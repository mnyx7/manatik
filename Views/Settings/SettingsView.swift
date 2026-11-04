import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var reminderScheduler: ReminderScheduler
    @StateObject var viewModel: SettingsViewModel

    @FocusState private var isStartDayFocused: Bool

    var body: some View {
        Form {
            generalSection
            remindersSection
            organiseSection
            backupSection
            aboutSection
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isStartDayFocused = false }
            }
        }
        .sheet(isPresented: $viewModel.isShowingReminderEditor) {
            ReminderEditorView(
                reminder: viewModel.editingReminder,
                currency: viewModel.currentCurrency
            ) { saved in
                viewModel.saveReminder(saved)
                Task { await syncReminders() }
            }
        }
        .fileExporter(
            isPresented: $viewModel.isShowingExporter,
            document: viewModel.exportDocument,
            contentType: .json,
            defaultFilename: "manatik-backup"
        ) { result in
            viewModel.handleExportResult(result)
        }
        .fileImporter(
            isPresented: $viewModel.isShowingImporter,
            allowedContentTypes: [.json]
        ) { result in
            viewModel.handleImportResult(result)
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
            // Applied on selection; no confirmation step.
            Picker(selection: Binding(
                get: { viewModel.currency },
                set: { viewModel.currency = $0 }
            )) {
                ForEach(Currency.allCases) { currency in
                    Text("\(currency.rawValue) \u{2014} \(currency.localizedName)")
                        .tag(currency)
                }
            } label: {
                Text("Currency")
            }
            .frame(minHeight: AppTheme.minimumTapTarget)

            HStack {
                Text("Start date of the month")
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
                    .accessibilityLabel(Text("Start day of the month"))
            }

            if let error = viewModel.monthStartDayError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppTheme.expenseAccent)
            }
        } header: {
            Text("General")
        } footer: {
            Text("Changing the currency relabels existing amounts; it does not convert them.\n\nType the day your budgeting month begins, from 1 to 28. Days after 28 are not allowed because they do not exist in February.")
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

    // MARK: - Organise

    private var organiseSection: some View {
        Section {
            NavigationLink {
                CustomCategoriesListView(viewModel: viewModel)
            } label: {
                HStack {
                    Label("My categories", systemImage: "tag")
                    Spacer()
                    Text("\(viewModel.customCategories.count)")
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: AppTheme.minimumTapTarget)
            }

            if !viewModel.store.state.recurringSeries.isEmpty {
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
            Text("Organise")
        } footer: {
            Text("Add or remove your own categories here, or from the New chip while entering an amount.")
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
            // Said plainly here rather than discovered on a restore.
            Text(backupFooterText)
        }
    }

    private var backupFooterText: String {
        var text = viewModel.entryCountDescription + ". "
        text += NSLocalizedString(
            "Importing replaces everything on this device, so the current data is saved as a file first.",
            comment: "Backup footer"
        )
        if viewModel.attachmentCount > 0 {
            text += " " + String(
                format: NSLocalizedString(
                    "Your %d bill photos and documents stay on this device: the backup file records that they existed but does not contain them.",
                    comment: "Backup footer"
                ),
                viewModel.attachmentCount
            )
        }
        return text
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

/// The user's own categories, with how many entries each one holds.
struct CustomCategoriesListView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section {
                Button {
                    viewModel.isShowingCategoryEditor = true
                } label: {
                    Label("Add a category", systemImage: "plus.circle")
                        .frame(minHeight: AppTheme.minimumTapTarget)
                }
            }

            if viewModel.customCategories.isEmpty {
                Text("You have not added any categories yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.customCategories) { category in
                    HStack(spacing: 12) {
                        Text(category.icon)
                            .font(.title3)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.localizedName)
                                .font(.subheadline.weight(.medium))
                            Text(
                                String(
                                    format: NSLocalizedString("%d entries", comment: "Count"),
                                    viewModel.usageCount(for: category)
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .frame(minHeight: AppTheme.minimumTapTarget)
                    .accessibilityElement(children: .combine)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteCustomCategory(category)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteCustomCategory(category)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        guard viewModel.customCategories.indices.contains(index) else { continue }
                        viewModel.deleteCustomCategory(viewModel.customCategories[index])
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.isShowingCategoryEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text("Add a category"))
            }
        }
        .sheet(isPresented: $viewModel.isShowingCategoryEditor) {
            CategoryEditorView(suggestedKind: .expense) { name, icon, kind in
                viewModel.createCategory(name: name, icon: icon, kind: kind)
            }
        }
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
                        Text(store.category(for: series.categoryID).icon)
                            .accessibilityHidden(true)
                        Text(series.note.isEmpty
                             ? store.category(for: series.categoryID).localizedName
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
