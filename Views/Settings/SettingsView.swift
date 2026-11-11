import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(ReminderScheduler.self) private var reminderScheduler
    @State var viewModel: SettingsViewModel

    @FocusState private var isStartDayFocused: Bool

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
            NavigationLink {
                CategoryManagerView(viewModel: viewModel)
            } label: {
                HStack {
                    Label("My categories", systemImage: "tag")
                    Spacer()
                    Text("\(viewModel.allCategories.count)")
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
            NavigationLink {
                FeedbackView(viewModel: viewModel)
            } label: {
                HStack {
                    Label("Feedback and ideas", systemImage: "bubble.left.and.text.bubble.right")
                    Spacer()
                    if !viewModel.feedbackNotes.isEmpty {
                        Text("\(viewModel.feedbackNotes.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: AppTheme.minimumTapTarget)
            }
        } header: {
            Text("Feedback")
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
                Toggle(isOn: Binding(
                    get: { viewModel.showsRecentsFirst },
                    set: { viewModel.showsRecentsFirst = $0 }
                )) {
                    Label("Show recent first", systemImage: "clock.arrow.circlepath")
                }
            } footer: {
                Text(viewModel.showsRecentsFirst
                     ? "The entry form leads with the categories you used most recently."
                     : "The entry form follows the order below.")
            }

            Section {
                // Offsets line up with this list, which is why it shows hidden
                // categories too rather than filtering them out.
                ForEach(viewModel.allCategories) { category in
                    row(category)
                }
                .onMove { source, destination in
                    viewModel.moveCategories(from: source, to: destination)
                }
            } header: {
                Text("Order")
            } footer: {
                Text("Drag to reorder. Hidden categories stay out of the pickers but keep the entries already filed under them.")
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

                    if hidden {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }

                Text(String(format: NSLocalizedString("%d entries", comment: "Count"), uses))
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

/// Somewhere to write down what the app should do better.
///
/// There is no server to send this to, so notes are kept on the device and
/// each one can be shared wherever the user likes.
struct FeedbackView: View {
    @Bindable var viewModel: SettingsViewModel
    @FocusState private var isWriting: Bool

    private var canSave: Bool {
        !viewModel.feedbackDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField(
                    "What would make manatik better?",
                    text: $viewModel.feedbackDraft,
                    axis: .vertical
                )
                .lineLimit(4...10)
                .focused($isWriting)

                Button {
                    isWriting = false
                    viewModel.saveFeedback()
                } label: {
                    Label("Save this note", systemImage: "square.and.pencil")
                        .frame(minHeight: AppTheme.minimumTapTarget)
                }
                .disabled(!canSave)
            } header: {
                Text("New note")
            } footer: {
                Text("Notes are kept on this device with the app version attached, so you can send them on whenever you like.")
            }

            if !viewModel.feedbackNotes.isEmpty {
                Section("Saved notes") {
                    ForEach(viewModel.feedbackNotes) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(note.text)
                                .font(.subheadline)

                            HStack(spacing: 10) {
                                Text(DateFormatting.dayMonthYear(note.createdAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(note.appVersion)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)

                                Spacer()

                                ShareLink(item: note.shareableText) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .font(.caption.weight(.semibold))
                                        .labelStyle(.iconOnly)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            guard viewModel.feedbackNotes.indices.contains(index) else { continue }
                            viewModel.deleteFeedback(viewModel.feedbackNotes[index])
                        }
                    }
                }
            }
        }
        .navigationTitle("Feedback")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isWriting = false }
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
