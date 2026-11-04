import Foundation

/// What `load()` found on disk.
enum StateLoadOutcome {
    /// No file yet -- a genuinely new install.
    case fresh
    case loaded(AppState)
    /// Read from an older schema and upgraded in memory.
    case migrated(AppState, fromVersion: Int)
    /// A file exists but could not be read. The caller must NOT start saving
    /// over it, or a decode bug would destroy real data.
    case unreadable(message: String, backupCopy: URL?)
}

enum AppStatePersistenceError: LocalizedError {
    case invalidFile
    case unsupportedSchema(version: Int)

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return NSLocalizedString("This is not a valid manatik backup file.", comment: "Error")
        case .unsupportedSchema(let version):
            return String(
                format: NSLocalizedString(
                    "This backup was made by a newer version of manatik (format %d). Update the app and try again.",
                    comment: "Error"
                ),
                version
            )
        }
    }
}

protocol AppStatePersisting {
    func load() -> StateLoadOutcome
    func save(_ state: AppState) throws
    func exportData(from state: AppState) throws -> Data
    func decodeState(from data: Data) throws -> AppState
    /// Writes a timestamped copy next to the live file and returns its URL.
    func writeSnapshot(_ state: AppState, tag: String) throws -> URL
}

final class AppStatePersistence: AppStatePersisting {
    /// Bump when the on-disk shape changes, and add a migration below.
    static let currentSchemaVersion = 2

    private let fileURL: URL
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(filename: String = "manatik-state.json") {
        let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        self.directory = documents
        self.fileURL = documents.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - Load

    func load() -> StateLoadOutcome {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .fresh
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            return .unreadable(
                message: String(
                    format: NSLocalizedString("Your data file could not be opened: %@", comment: "Error"),
                    error.localizedDescription
                ),
                backupCopy: nil
            )
        }

        if data.isEmpty {
            return .fresh
        }

        do {
            let version = try detectSchemaVersion(in: data)
            var state = try decodeState(from: data, version: version)
            state.settings.normalize()

            if version < Self.currentSchemaVersion {
                return .migrated(state, fromVersion: version)
            }
            return .loaded(state)
        } catch {
            // Keep the bytes before anything else touches them.
            let copy = try? copyAside(data: data, tag: "unreadable")
            return .unreadable(
                message: String(
                    format: NSLocalizedString("Your data file could not be read: %@", comment: "Error"),
                    error.localizedDescription
                ),
                backupCopy: copy
            )
        }
    }

    // MARK: - Save

    func save(_ state: AppState) throws {
        let file = StateFile(
            schemaVersion: Self.currentSchemaVersion,
            transactions: state.transactions,
            recurringSeries: state.recurringSeries,
            paymentReminders: state.paymentReminders,
            settings: state.settings
        )
        let data = try encoder.encode(file)
        try data.write(to: fileURL, options: .atomic)

        // Financial data should not be readable while the device is locked.
        #if canImport(UIKit)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUnlessOpen],
            ofItemAtPath: fileURL.path
        )
        #endif
    }

    func writeSnapshot(_ state: AppState, tag: String) throws -> URL {
        let file = StateFile(
            schemaVersion: Self.currentSchemaVersion,
            transactions: state.transactions,
            recurringSeries: state.recurringSeries,
            paymentReminders: state.paymentReminders,
            settings: state.settings
        )
        let data = try encoder.encode(file)
        let url = directory.appendingPathComponent("manatik-\(tag)-\(Self.timestamp()).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Import / export

    func exportData(from state: AppState) throws -> Data {
        let pretty = JSONEncoder()
        pretty.dateEncodingStrategy = .iso8601
        pretty.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try pretty.encode(
            StateFile(
                schemaVersion: Self.currentSchemaVersion,
                transactions: state.transactions,
                recurringSeries: state.recurringSeries,
                paymentReminders: state.paymentReminders,
                settings: state.settings
            )
        )
    }

    func decodeState(from data: Data) throws -> AppState {
        let version = try detectSchemaVersion(in: data)
        var state = try decodeState(from: data, version: version)
        state.settings.normalize()
        return state
    }

    // MARK: - Schema handling

    private struct SchemaProbe: Decodable {
        let schemaVersion: Int?
    }

    private struct StateFile: Codable {
        var schemaVersion: Int
        var transactions: [Transaction]
        var recurringSeries: [RecurringSeries]
        var paymentReminders: [PaymentReminder]
        var settings: AppSettings

        init(
            schemaVersion: Int,
            transactions: [Transaction],
            recurringSeries: [RecurringSeries],
            paymentReminders: [PaymentReminder],
            settings: AppSettings
        ) {
            self.schemaVersion = schemaVersion
            self.transactions = transactions
            self.recurringSeries = recurringSeries
            self.paymentReminders = paymentReminders
            self.settings = settings
        }

        /// Collection fields decode permissively. A future release that adds a
        /// list must not make this release's files unreadable, which is exactly
        /// how a schema change turns into apparent data loss.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
            transactions = try container.decodeIfPresent([Transaction].self, forKey: .transactions) ?? []
            recurringSeries = try container.decodeIfPresent([RecurringSeries].self, forKey: .recurringSeries) ?? []
            paymentReminders = try container.decodeIfPresent([PaymentReminder].self, forKey: .paymentReminders) ?? []
            settings = try container.decode(AppSettings.self, forKey: .settings)
        }
    }

    private func detectSchemaVersion(in data: Data) throws -> Int {
        guard let probe = try? decoder.decode(SchemaProbe.self, from: data) else {
            throw AppStatePersistenceError.invalidFile
        }
        // Files written before versioning existed carry no marker.
        let version = probe.schemaVersion ?? 1
        guard version <= Self.currentSchemaVersion else {
            throw AppStatePersistenceError.unsupportedSchema(version: version)
        }
        return version
    }

    private func decodeState(from data: Data, version: Int) throws -> AppState {
        switch version {
        case 1:
            let legacy = try decoder.decode(LegacyStateFileV1.self, from: data)
            return LegacyStateFileV1.migrate(legacy)
        case 2:
            let file = try decoder.decode(StateFile.self, from: data)
            return AppState(
                transactions: file.transactions,
                recurringSeries: file.recurringSeries,
                paymentReminders: file.paymentReminders,
                settings: file.settings
            )
        default:
            throw AppStatePersistenceError.unsupportedSchema(version: version)
        }
    }

    // MARK: - Helpers

    private func copyAside(data: Data, tag: String) throws -> URL {
        let url = directory.appendingPathComponent("manatik-\(tag)-\(Self.timestamp()).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Schema 1

/// The shape written before recurring series were split out and before amounts
/// became `Decimal`. Recurring transactions here were simultaneously a template
/// and a ledger entry, so each one becomes a series whose history is then
/// materialized by the store.
private struct LegacyStateFileV1: Decodable {
    struct LegacyTransaction: Decodable {
        let id: UUID
        let amount: Double
        let note: String
        let categoryID: String
        let type: TransactionType
        let date: Date
        let createdAt: Date?
        let updatedAt: Date?
        let recurrenceRule: String?
    }

    struct LegacySavingsGoal: Decodable {
        let targetAmount: Double
        let currentSavedAmount: Double
        let useAmountLeftForProgress: Bool
    }

    struct LegacySettings: Decodable {
        let currency: Currency
        let monthStartDay: Int
        let savingsGoal: LegacySavingsGoal
    }

    let transactions: [LegacyTransaction]
    let settings: LegacySettings

    static func migrate(_ legacy: LegacyStateFileV1) -> AppState {
        var transactions: [Transaction] = []
        var series: [RecurringSeries] = []

        for row in legacy.transactions {
            let amount = decimal(from: row.amount)
            let rule = RecurrenceRule(rawValue: row.recurrenceRule ?? "none") ?? .none

            if rule.repeats {
                series.append(
                    RecurringSeries(
                        id: row.id,
                        amount: amount,
                        note: row.note,
                        categoryID: row.categoryID,
                        type: row.type,
                        startDate: row.date,
                        rule: rule,
                        endDate: nil,
                        isPaused: false,
                        skippedDays: [],
                        // nil so the store backfills every past occurrence as a
                        // real row, preserving the history the old app showed.
                        materializedThrough: nil,
                        createdAt: row.createdAt ?? row.date,
                        updatedAt: row.updatedAt ?? row.date
                    )
                )
            } else {
                transactions.append(
                    Transaction(
                        id: row.id,
                        amount: amount,
                        note: row.note,
                        categoryID: row.categoryID,
                        type: row.type,
                        date: row.date,
                        createdAt: row.createdAt ?? row.date,
                        updatedAt: row.updatedAt ?? row.date,
                        seriesID: nil
                    )
                )
            }
        }

        var settings = AppSettings(
            currency: legacy.settings.currency,
            monthStartDay: legacy.settings.monthStartDay,
            savingsGoal: SavingsGoal(
                targetAmount: decimal(from: legacy.settings.savingsGoal.targetAmount),
                currentSavedAmount: decimal(from: legacy.settings.savingsGoal.currentSavedAmount),
                useAmountLeftForProgress: legacy.settings.savingsGoal.useAmountLeftForProgress
            )
        )
        settings.normalize()

        return AppState(transactions: transactions, recurringSeries: series, settings: settings)
    }

    /// Goes through the 2-decimal text form so binary float noise in the old
    /// file does not become a permanent `Decimal` value.
    private static func decimal(from value: Double) -> Decimal {
        guard value.isFinite else { return .zero }
        return Decimal(string: String(format: "%.2f", value), locale: Locale(identifier: "en_US_POSIX")) ?? .zero
    }
}
