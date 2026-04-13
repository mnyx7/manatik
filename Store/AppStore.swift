import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var state: AppState

    let categories: [TransactionCategory]

    private let persistence: AppStatePersisting
    private let recurringService: RecurringTransactionServicing

    init(
        persistence: AppStatePersisting = AppStatePersistence(),
        recurringService: RecurringTransactionServicing = RecurringTransactionService(),
        categories: [TransactionCategory] = DefaultCategories.all,
        initialState: AppState? = nil
    ) {
        self.persistence = persistence
        self.recurringService = recurringService
        self.categories = categories
        self.state = initialState ?? persistence.load()
    }

    var selectedPeriod: DateInterval {
        DateRangeCalculator.period(
            for: state.selectedPeriodAnchorDate,
            monthStartDay: state.settings.monthStartDay
        )
    }

    var selectedYear: Int {
        Calendar.current.component(.year, from: state.selectedPeriodAnchorDate)
    }

    var occurrencesForSelectedPeriod: [TransactionOccurrence] {
        recurringService.occurrences(for: state.transactions, in: selectedPeriod)
    }

    func summaryForSelectedPeriod() -> TransactionSummary {
        TransactionAnalytics.summary(
            occurrences: occurrencesForSelectedPeriod,
            dayCount: DateRangeCalculator.dayCount(for: selectedPeriod)
        )
    }

    func categoryTotalsForSelectedPeriod() -> [CategorySpending] {
        TransactionAnalytics.topCategorySpending(from: occurrencesForSelectedPeriod, categories: categories)
    }

    func groupedSectionsForSelectedPeriod(filter: TransactionFilter) -> [DailyTransactionSection] {
        let filtered = apply(filter: filter, to: occurrencesForSelectedPeriod)
        return TransactionAnalytics.groupedByDay(filtered)
    }

    func monthsOverview(for year: Int) -> [MonthOverviewItem] {
        (1...12).map { month in
            let anchor = DateRangeCalculator.monthAnchor(
                year: year,
                month: month,
                monthStartDay: state.settings.monthStartDay
            )
            let interval = DateRangeCalculator.period(for: anchor, monthStartDay: state.settings.monthStartDay)
            let occurrences = recurringService.occurrences(for: state.transactions, in: interval)
            let summary = TransactionAnalytics.summary(
                occurrences: occurrences,
                dayCount: DateRangeCalculator.dayCount(for: interval)
            )
            return MonthOverviewItem(
                month: month,
                year: year,
                interval: interval,
                income: summary.income,
                expense: summary.expense
            )
        }
    }

    func setSelectedPeriod(anchorDate: Date) {
        state.selectedPeriodAnchorDate = anchorDate
        persist()
    }

    func moveSelectedPeriod(byMonths value: Int) {
        guard let shifted = Calendar.current.date(byAdding: .month, value: value, to: state.selectedPeriodAnchorDate) else { return }
        setSelectedPeriod(anchorDate: shifted)
    }

    func addTransaction(_ draft: TransactionDraft) {
        let transaction = Transaction(
            amount: draft.amount,
            note: draft.note,
            categoryID: draft.categoryID,
            type: draft.type,
            date: draft.date,
            recurrenceRule: draft.recurrenceRule
        )
        state.transactions.append(transaction)
        persist()
    }

    func updateTransaction(id: UUID, draft: TransactionDraft) {
        guard let index = state.transactions.firstIndex(where: { $0.id == id }) else { return }
        state.transactions[index].amount = draft.amount
        state.transactions[index].note = draft.note
        state.transactions[index].categoryID = draft.categoryID
        state.transactions[index].type = draft.type
        state.transactions[index].date = draft.date
        state.transactions[index].recurrenceRule = draft.recurrenceRule
        state.transactions[index].updatedAt = Date()
        persist()
    }

    func deleteTransaction(id: UUID) {
        state.transactions.removeAll { $0.id == id }
        persist()
    }

    func updateSettings(currency: Currency? = nil, monthStartDay: Int? = nil, savingsGoal: SavingsGoal? = nil) {
        if let currency {
            state.settings.currency = currency
        }

        if let monthStartDay {
            state.settings.monthStartDay = min(max(monthStartDay, 1), 31)
        }

        if let savingsGoal {
            state.settings.savingsGoal = savingsGoal
        }

        persist()
    }

    func resetWithImportedState(_ imported: AppState) {
        state = imported
        persist()
    }

    func exportStateData() throws -> Data {
        try persistence.exportData(from: state)
    }

    func importStateData(_ data: Data) throws {
        let imported = try persistence.importState(from: data)
        resetWithImportedState(imported)
    }

    private func persist() {
        state.transactions.sort(by: { $0.date > $1.date })
        persistence.save(state)
    }

    private func apply(filter: TransactionFilter, to occurrences: [TransactionOccurrence]) -> [TransactionOccurrence] {
        occurrences.filter { item in
            let categoryMatches = filter.categoryID.map { $0 == item.categoryID } ?? true
            let typeMatches = filter.type.map { $0 == item.type } ?? true
            let dateMatches = filter.dateInterval.map { $0.contains(item.date) } ?? true
            let text = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchMatches = text.isEmpty || item.note.localizedCaseInsensitiveContains(text)
            return categoryMatches && typeMatches && dateMatches && searchMatches
        }
    }
}

struct TransactionDraft {
    var amount: Double
    var note: String
    var categoryID: String
    var type: TransactionType
    var date: Date
    var recurrenceRule: RecurrenceRule
}

struct MonthOverviewItem: Identifiable {
    var id: String { "\(year)-\(month)" }
    let month: Int
    let year: Int
    let interval: DateInterval
    let income: Double
    let expense: Double
}
