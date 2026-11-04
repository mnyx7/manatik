import Foundation

/// UI state for the main page and the activities list.
///
/// Holds no derived data and does not republish the store. Views observe the
/// store directly through the environment, so the old `objectWillChange`
/// bridge (which re-rendered twice and lagged by a runloop hop) is gone.
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var filter: TransactionFilter = .empty

    @Published var isShowingAddSheet = false
    @Published var isShowingPeriodPicker = false
    @Published var isShowingDateFilter = false

    /// Pre-selected category when the add sheet was opened from a quick-add chip.
    @Published var quickAddCategoryID: String?

    @Published var editingOccurrence: TransactionOccurrence?
    @Published var pendingDelete: TransactionOccurrence?

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

    func clearFilters() {
        filter = .empty
    }
}
