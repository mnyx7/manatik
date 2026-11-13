import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(ReminderScheduler.self) private var reminderScheduler
    @State var viewModel: SettingsViewModel

    @FocusState private var isStartDayFocused: Bool
    @State private var isShowingCurrencyPicker = false

    var body: some View {
        Form {
            homeStyleSection
            generalSection
            PaymentRemindersSection(viewModel: viewModel)
            organiseSection
            backupSection
            feedbackSection
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isStartDayFocused = false }
            }
        }
        .fileExporter(
            isPresented: $viewModel.isShowingExporter,
            document: viewModel.exportDocument,
            contentType: .json,
            defaultFilename: "muna-backup"
        ) { result in
            viewModel.handleExportResult(result)
        }
        .fileImporter(
            isPresented: $viewModel.isShowingImporter,
            allowedContentTypes: viewModel.importKind == .csv
                ? [.commaSeparatedText, .tabSeparatedText, .plainText]
                : [.json]
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
        .alert(
            "Add these entries?",
            isPresented: Binding(
                get: { viewModel.pendingCSV != nil },
                set: { if !$0 { viewModel.pendingCSV = nil } }
            )
        ) {
            Button("Add") { viewModel.confirmCSVImport() }
            Button("Cancel", role: .cancel) { viewModel.pendingCSV = nil }
        } message: {
            Text(viewModel.csvSummary)
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
            Button {
                isShowingCurrencyPicker = true
            } label: {
                HStack {
                    Text("Main currency")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(viewModel.currency.symbol) \(viewModel.currency.rawValue)")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(minHeight: AppTheme.minimumTapTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(viewModel.currency.localizedName))
            .sheet(isPresented: $isShowingCurrencyPicker) {
                CurrencyPickerView(
                    title: "Main currency",
                    selection: viewModel.currency,
                    pinned: viewModel.store.pinnedCurrencies
                ) { viewModel.currency = $0 }
            }

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
            .frame(minHeight: AppTheme.minimumTapTarget)
            .contentShape(.rect)
            .onTapGesture { isStartDayFocused = true }

            if let error = viewModel.monthStartDayError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppTheme.expenseAccent)
            }
        } header: {
            Text("General")
        } footer: {
            Text("New entries start in the main currency, and you can pick another one on each entry. Totals add up entries in the main currency; amounts are never converted.\n\nType the day your budgeting month begins, from 1 to 28. Days after 28 are not allowed because they do not exist in February.")
        }
    }

    // MARK: - Home page

    /// Thumbnails in one row; tapping one applies it straight away.
    private var homeStyleSection: some View {
        Section {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(HomeStyle.allCases) { style in
                            HomeStyleThumbnail(
                                style: style,
                                isSelected: viewModel.homeStyle == style
                            ) {
                                withAnimation(.snappy) { viewModel.homeStyle = style }
                            }
                            .id(style)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .scrollClipDisabled()
                // A chosen style further along the row would otherwise sit
                // off-screen with nothing showing which one is active.
                .onAppear { proxy.scrollTo(viewModel.homeStyle, anchor: .center) }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            Text("Home page")
        }
    }

    // MARK: - Organise

    private var organiseSection: some View {
        Section {
            NavigationLink(value: RootDestination.categoryManager) {
                HStack {
                    Label("My categories", systemImage: "tag")
                    Spacer()
                    Text("\(viewModel.allCategories.count)")
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: AppTheme.minimumTapTarget)
            }

            if !viewModel.store.state.recurringSeries.isEmpty {
                NavigationLink(value: RootDestination.recurringSeries) {
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
                viewModel.beginBackupImport()
            } label: {
                Label("Import a backup", systemImage: "square.and.arrow.down")
                    .frame(minHeight: AppTheme.minimumTapTarget)
            }

            Button {
                viewModel.beginCSVImport()
            } label: {
                Label("Import from another app (CSV)", systemImage: "tablecells")
                    .frame(minHeight: AppTheme.minimumTapTarget)
            }
        } header: {
            Text("Backup")
        } footer: {
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

    // MARK: - Feedback

    private var feedbackSection: some View {
        Section {
            Button {
                FeedbackMailer.shared.compose()
            } label: {
                Label("Send feedback", systemImage: "envelope")
                    .frame(minHeight: AppTheme.minimumTapTarget)
            }
        } header: {
            Text("Feedback")
        } footer: {
            Text("Or shake your phone on any screen to report a problem with a screenshot of it.")
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink(value: RootDestination.about) {
                Label("About us", systemImage: "info.circle")
                    .frame(minHeight: AppTheme.minimumTapTarget)
            }
        } footer: {
            Text(viewModel.appVersionText)
                .frame(maxWidth: .infinity, alignment: .center)
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

/// Every category in one place: reorder, hide, edit, delete, add.
struct CategoryManagerView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.editMode) private var editMode

    var body: some View {
        List {
            Section {
                Picker("Type", selection: $viewModel.managedType) {
                    Text("Expense").tag(TransactionType.expense)
                    Text("Income").tag(TransactionType.income)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            } footer: {
                Text(viewModel.managedType == .expense
                     ? "These are the categories you can pick when adding an expense."
                     : "These are the categories you can pick when adding income.")
            }

            Section {
                Toggle(isOn: Binding(
                    get: { viewModel.showsRecentsFirst },
                    set: { viewModel.showsRecentsFirst = $0 }
                )) {
                    Label("Show recent first", systemImage: "clock.arrow.circlepath")
                }
            } footer: {
                Text(viewModel.showsRecentsFirst
                     ? "The entry form starts with the five you used most recently, then follows the order below. Turn this off to use only your order."
                     : "The entry form shows categories exactly in the order below.")
            }

            Section {
                // Offsets line up with this list, which is why it shows hidden
                // categories too rather than filtering them out.
                ForEach(viewModel.managedCategories) { category in
                    row(category)
                }
                .onMove { source, destination in
                    viewModel.moveManagedCategories(from: source, to: destination)
                }
            } header: {
                Text(viewModel.managedType == .expense ? "Expense order" : "Income order")
            } footer: {
                Text("Tap Edit, then drag to reorder. Categories marked “both” appear in Expense and Income. Hidden categories stay out of the pickers but keep the entries already filed under them.")
            }

            Section {
                Button {
                    viewModel.editingCategory = nil
                    viewModel.isShowingCategoryEditor = true
                } label: {
                    Label("Add a category", systemImage: "plus.circle")
                        .frame(minHeight: AppTheme.minimumTapTarget)
                }

                Button {
                    viewModel.resetCategoryOrder()
                } label: {
                    Label("Reset to the original order", systemImage: "arrow.uturn.backward")
                        .frame(minHeight: AppTheme.minimumTapTarget)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $viewModel.isShowingCategoryEditor) {
            CategoryEditorView(
                suggestedKind: .expense,
                editing: viewModel.editingCategory
            ) { name, icon, kind in
                if let editing = viewModel.editingCategory {
                    viewModel.saveCategoryEdit(id: editing.id, name: name, icon: icon, kind: kind)
                } else {
                    viewModel.createCategory(name: name, icon: icon, kind: kind)
                }
                viewModel.editingCategory = nil
            }
        }
    }

    @ViewBuilder
    private func row(_ category: TransactionCategory) -> some View {
        let hidden = viewModel.isHidden(category)
        let uses = viewModel.usageCount(for: category)

        HStack(spacing: 12) {
            CategoryIconView(category: category, size: .medium)
                .opacity(hidden ? 0.4 : 1)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(category.localizedName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(hidden ? .secondary : .primary)

                    if category.isCustom {
                        Text("Mine")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AppTheme.savingsSurface, in: Capsule())
                            .foregroundStyle(AppTheme.savingsAccent)
                    }

                    if category.kind == .both {
                        Text("both")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                            .foregroundStyle(.secondary)
                    }

                    if hidden {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }

                Text(uses == 1
                     ? NSLocalizedString("1 entry", comment: "Count")
                     : String(format: NSLocalizedString("%d entries", comment: "Count"), uses))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(minHeight: AppTheme.minimumTapTarget)
        .accessibilityElement(children: .combine)
        .accessibilityValue(
            hidden
                ? NSLocalizedString("hidden", comment: "Accessibility")
                : NSLocalizedString("shown", comment: "Accessibility")
        )
        .swipeActions(edge: .trailing) {
            if category.isCustom {
                Button(role: .destructive) {
                    viewModel.deleteCustomCategory(category)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            if viewModel.canHide(category) {
                Button {
                    viewModel.setHidden(category, hidden: !hidden)
                } label: {
                    Label(
                        hidden ? "Show" : "Hide",
                        systemImage: hidden ? "eye" : "eye.slash"
                    )
                }
                .tint(.secondary)
            }
        }
        .contextMenu {
            if category.isCustom {
                Button {
                    viewModel.editingCategory = category
                    viewModel.isShowingCategoryEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if viewModel.canHide(category) {
                Button {
                    viewModel.setHidden(category, hidden: !hidden)
                } label: {
                    Label(
                        hidden ? "Show in pickers" : "Hide from pickers",
                        systemImage: hidden ? "eye" : "eye.slash"
                    )
                }
            }

            if category.isCustom {
                Button(role: .destructive) {
                    viewModel.deleteCustomCategory(category)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

/// Lets the user end, pause or remove a repeating entry without hunting for one
/// of its rows in the ledger.
struct RecurringSeriesListView: View {
    let store: AppStore

    var body: some View {
        List {
            ForEach(store.state.recurringSeries) { series in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        CategoryIconView(
                            category: store.category(for: series.categoryID),
                            size: .small
                        )
                        Text(series.note.isEmpty
                             ? store.category(for: series.categoryID).localizedName
                             : series.note)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(
                            CurrencyFormatting.formatSigned(
                                amount: series.amount,
                                type: series.type,
                                currency: series.currency ?? store.mainCurrency
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
