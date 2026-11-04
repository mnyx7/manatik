import SwiftUI

@main
struct ManatikApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var reminderScheduler = ReminderScheduler()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(reminderScheduler)
                .task {
                    // Turn every repeating date up to today into a real entry
                    // before the first frame reads the ledger.
                    store.materializeDueOccurrences()
                    // A bill picked for an entry the user then cancelled leaves
                    // a file behind; clear those rather than letting them grow.
                    store.pruneAttachmentOrphans()
                }
        }
    }
}
