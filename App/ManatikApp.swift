import SwiftUI

@main
struct ManatikApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: HomeViewModel(store: store))
                .environmentObject(store)
        }
    }
}
