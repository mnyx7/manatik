import SwiftUI

/// Previous / back-to-today / pick / next for the browsed period. Shared by
/// every home style so they all move through months the same way.
struct PeriodToolbar: ToolbarContent {
    let store: AppStore
    let viewModel: HomeViewModel

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                store.movePeriod(byMonths: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel(Text("Previous period"))
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            if !store.isViewingCurrentPeriod {
                Button {
                    store.resetPeriodToToday()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .accessibilityLabel(Text("Back to today"))
            }

            Button {
                viewModel.isShowingPeriodPicker = true
            } label: {
                Image(systemName: "calendar")
            }
            .accessibilityLabel(Text("Change period"))

            Button {
                store.movePeriod(byMonths: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel(Text("Next period"))
        }
    }
}
