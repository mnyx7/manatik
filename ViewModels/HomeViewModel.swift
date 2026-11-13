import Foundation
import Observation

/// UI state shared by the main page and the activities list.
///
/// Holds no derived data and does not republish the store. Views observe the
/// store directly through the environment.
@MainActor
@Observable
final class HomeViewModel {
    var filter: TransactionFilter = .empty

    /// Which slice of the ledger Activities is showing. Writes the type and
    /// bills flags into `filter`, leaving the user's own filters alone.
    var scope: ActivityScope = .all {
        didSet { filter.applyScope(scope) }
    }

    var isShowingAddSheet = false
    /// True while the Activity search field has the keyboard, so the tab bar
    /// can step aside and the field sits on the keyboard.
    var isSearchFocused = false
    var isShowingPeriodPicker = false
    var isShowingDateFilter = false

    /// Pre-selected category when the add sheet was opened from a quick-add chip.
    var quickAddCategoryID: String?

    var editingOccurrence: TransactionOccurrence?
    var pendingDelete: TransactionOccurrence?

    // Savings and loan flows
    var contributingGoal: SavingsGoal?
    var payingLoan: Loan?
    var isShowingGoalEditor = false
    var editingGoal: SavingsGoal?
    var isShowingLoanEditor = false
    var editingLoan: Loan?

    var quickAddCategories: [TransactionCategory] {
        DefaultCategories.quickAddCategoryIDs.map { DefaultCategories.category(for: $0) }
    }

    /// The range actually being browsed. An explicit date filter wins over the
    /// selected period, so a range outside the current month returns its real
    /// contents instead of nothing.
    func browsedInterval(defaultPeriod: DateInterval) -> DateInterval {
        filter.dateInterval ?? defaultPeriod
    }

    /// The day the calendar strip has picked, expressed as a one-day date
    /// filter so it reuses the same filtering path as a manual range.
    var selectedDay: Date? {
        get {
            guard let interval = filter.dateInterval else { return nil }
            let calendar = Calendar.current
            let days = calendar.dateComponents(
                [.day],
                from: interval.start,
                to: interval.end
            ).day ?? 0
            return days == 1 ? calendar.startOfDay(for: interval.start) : nil
        }
        set {
            let calendar = Calendar.current
            guard let day = newValue else {
                filter.dateInterval = nil
                return
            }
            let start = calendar.startOfDay(for: day)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            filter.dateInterval = DateInterval(start: start, end: end)
        }
    }

    func beginAdd() {
        quickAddCategoryID = nil
        editingOccurrence = nil
        isShowingAddSheet = true
    }

    func beginQuickAdd(_ category: TransactionCategory) {
        quickAddCategoryID = category.id
        editingOccurrence = nil
        isShowingAddSheet = true
    }

    /// Clears what the user set, keeping the Activities segment intact.
    func clearFilters() {
        filter = .empty
        filter.applyScope(scope)
    }

    func newGoal() {
        editingGoal = nil
        isShowingGoalEditor = true
    }

    func edit(goal: SavingsGoal) {
        editingGoal = goal
        isShowingGoalEditor = true
    }

    func newLoan() {
        editingLoan = nil
        isShowingLoanEditor = true
    }

    func edit(loan: Loan) {
        editingLoan = loan
        isShowingLoanEditor = true
    }
}
