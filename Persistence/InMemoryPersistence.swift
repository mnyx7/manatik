//
//  InMemoryPersistence.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import Foundation

/// A store that keeps state in memory and never touches the filesystem.
///
/// Used by previews and by `-qa-seed` screenshot runs. Without it both would
/// write over the real `manatik-state.json` in Documents, which is how a
/// preview can silently destroy a person's ledger.
final class InMemoryPersistence: AppStatePersisting {
    private var stored: AppState?

    init(initial: AppState? = nil) {
        self.stored = initial
    }

    func load() -> StateLoadOutcome {
        guard let stored else { return .fresh }
        return .loaded(stored)
    }

    func save(_ state: AppState) throws {
        stored = state
    }

    func exportData(from state: AppState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(state)
    }

    func decodeState(from data: Data) throws -> AppState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppState.self, from: data)
    }

    func writeSnapshot(_ state: AppState, tag: String) throws -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(tag).json")
    }
}
