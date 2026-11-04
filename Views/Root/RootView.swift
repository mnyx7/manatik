import SwiftUI

enum RootDestination: Hashable {
    case activities
    case settings
    case yearOverview
}

/// The app shell: the main page, plus one bottom bar with Settings on the left,
/// add in the middle and Activities on the right.
///
/// Every sheet and destructive confirmation is presented from here. Previously
/// two `.sheet` modifiers hung off different levels of the same hierarchy,
/// which is how SwiftUI ends up dropping one of two competing presentations.
struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var reminderScheduler: ReminderScheduler

    @StateObject private var viewModel = HomeViewModel()
    @State private var path: [RootDestination] = []
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                viewModel: viewModel,
                onOpenActivities: { path.append(.activities) },
                onOpenYearOverview: { path.append(.yearOverview) }
            )
            .navigationDestination(for: RootDestination.self, destination: destination)
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        }
        .sheet(isPresented: $viewModel.isShowingAddSheet) {
            TransactionFormView(
                store: store,
                mode: .add(preselectedCategoryID: viewModel.quickAddCategoryID)
            )
        }
        .sheet(item: $viewModel.editingOccurrence) { occurrence in
            TransactionFormView(store: store, mode: .edit(occurrence: occurrence))
        }
        .sheet(isPresented: $viewModel.isShowingPeriodPicker) {
            PeriodPickerSheet(
                selectedDate: store.periodAnchorDate,
                monthStartDay: store.state.settings.monthStartDay
            ) { store.setPeriodAnchor($0) }
        }
        .sheet(isPresented: $viewModel.isShowingDateFilter) {
            DateFilterSheetView(filter: $viewModel.filter)
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: deleteDialogBinding,
            titleVisibility: .visible,
            presenting: viewModel.pendingDelete
        ) { occurrence in
            deleteActions(for: occurrence)
        } message: { occurrence in
            Text(deleteDialogMessage(for: occurrence))
        }
        .alert(
            store.persistenceIssue?.title ?? "",
            isPresented: persistenceAlertBinding,
            presenting: store.persistenceIssue
        ) { issue in
            if issue.isBlocking {
                // A blocking issue means nothing is being saved. The user has
                // to choose, rather than silently losing every later edit.
                Button("Start fresh", role: .destructive) {
                    store.resumePersistenceWithCurrentState()
                }
                Button("Keep waiting", role: .cancel) {
                    store.persistenceIssue = nil
                }
            } else {
                Button("OK", role: .cancel) {
                    store.persistenceIssue = nil
                }
            }
        } message: { issue in
            Text(persistenceMessage(for: issue))
        }
        .task {
            await reminderScheduler.refreshAuthorizationStatus()
            await reminderScheduler.sync(
                reminders: store.state.paymentReminders,
                currency: store.state.settings.currency
            )
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Catches up any series dates that passed while the app was away,
            // and re-aligns notifications with what is on disk.
            store.materializeDueOccurrences()
            Task {
                await reminderScheduler.sync(
                    reminders: store.state.paymentReminders,
                    currency: store.state.settings.currency
                )
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(alignment: .center) {
            barButton(
                systemImage: "gearshape",
                title: "Settings",
                accessibilityLabel: Text("Settings")
            ) {
                path.append(.settings)
            }

            Spacer(minLength: 12)

            Button {
                viewModel.beginAdd()
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Color.accentColor))
                    .shadow(radius: 6, y: 2)
            }
            .accessibilityLabel(Text("Add income or expense"))

            Spacer(minLength: 12)

            barButton(
                systemImage: "list.bullet.rectangle",
                title: "Activities",
                accessibilityLabel: Text("Activities")
            ) {
                path.append(.activities)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(.bar)
    }

    @ViewBuilder
    private func barButton(
        systemImage: String,
        title: LocalizedStringKey,
        accessibilityLabel: Text,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                Text(title)
                    .font(.caption2)
            }
            .frame(minWidth: 64, minHeight: AppTheme.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destination(_ destination: RootDestination) -> some View {
        switch destination {
        case .activities:
            ActivitiesView(viewModel: viewModel)
        case .settings:
            SettingsView(viewModel: SettingsViewModel(store: store))
        case .yearOverview:
            YearlyOverviewView(
                viewModel: YearlyOverviewViewModel(store: store, year: store.selectedYear)
            )
        }
    }

    // MARK: - Delete confirmation

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingDelete != nil },
            set: { if !$0 { viewModel.pendingDelete = nil } }
        )
    }

    private var deleteDialogTitle: LocalizedStringKey {
        guard let occurrence = viewModel.pendingDelete else { return "Delete entry?" }
        return occurrence.isRecurring ? "This is a repeating entry" : "Delete entry?"
    }

    private func deleteDialogMessage(for occurrence: TransactionOccurrence) -> String {
        guard occurrence.isRecurring else {
            return NSLocalizedString("This cannot be undone.", comment: "Delete message")
        }
        return NSLocalizedString(
            "Choose how much of the series to remove. Past entries you keep stay in your history.",
            comment: "Delete message"
        )
    }

    @ViewBuilder
    private func deleteActions(for occurrence: TransactionOccurrence) -> some View {
        if occurrence.isRecurring {
            Button("Delete only this one", role: .destructive) {
                store.deleteOccurrence(occurrence, scope: .thisOccurrenceOnly)
                viewModel.pendingDelete = nil
            }
            Button("Delete this and all future", role: .destructive) {
                store.deleteOccurrence(occurrence, scope: .thisAndFutureOccurrences)
                viewModel.pendingDelete = nil
            }
            Button("Delete the whole series, including history", role: .destructive) {
                store.deleteOccurrence(occurrence, scope: .entireSeriesIncludingHistory)
                viewModel.pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { viewModel.pendingDelete = nil }
        } else {
            Button("Delete", role: .destructive) {
                store.deleteOccurrence(occurrence, scope: .thisOccurrenceOnly)
                viewModel.pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { viewModel.pendingDelete = nil }
        }
    }

    // MARK: - Persistence alert

    private var persistenceAlertBinding: Binding<Bool> {
        Binding(
            get: { store.persistenceIssue != nil },
            set: { if !$0 { store.persistenceIssue = nil } }
        )
    }

    private func persistenceMessage(for issue: PersistenceIssue) -> String {
        guard let copy = issue.backupCopy else { return issue.message }
        return issue.message + "\n\n" + String(
            format: NSLocalizedString("A copy of the unreadable file was kept as %@.", comment: "Error detail"),
            copy.lastPathComponent
        )
    }
}

/// `sheet(item:)` for an optional `Identifiable` binding.
extension View {
    func sheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(isPresented: Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )) {
            if let value = item.wrappedValue {
                content(value)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(MockData.previewStore())
        .environmentObject(ReminderScheduler())
}
