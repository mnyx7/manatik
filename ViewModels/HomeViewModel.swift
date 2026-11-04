import Foundation

/// UI state shared by the main page and the activities list.
///
/// Holds no derived data and does not republish the store. Views observe the
/// store directly through the environment.
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var filter: TransactionFilter = .empty

    /// Which slice of the ledger Activities is showing. Writes the type and
    /// bills flags into `filter`, leaving the user's own filters alone.
    @Published var scope: ActivityScope = .all {
        didSet { filter.applyScope(scope) }
    }

    @Published var isShowingAddSheet = false
    @Published var isShowingPeriodPicker = false
    @Published var isShowingDateFilter = false

    /// Pre-selected category when the add sheet was opened from a quick-add chip.
    @Published var quickAddCategoryID: String?

    @Published var editingOccurrence: TransactionOccurrence?
    @Published var pendingDelete: TransactionOccurrence?

    // Savings and loan flows
    @Published var contributingGoal: SavingsGoal?
    @Published var payingLoan: Loan?
    @Published var isShowingGoalEditor = false
    @Published var editingGoal: SavingsGoal?
    @Published var isShowingLoanEditor = false
    @Published var editingLoan: Loan?

    var quickAddCategories: [TransactionCategory] {
        DefaultCategories.quickAddCategoryIDs.map { DefaultCategories.category(for: $0) }
    }

    /// The range actually being browsed. An explicit date filter wins over the
    /// selected period, so a range outside the current month returns its real
    /// contents instead of nothing.
    func browsedInterval(defaultPeriod: DateInterval) -> DateInterval {
        filter.dateInterval ?? defaultPeriod
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
