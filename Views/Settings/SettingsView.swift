import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var reminderScheduler: ReminderScheduler
    @StateObject var viewModel: SettingsViewModel

    @FocusState private var isStartDayFocused: Bool
    @FocusState private var focusedGoalField: GoalField?

    private enum GoalField: Hashable {
        case target
        case current
    }

    var body: some View {
        Form {
            generalSection
            remindersSection
            repeatingSection
            savingsSection
            backupSection
            aboutSection
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isStartDayFocused = false
                    focusedGoalField = nil
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingReminderEditor) {
            ReminderEditorView(
                reminder: viewModel.editingReminder,
                currency: viewModel.currentCurrency
            ) { saved in
                viewModel.saveReminder(saved)
                Task {
                    await syncReminders()
                }
            }
        }
        .fileExporter(
            isPresented: $viewModel.isShowingExporter,
            document: viewModel.exportDocument,
            contentType: .json,
            defaultFilename: "manatik-backup"
        ) { result in
            // The result used to be thrown away, hiding failed exports.
            viewModel.handleExportResult(result)
        }
        .fileImporter(
            isPresented: $viewModel.isShowingImporter,
            allowedContentTypes: [.json]
        ) { result in
            viewModel.handleImportResult(result)
        }
        .confirmationDialog(
            "Change currency?",
            isPresented: currencyDialogBinding,
            titleVisibility: .visible
        ) {
            Button("Change currency", role: .destructive) {
                viewModel.confirmCurrencyChange()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelCurrencyChange()
            }
        } message: {
            Text(viewModel.currencyChangeWarning)
        }
        .confirmationDialog(
            "Replace all data?",
            isPresented: importDialogBinding,
            titleVisibility: .visible
        ) {
            Button("Replace everything", role: .destructive) {
                viewModel.confirmImport()
                Task { await syncReminders() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelImport()
            }
        } message: {
            Text(viewModel.importWarning)
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Done", isPresented: infoBinding) {
            Button("OK", role: .cancel) { viewModel.infoMessage = nil }
        } message: {
            Text(viewModel.infoMessage ?? "")
        }
        .task {
            await reminderScheduler.refreshAuthorizationStatus()
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section {
            // A plain Picker would switch currency instantly; switching
            // relabels every historical amount without converting it, so it
            // goes through a confirmation instead.
            Menu {
                ForEach(Currency.allCases) { currency in
                    Button {
                        viewModel.requestCurrencyChange(to: currency)
                    } label: {
                        if currency == viewModel.currentCurrency {
                            Label("\(currency.rawValue) \u{2014} \(currency.localizedName)", systemImage: "checkmark")
                        } else {
                            Text("\(currency.rawValue) \u{2014} \(currency.localizedName)")
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Currency")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(viewModel.currentCurrency.rawValue)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(minHeight: AppTheme.minimumTapTarget)
            }
            .accessibilityLabel(Text("Currency"))
            .accessibilityValue(viewModel.currentCurrency.rawValue)

            HStack {
                Text("Period starts on day")
                Spacer()
                TextField("1", text: $viewModel.monthStartDayInput)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .focused($isStartDayFocused)
                    .onChange(of: isStartDayFocused) { _, focused in
                        if !focused { viewModel.commitMonthStartDay() }
                    }
                    .onSubmit { viewModel.commitMonthStartDay() }
                    .accessibilityLabel(Text("Period starts on day of month"))
            }

            if let error = viewModel.monthStartDayError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppTheme.expenseAccent)
            }
        } header: {
            Text("General")
        } footer: {
            Text("Type the day your budgeting month begins, from 1 to 28. Days after 28 are not allowed because they do not exist in February.")
        }
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        Section {
            if reminderScheduler.isBlockedInSystemSettings {
                Label(
                    "Notifications are turned off for manatik in iOS Settings.",
                    systemImage: "bell.slash"
                )
                .font(.footnote)
                .foregroundStyle(AppTheme.expenseAccent)
            } else if reminderScheduler.needsPermissionPrompt {
                Button {
                    Task {
                        await reminderScheduler.requestAuthorization()
                        await syncReminders()
                    }
                } label: {
                    Label("Allow notifications", systemImage: "bell.badge")
                        .frame(minHeight: AppTheme.minimumTapTarget)
                }
            }

            ForEach(viewModel.reminders) { reminder in
                reminderRow(reminder)
            }
            .onDelete { offsets in
                for index in offsets {
                    guard viewModel.reminders.indices.contains(index) else { continue }
                    viewModel.deleteReminder(viewModel.reminders[index])
                }
                Task { await syncReminders() }
            }

            Button {
                viewModel.addReminder()
            } label: {
                Label("Add a payment reminder", systemImage: "plus.circle")
                    .frame(minHeight: AppTheme.minimumTapTarget)
            }
        } header: {
            Text("Payment Reminders")
        } footer: {
            Text("Get a notification before a loan instalment, a utility bill or a subscription is due. Reminders are local to this device.")
        }
    }

    @ViewBuilder
    private func reminderRow(_ reminder: PaymentReminder) -> some View {
        Button {
            viewModel.editReminder(reminder)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(reminder.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(reminderSubtitle(reminder))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { reminder.isEnabled },
                    set: { newValue in
                        viewModel.toggleReminder(reminder, isEnabled: newValue)
                        Task { await syncReminders() }
                    }
                ))
                .labelsHidden()
                .accessibilityLabel(Text("Reminder enabled"))
            }
            .frame(minHeight: AppTheme.minimumTapTarget)
        }
        .buttonStyle(.plain)
    }

    private func reminderSubtitle(_ reminder: PaymentReminder) -> String {
        var parts = [DateFormatting.dayMonthYear(reminder.fireDate)]
        if reminder.repeatRule.repeats {
            parts.append(reminder.repeatRule.localizedTitle)
        }
        let money = reminder.localizedSubtitle(currency: viewModel.currentCurrency)
        if !money.isEmpty {
            parts.append(money)
        }
        if reminder.hasLapsed() {
            parts.append(NSLocalizedString("passed", comment: "Reminder state"))
        }
        return parts.joined(separator: " \u{00B7} ")
    }

    // MARK: - Repeating entries

    private var repeatingSection: some View {
        Section {
            if viewModel.store.state.recurringSeries.isEmpty {
                Text("No repeating entries yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                NavigationLink {
                    RecurringSeriesListView(store: viewModel.store)
                } label: {
                    HStack {
                        Label("Repeating entries", systemImage: "repeat")
                        Spacer()
                        Text("\(viewModel.store.state.recurringSeries.count)")
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: AppTheme.minimumTapTarget)
                }
            }
        } header: {
            Text("Repeating")
        }
    }

    // MARK: - Savings

    private var savingsSection: some View {
        Section {
            HStack {
                Text("Target amount")
                Spacer()
                TextField(
                    "0",
                    text: Binding(
                        get: { viewModel.goalTargetInput },
                        set: { viewModel.handleGoalTargetChange($0) }
                    )
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focusedGoalField, equals: .target)
            }

            if !viewModel.useAmountLeftForProgress {
                HStack {
                    Text("Saved so far")
                    Spacer()
                    TextField(
                        "0",
                        text: Binding(
                            get: { viewModel.goalCurrentInput },
                            set: { viewModel.handleGoalCurrentChange($0) }
                        )
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedGoalField, equals: .current)
                }
            }

            Toggle("Track what is left this period", isOn: $viewModel.useAmountLeftForProgress)
                .onChange(of: viewModel.useAmountLeftForProgress) { _, _ in
                    viewModel.commitSavingsGoal()
                }
        } header: {
            Text("Savings Goal")
        } footer: {
            Text(viewModel.useAmountLeftForProgress
                 ? "Progress follows income minus expenses for the current period."
                 : "Progress follows the saved amount you enter here.")
        }
        // Values are written when a field loses focus, not on every keystroke.
        .onChange(of: focusedGoalField) { _, newValue in
            if newValue == nil { viewModel.commitSavingsGoal() }
        }
    }

    // MARK: - Backup

    private var backupSection: some View {
        Section {
            Button {
                viewModel.prepareExport()
            } label: {
                Label("Export a backup", systemImage: "square.and.arrow.up")
                    .frame(minHeight: AppTheme.minimumTapTarget)
            }

            Button {
                viewModel.isShowingImporter = true
            } label: {
                Label("Import a backup", systemImage: "square.and.arrow.down")
                    .frame(minHeight: AppTheme.minimumTapTarget)
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("\(viewModel.entryCountDescription). Importing replaces everything on this device, so the current data is saved as a file first.")
        }
    }

    private var aboutSection: some View {
        Section {
            Text("manatik keeps your budget on this device only. Nothing is uploaded, so export a backup regularly.")
                .font(.footnote)

            Text(viewModel.appVersionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        } header: {
            Text("About")
        }
    }

    // MARK: - Helpers

    private func syncReminders() async {
        await reminderScheduler.sync(
            reminders: viewModel.store.state.paymentReminders,
            currency: viewModel.currentCurrency
        )
    }

    private var currencyDialogBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingCurrency != nil },
            set: { if !$0 { viewModel.cancelCurrencyChange() } }
        )
    }

    private var importDialogBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingImport != nil },
            set: { if !$0 { viewModel.cancelImport() } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var infoBinding: Binding<Bool> {
        Binding(
            get: { viewModel.infoMessage != nil },
            set: { if !$0 { viewModel.infoMessage = nil } }
        )
    }
}

/// Lets the user end, pause or remove a repeating entry without hunting for one
/// of its rows in the ledger.
struct RecurringSeriesListView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        List {
            ForEach(store.state.recurringSeries) { series in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(DefaultCategories.category(for: series.categoryID).icon)
                            .accessibilityHidden(true)
                        Text(series.note.isEmpty
                             ? DefaultCategories.category(for: series.categoryID).localizedName
                             : series.note)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(
                            CurrencyFormatting.formatSigned(
                                amount: series.amount,
                                type: series.type,
                                currency: store.state.settings.currency
                            )
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent(for: series.type))
                    }

                    Text(detail(for: series))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 14) {
                        Button(series.isPaused ? "Resume" : "Pause") {
                            store.setSeriesPaused(series.id, paused: !series.isPaused)
                        }
                        .font(.footnote.weight(.semibold))

                        Button("End today") {
                            store.setSeriesEndDate(series.id, endDate: Date())
                        }
                        .font(.footnote.weight(.semibold))
                    }
                    .frame(minHeight: AppTheme.minimumTapTarget)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Repeating Entries")
    }

    private func detail(for series: RecurringSeries) -> String {
        var parts = [series.rule.localizedTitle]
        parts.append(
            String(
                format: NSLocalizedString("from %@", comment: "Series detail"),
                DateFormatting.dayMonthYear(series.startDate)
            )
        )
        if let end = series.endDate {
            parts.append(
                String(
                    format: NSLocalizedString("until %@", comment: "Series detail"),
                    DateFormatting.dayMonthYear(end)
                )
            )
        }
        if series.isPaused {
            parts.append(NSLocalizedString("paused", comment: "Series detail"))
        }
        return parts.joined(separator: " \u{00B7} ")
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel(store: MockData.previewStore()))
            .environmentObject(ReminderScheduler())
    }
}
