import Combine
import Foundation

@MainActor
final class YearlyOverviewViewModel: ObservableObject {
    let store: AppStore
    @Published var year: Int

    init(store: AppStore, year: Int) {
        self.store = store
        self.year = year
    }

    var months: [MonthOverviewItem] {
        store.monthsOverview(for: year)
    }

    var selectedInterval: DateInterval {
        store.selectedPeriod
    }

    func select(month item: MonthOverviewItem) {
        store.setSelectedPeriod(anchorDate: item.interval.start)
    }

    func nextYear() {
        year += 1
    }

    func previousYear() {
        year -= 1
    }
}
