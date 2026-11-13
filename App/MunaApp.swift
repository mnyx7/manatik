//
//  MunaApp.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import SwiftUI

@main
struct MunaApp: App {
    @State private var store = AppStore.makeForLaunch()
    @State private var reminderScheduler = ReminderScheduler()
    @State private var isShowingSplash = true
    @State private var links = AppLinks()

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if isShowingSplash {
                    SplashView { isShowingSplash = false }
                        .zIndex(1)
                }
            }
                .environment(store)
                .environment(reminderScheduler)
                .environment(links)
                .onOpenURL { url in
                    // From the widget the user wants the form, not the
                    // splash, so skip straight to it.
                    if links.handle(url) { isShowingSplash = false }
                }
                .task {
                    #if DEBUG
                    // `-qa-open-url muna://add` runs a link through the same
                    // path a widget tap takes.
                    if let link = QALaunch.value(for: "-qa-open-url"), let url = URL(string: link),
                       links.handle(url) {
                        isShowingSplash = false
                    }
                    #endif
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

extension AppStore {
    /// The store the app launches with. In Debug a `-qa-seed` launch argument
    /// swaps in in-memory demo data, so screenshot runs never touch the real
    /// file in Documents.
    static func makeForLaunch() -> AppStore {
        #if DEBUG
        if QALaunch.isSeeding {
            let store = AppStore(
                persistence: InMemoryPersistence(),
                initialState: QALaunch.demoState()
            )
            store.materializeDueOccurrences()
            return store
        }
        #endif
        return AppStore()
    }
}
