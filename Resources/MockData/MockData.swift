import Foundation

/// Sample data for SwiftUI previews. Not referenced by the shipping app.
enum MockData {
    static func previewState(calendar: Calendar = .current) -> AppState {
        let now = Date()
        func daysAgo(_ value: Int) -> Date {
            calendar.date(byAdding: .day, value: -value, to: now) ?? now
        }

        let salary = RecurringSeries(
            amount: 3_200,
            note: "Monthly salary",
            categoryID: "salary",
            type: .income,
            startDate: daysAgo(40),
            rule: .monthly
        )

        let rent = RecurringSeries(
            amount: 900,
            note: "Apartment rent",
            categoryID: "rent",
            type: .expense,
            startDate: daysAgo(37),
            rule: .monthly
        )

        let transactions = [
            Transaction(
                amount: Decimal(string: "84.50") ?? 0,
                note: "Weekly groceries",
                categoryID: "groceries",
                type: .expense,
                date: daysAgo(2)
            ),
            Transaction(
                amount: Decimal(string: "4.20") ?? 0,
                note: "Morning coffee",
                categoryID: "cafe",
                type: .expense,
                date: daysAgo(1)
            ),
            Transaction(
                amount: Decimal(string: "22.00") ?? 0,
                note: "Metro top-up",
                categoryID: "transport",
                type: .expense,
                date: now
            )
        ]

        return AppState(
            transactions: transactions,
            recurringSeries: [salary, rent],
            settings: .default
        )
    }

    @MainActor
    static func previewStore() -> AppStore {
        let store = AppStore(
            persistence: InMemoryPersistence(),
            initialState: previewState()
        )
        store.materializeDueOccurrences()
        return store
    }

    /// Previews mutate the store freely; without this they would write over the
    /// real `manatik-state.json` in the simulator's Documents directory.
    final class InMemoryPersistence: AppStatePersisting {
        private var stored: AppState?

        func load() -> StateLoadOutcome {
            guard let stored else { return .fresh }
            return .loaded(stored)
        }

        func save(_ state: AppState) throws {
            stored = state
        }

        func exportData(from state: AppState) throws -> Data {
            try JSONEncoder().encode(state)
        }

        func decodeState(from data: Data) throws -> AppState {
            try JSONDecoder().decode(AppState.self, from: data)
        }

        func writeSnapshot(_ state: AppState, tag: String) throws -> URL {
            URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(tag).json")
        }
    }

    static func previewOccurrence(projected: Bool) -> TransactionOccurrence {
        TransactionOccurrence(
            id: projected ? "preview-projected" : "preview-real",
            transactionID: projected ? nil : UUID(),
            seriesID: projected ? UUID() : nil,
            amount: projected ? 900 : (Decimal(string: "84.50") ?? 0),
            note: projected ? "Apartment rent" : "Weekly groceries",
            categoryID: projected ? "rent" : "groceries",
            type: .expense,
            date: Date(),
            isProjected: projected
        )
    }
}
