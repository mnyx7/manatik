import Foundation
import Observation

@MainActor
@Observable
final class YearlyOverviewViewModel {
    var year: Int

    let store: AppStore

    init(store: AppStore, year: Int) {
        self.store = store
        self.year = year
    }

    /// Backed by the store's per-year cache: the twelve period summaries are
    /// computed once per data change rather than on every body evaluation.
    var months: [MonthOverviewItem] {
        store.monthsOverview(for: year)
    }

    var selectedInterval: DateInterval {
        store.selectedPeriod
    }

    var currency: Currency {
        store.state.settings.currency
    }

    var canGoToNextYear: Bool {
        year < 2200
    }

    var canGoToPreviousYear: Bool {
        year > 1900
    }

    func select(month item: MonthOverviewItem) {
        store.setPeriodAnchor(item.interval.start)
    }

    func nextYear() {
        guard canGoToNextYear else { return }
        year += 1
    }

    func previousYear() {
        guard canGoToPreviousYear else { return }
        year -= 1
    }
}
