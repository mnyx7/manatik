//
//  AppStatePersistence.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

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
            return NSLocalizedString("This is not a valid muna backup file.", comment: "Error")
        case .unsupportedSchema(let version):
            return String(
                format: NSLocalizedString(
                    "This backup was made by a newer version of muna (format %d). Update the app and try again.",
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
    ///
    /// 1: one flat transaction list, Double amounts, recurrence on the row.
    /// 2: recurring series split out, Decimal amounts, reminders.
    /// 3: custom categories, many savings goals, loans, attachments, bills.
    static let currentSchemaVersion = 3

    private let fileURL: URL
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // Keeps the pre-rename name on purpose: renaming it would leave existing
    // users' data behind in the old file.
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
        let data = try encoder.encode(StateFile(state: state))
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
        let data = try encoder.encode(StateFile(state: state))
        let url = directory.appendingPathComponent("muna-\(tag)-\(Self.timestamp()).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Import / export

    func exportData(from state: AppState) throws -> Data {
        let pretty = JSONEncoder()
        pretty.dateEncodingStrategy = .iso8601
        pretty.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try pretty.encode(StateFile(state: state))
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
        var customCategories: [TransactionCategory]
        var categoryOrder: [String]
        var hiddenCategoryIDs: Set<String>
        var savingsGoals: [SavingsGoal]
        var loans: [Loan]
        var feedbackNotes: [FeedbackNote]
        var settings: AppSettings

        init(state: AppState) {
            schemaVersion = AppStatePersistence.currentSchemaVersion
            transactions = state.transactions
            recurringSeries = state.recurringSeries
            paymentReminders = state.paymentReminders
            customCategories = state.customCategories
            categoryOrder = state.categoryOrder
            hiddenCategoryIDs = state.hiddenCategoryIDs
            savingsGoals = state.savingsGoals
            loans = state.loans
            feedbackNotes = state.feedbackNotes
            settings = state.settings
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
            customCategories = try container.decodeIfPresent([TransactionCategory].self, forKey: .customCategories) ?? []
            categoryOrder = try container.decodeIfPresent([String].self, forKey: .categoryOrder) ?? []
            hiddenCategoryIDs = try container.decodeIfPresent(Set<String>.self, forKey: .hiddenCategoryIDs) ?? []
            savingsGoals = try container.decodeIfPresent([SavingsGoal].self, forKey: .savingsGoals) ?? []
            loans = try container.decodeIfPresent([Loan].self, forKey: .loans) ?? []
            feedbackNotes = try container.decodeIfPresent([FeedbackNote].self, forKey: .feedbackNotes) ?? []
            settings = try container.decode(AppSettings.self, forKey: .settings)
        }

        var appState: AppState {
            AppState(
                transactions: transactions,
                recurringSeries: recurringSeries,
                paymentReminders: paymentReminders,
                customCategories: customCategories,
                categoryOrder: categoryOrder,
                hiddenCategoryIDs: hiddenCategoryIDs,
                savingsGoals: savingsGoals,
                loans: loans,
                feedbackNotes: feedbackNotes,
                settings: settings
            )
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
            return LegacySchema.migrateV1(try decoder.decode(LegacySchema.FileV1.self, from: data))
        case 2:
            let file = try decoder.decode(LegacySchema.FileV2.self, from: data)
            return LegacySchema.migrateV2(file)
        case 3:
            return try decoder.decode(StateFile.self, from: data).appState
        default:
            throw AppStatePersistenceError.unsupportedSchema(version: version)
        }
    }

    // MARK: - Helpers

    private func copyAside(data: Data, tag: String) throws -> URL {
        let url = directory.appendingPathComponent("muna-\(tag)-\(Self.timestamp()).json")
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

// MARK: - Older on-disk shapes

enum LegacySchema {
    /// Schema 1: amounts were Double and a recurring row was simultaneously a
    /// template and a ledger entry.
    struct FileV1: Decodable {
        struct Row: Decodable {
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

        let transactions: [Row]
        let settings: SettingsV1V2
    }

    /// Schema 2: series were split out, but there was still exactly one savings
    /// goal and it lived inside settings.
    struct FileV2: Decodable {
        let transactions: [Transaction]
        let recurringSeries: [RecurringSeries]
        let paymentReminders: [PaymentReminder]?
        let settings: SettingsV1V2
    }

    struct SettingsV1V2: Decodable {
        struct Goal: Decodable {
            let targetAmount: Double?
            let currentSavedAmount: Double?
        }

        let currency: Currency?
        let monthStartDay: Int?
        let savingsGoal: Goal?
    }

    static func migrateV1(_ file: FileV1) -> AppState {
        var transactions: [Transaction] = []
        var series: [RecurringSeries] = []

        for row in file.transactions {
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
                        updatedAt: row.updatedAt ?? row.date
                    )
                )
            }
        }

        return assemble(
            transactions: transactions,
            series: series,
            reminders: [],
            legacySettings: file.settings
        )
    }

    static func migrateV2(_ file: FileV2) -> AppState {
        assemble(
            transactions: file.transactions,
            series: file.recurringSeries,
            reminders: file.paymentReminders ?? [],
            legacySettings: file.settings
        )
    }

    /// Turns the single settings-level savings goal into the first entry of the
    /// new goal list. Anything already put aside becomes the goal's opening
    /// amount rather than a fabricated past expense.
    private static func assemble(
        transactions: [Transaction],
        series: [RecurringSeries],
        reminders: [PaymentReminder],
        legacySettings: SettingsV1V2
    ) -> AppState {
        var settings = AppSettings(
            currency: legacySettings.currency ?? .azn,
            monthStartDay: legacySettings.monthStartDay ?? 1
        )
        settings.normalize()

        var goals: [SavingsGoal] = []
        let target = decimal(from: legacySettings.savingsGoal?.targetAmount ?? 0)
        let saved = decimal(from: legacySettings.savingsGoal?.currentSavedAmount ?? 0)

        if target > 0 || saved > 0 {
            goals.append(
                SavingsGoal(
                    name: NSLocalizedString("Savings", comment: "Migrated goal name"),
                    targetAmount: target > 0 ? target : saved,
                    openingAmount: saved,
                    note: NSLocalizedString(
                        "Carried over from your earlier savings goal.",
                        comment: "Migrated goal note"
                    )
                )
            )
        }

        return AppState(
            transactions: transactions,
            recurringSeries: series,
            paymentReminders: reminders,
            customCategories: [],
            savingsGoals: goals,
            loans: [],
            settings: settings
        )
    }

    /// Goes through the 2-decimal text form so binary float noise in the old
    /// file does not become a permanent `Decimal` value.
    private static func decimal(from value: Double) -> Decimal {
        guard value.isFinite else { return .zero }
        return Decimal(
            string: String(format: "%.2f", value),
            locale: Locale(identifier: "en_US_POSIX")
        ) ?? .zero
    }
}
