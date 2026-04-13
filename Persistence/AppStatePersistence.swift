import Foundation

protocol AppStatePersisting {
    func load() -> AppState
    func save(_ state: AppState)
    func exportData(from state: AppState) throws -> Data
    func importState(from data: Data) throws -> AppState
}

enum AppStatePersistenceError: LocalizedError {
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "Invalid backup file."
        }
    }
}

final class AppStatePersistence: AppStatePersisting {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(filename: String = "manatik-state.json") {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.fileURL = directory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load() -> AppState {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? decoder.decode(AppState.self, from: data) else {
            return .default
        }

        var normalized = state
        normalized.settings.monthStartDay = min(max(normalized.settings.monthStartDay, 1), 31)
        return normalized
    }

    func save(_ state: AppState) {
        do {
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save app state: \(error.localizedDescription)")
        }
    }

    func exportData(from state: AppState) throws -> Data {
        try encoder.encode(state)
    }

    func importState(from data: Data) throws -> AppState {
        guard let imported = try? decoder.decode(AppState.self, from: data) else {
            throw AppStatePersistenceError.invalidFile
        }

        var normalized = imported
        normalized.settings.monthStartDay = min(max(normalized.settings.monthStartDay, 1), 31)
        return normalized
    }
}
