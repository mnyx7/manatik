import SwiftUI

/// Screens pushed on top of whichever tab is showing. The tabs themselves are
/// not destinations: they swap the stack's root, so every tab behaves the same
/// way instead of Home alone popping back.
enum RootDestination: Hashable {
    case savings
    case loans
    case savingsGoal(UUID)
    case loanDetail(UUID)
    case yearOverview
    case reminders
    case categoryManager
    case recurringSeries
    case feedback
}

/// The app shell: content under a floating Liquid Glass bar carrying Home,
/// Activity, add, Overview and Settings.
///
/// The bar floats over the content rather than reserving a strip beneath it.
/// That is the point of the material — the page scrolls underneath and shows
/// through — so each screen keeps bottom content margin for the bar's height
/// instead of being clipped by it.
struct RootView: View {
    enum Tab: String, Hashable, CaseIterable {
        case home
        case activities
        case overview
        case settings

        var title: LocalizedStringKey {
            switch self {
            case .home: return "Home"
            case .activities: return "Activity"
            case .overview: return "Overview"
            case .settings: return "Settings"
            }
        }

        /// Both states of the symbol: the selected tab fills in, which is how
        /// every Apple tab bar signals position.
        var symbol: String {
            switch self {
            case .home: return "house"
            case .activities: return "list.bullet"
            case .overview: return "chart.pie"
            case .settings: return "gearshape"
            }
        }

        var selectedSymbol: String {
            switch self {
            case .home: return "house.fill"
            case .activities: return "list.bullet"
            case .overview: return "chart.pie.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    @Environment(AppStore.self) private var store
    @Environment(ReminderScheduler.self) private var reminderScheduler
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = HomeViewModel()
    @State private var tab: Tab = .home
    @State private var path: [RootDestination] = []

    /// Lets the tab buttons and the add button share one glass system, so they
    /// blend and separate together instead of reading as two unrelated chips.
    @Namespace private var glassNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $path) {
                content
                    .navigationDestination(for: RootDestination.self, destination: destination)
            }

            if !viewModel.isSearchFocused {
                bottomBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.25), value: viewModel.isSearchFocused)
        .background(AppBackgroundView())
        .tint(Color.accentColor)
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
        .sheet(isPresented: $viewModel.isShowingGoalEditor) {
            SavingsGoalEditorView(
                goal: viewModel.editingGoal,
                currency: store.state.settings.currency
            ) { name, target, opening, dueDate, note in
                if var existing = viewModel.editingGoal {
                    existing.name = name
                    existing.targetAmount = target
                    existing.openingAmount = opening
                    existing.dueDate = dueDate
                    existing.note = note
                    store.updateSavingsGoal(existing)
                } else {
                    store.addSavingsGoal(
                        name: name,
                        targetAmount: target,
                        openingAmount: opening,
                        dueDate: dueDate,
                        note: note
                    )
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingLoanEditor) {
            LoanEditorView(
                loan: viewModel.editingLoan,
                currency: store.state.settings.currency
            ) { name, initial, paid, monthly, startDate, dueDate, note in
                if var existing = viewModel.editingLoan {
                    existing.name = name
                    existing.initialAmount = initial
                    existing.openingPaidAmount = paid
                    existing.monthlyPayment = monthly
                    existing.startDate = startDate
                    existing.dueDate = dueDate
                    existing.note = note
                    store.updateLoan(existing)
                } else {
                    store.addLoan(
                        name: name,
                        initialAmount: initial,
                        openingPaidAmount: paid,
                        monthlyPayment: monthly,
                        startDate: startDate,
                        dueDate: dueDate,
                        note: note
                    )
                }
            }
        }
        .sheet(item: $viewModel.contributingGoal) { goal in
            let progress = store.progress(for: goal)
            AmountEntrySheet(
                title: "Add to savings",
                subtitle: goal.name,
                actionTitle: "Add",
                accent: AppTheme.savingsAccent,
                currency: store.state.settings.currency,
                suggestedAmount: progress.remainingAmount
            ) { amount, date, note in
                store.contribute(to: goal, amount: amount, date: date, note: note)
            }
        }
        .sheet(item: $viewModel.payingLoan) { loan in
            let progress = store.progress(for: loan)
            AmountEntrySheet(
                title: "Record a payment",
                subtitle: loan.name,
                actionTitle: "Record",
                accent: AppTheme.loanAccent,
                currency: store.state.settings.currency,
                suggestedAmount: loan.monthlyPayment ?? progress.remainingAmount
            ) { amount, date, note in
                store.recordPayment(on: loan, amount: amount, date: date, note: note)
            }
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
        #if DEBUG
        .task { applyQALaunchRouteIfNeeded() }
        #endif
        // Mirror the saved choice into the formatter's switch, at launch, on
        // a toggle and after a backup is restored.
        .onChange(of: store.state.settings.hidesAmounts, initial: true) { _, hidden in
            AmountPrivacy.shared.isHidden = hidden
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home:
            if store.state.settings.homeStyle == .classic {
                HomeView(
                    viewModel: viewModel,
                    onOpenActivities: { scope in
                        viewModel.scope = scope
                        select(.activities)
                    },
                    onOpenSavings: { push(.savings) },
                    onOpenLoans: { push(.loans) },
                    onOpenGoal: { push(.savingsGoal($0)) },
                    onOpenLoan: { push(.loanDetail($0)) }
                )
            } else {
                IllustratedHomeView(
                    viewModel: viewModel,
                    style: store.state.settings.homeStyle,
                    onOpenActivities: { scope in
                        viewModel.scope = scope
                        select(.activities)
                    },
                    onOpenOverview: { select(.overview) },
                    onOpenSavings: { push(.savings) },
                    onOpenLoans: { push(.loans) },
                    onOpenReminders: { push(.reminders) }
                )
            }
        case .activities:
            ActivitiesView(viewModel: viewModel)
        case .overview:
            OverviewView()
        case .settings:
            SettingsView(viewModel: SettingsViewModel(store: store))
        }
    }

    // MARK: - Floating glass bar

    private var bottomBar: some View {
        // One container means the bar and the add button are a single piece of
        // glass as far as the renderer is concerned: they refract together and
        // the add button's tint bleeds correctly into the capsule beside it.
        GlassEffectContainer(spacing: 18) {
            HStack(spacing: 10) {
                HStack(spacing: 2) {
                    tabButton(.home)
                    tabButton(.activities)
                }

                addButton

                HStack(spacing: 2) {
                    tabButton(.overview)
                    tabButton(.settings)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
            .glassEffectID("bar", in: glassNamespace)
        }
        .padding(.bottom, 8)
    }

    private var addButton: some View {
        Button {
            viewModel.beginAdd()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(Color.accentColor.opacity(0.85)).interactive(),
            in: .circle
        )
        .glassEffectID("add", in: glassNamespace)
        .accessibilityLabel(Text("Add income or expense"))
    }

    @ViewBuilder
    private func tabButton(_ slot: Tab) -> some View {
        let isActive = tab == slot && path.isEmpty

        Button {
            select(slot)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: isActive ? slot.selectedSymbol : slot.symbol)
                    .font(.system(size: 17, weight: isActive ? .semibold : .regular))
                    .symbolVariant(.none)
                Text(slot.title)
                    .font(.system(size: 10, weight: isActive ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 60, height: 46)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
        .accessibilityLabel(slot.title)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    /// Switches which tab's screen is the stack root. Any pushed screen is
    /// dropped, the way a tab bar normally behaves. Tapping the tab already
    /// showing does nothing.
    private func select(_ newTab: Tab) {
        guard newTab != tab || !path.isEmpty else { return }
        withAnimation(.smooth(duration: 0.25)) {
            path.removeAll()
            tab = newTab
        }
    }

    /// Pushes on top of wherever the user is, for screens reached from content.
    private func push(_ destination: RootDestination) {
        path.append(destination)
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destination(_ destination: RootDestination) -> some View {
        switch destination {
        case .savings:
            SavingsView(
                viewModel: viewModel,
                onOpenGoal: { push(.savingsGoal($0)) }
            )
        case .loans:
            LoansView(
                viewModel: viewModel,
                onOpenLoan: { push(.loanDetail($0)) }
            )
        case .savingsGoal(let id):
            SavingsGoalDetailView(goalID: id, viewModel: viewModel)
        case .loanDetail(let id):
            LoanDetailView(loanID: id, viewModel: viewModel)
        case .yearOverview:
            YearlyOverviewView(
                viewModel: YearlyOverviewViewModel(store: store, year: store.selectedYear)
            )
        case .reminders:
            RemindersView(viewModel: SettingsViewModel(store: store))
        // Settings pages go through the path too. A view-based NavigationLink
        // is not recorded in `path`, so the tab bar thought nothing was open
        // and swapped the screen underneath while the page stayed on top.
        case .categoryManager:
            CategoryManagerView(viewModel: SettingsViewModel(store: store))
        case .recurringSeries:
            RecurringSeriesListView(store: store)
        case .feedback:
            FeedbackView(viewModel: SettingsViewModel(store: store))
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
        if occurrence.isSavingsContribution {
            return NSLocalizedString(
                "This also removes the money from its savings goal.",
                comment: "Delete message"
            )
        }
        if occurrence.isLoanPayment {
            return NSLocalizedString(
                "This also removes the payment from its loan.",
                comment: "Delete message"
            )
        }
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

    // MARK: - Screenshot QA

    #if DEBUG
    private func applyQALaunchRouteIfNeeded() {
        if let style = QALaunch.homeStyle {
            store.updateSettings(homeStyle: style)
        }
        if CommandLine.arguments.contains("-qa-hide-amounts") {
            store.updateSettings(hidesAmounts: true)
        }
        if let name = QALaunch.tab, let slot = Tab(rawValue: name) {
            tab = slot
        }

        switch QALaunch.route {
        case "savings": path = [.savings]
        case "loans": path = [.loans]
        case "year": path = [.yearOverview]
        case "goal": path = [.savingsGoal(QALaunch.goalID)]
        case "loan": path = [.loanDetail(QALaunch.loanID)]
        case "add", "currency": viewModel.isShowingAddSheet = true
        case "reminders": path = [.reminders]
        case "categories": tab = .settings; path = [.categoryManager]
        case "usd":
            viewModel.editingOccurrence = store.occurrences(in: store.selectedPeriod)
                .first { $0.currency == .usd }
        case "bill":
            viewModel.editingOccurrence = store.occurrences(in: store.selectedPeriod)
                .first { $0.transactionID == QALaunch.billTransactionID }
        default: break
        }
    }
    #endif
}

#Preview {
    RootView()
        .environment(AppStore(persistence: InMemoryPersistence(), initialState: MockData.previewState()))
        .environment(ReminderScheduler())
}
