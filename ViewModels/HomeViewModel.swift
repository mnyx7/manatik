import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var filter: TransactionFilter = .empty
    @Published var isShowingAddSheet = false
    @Published var isShowingSettings = false
    @Published var isShowingYearlyOverview = false
    @Published var isShowingPeriodPicker = false
    @Published var editingTransactionID: UUID?
    @Published var pendingDeleteID: UUID?

    let store: AppStore

    private var cancellables = Set<AnyCancellable>()

    init(store: AppStore) {
        self.store = store

        store.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var selectedYearText: String {
        String(store.selectedYear)
    }

    var selectedPeriodText: String {
        DateRangeCalculator.periodDisplayText(for: store.selectedPeriod)
    }

    var summary: TransactionSummary {
        store.summaryForSelectedPeriod()
    }

    var categoryTotals: [CategorySpending] {
        store.categoryTotalsForSelectedPeriod()
    }

    var sections: [DailyTransactionSection] {
        store.groupedSectionsForSelectedPeriod(filter: filter)
    }

    var quickAddCategories: [TransactionCategory] {
        DefaultCategories.quickAddCategoryIDs.map { DefaultCategories.category(for: $0) }
    }

    var hasActiveFilter: Bool {
        filter.isActive
    }

    var currency: Currency {
        store.state.settings.currency
    }

    var savingsGoal: SavingsGoal {
        store.state.settings.savingsGoal
    }

    func amountText(_ amount: Double) -> String {
        CurrencyFormatting.format(amount: amount, currency: currency)
    }

    func monthlySavingsProgress() -> (current: Double, target: Double, progress: Double) {
        let current = savingsGoal.useAmountLeftForProgress ? max(summary.amountLeft, 0) : max(savingsGoal.currentSavedAmount, 0)
        let target = max(savingsGoal.targetAmount, 1)
        let progress = min(current / target, 1)
        return (current, target, progress)
    }

    func startQuickAdd(with category: TransactionCategory) {
        editingTransactionID = nil
        isShowingAddSheet = true
        filter.type = nil
    }

    func deletePendingTransaction() {
        guard let id = pendingDeleteID else { return }
        store.deleteTransaction(id: id)
        pendingDeleteID = nil
    }

    func setPeriodAnchorDate(_ date: Date) {
        store.setSelectedPeriod(anchorDate: date)
    }

    func movePeriod(by months: Int) {
        store.moveSelectedPeriod(byMonths: months)
    }
}
