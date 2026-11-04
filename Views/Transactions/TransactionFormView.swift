import SwiftUI

struct TransactionFormView: View {
    private enum Field: Hashable {
        case amount
        case note
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TransactionFormViewModel
    @FocusState private var focusedField: Field?

    @State private var isShowingScopeChoice = false
    @State private var isShowingDeleteChoice = false

    init(store: AppStore, mode: TransactionFormViewModel.Mode) {
        _viewModel = StateObject(wrappedValue: TransactionFormViewModel(store: store, mode: mode))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let context = viewModel.linkedContextDescription {
                    Section {
                        Label(context, systemImage: "link")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Picker(selection: $viewModel.type) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.localizedTitle).tag(type)
                        }
                    } label: {
                        Text("Type")
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isLinkedEntry)
                }

                amountAndCategorySection
                billSection

                if viewModel.canEditRecurrence {
                    recurrenceSection
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.expenseAccent)
                    }
                }

                if viewModel.isAdding {
                    saveActionsSection
                }

                if viewModel.editingOccurrence != nil {
                    Section {
                        Button(role: .destructive) {
                            isShowingDeleteChoice = true
                        } label: {
                            Label("Delete entry", systemImage: "trash")
                                .frame(minHeight: AppTheme.minimumTapTarget)
                        }
                    }
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .defaultFocus($focusedField, .amount)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.saveButtonTitle) { attemptSave(thenDismiss: true) }
                        .disabled(!viewModel.isFormValid)
                        .fontWeight(.semibold)
                }

                // The decimal pad has no return key, so without this the
                // keyboard covered the lower rows with no way to dismiss it.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onChange(of: viewModel.type) { _, _ in
                viewModel.handleTypeChange()
            }
            .sheet(isPresented: $viewModel.isShowingCategoryEditor) {
                CategoryEditorView(suggestedKind: viewModel.type == .income ? .income : .expense) {
                    name, icon, kind in
                    viewModel.createCategory(name: name, icon: icon, kind: kind)
                }
            }
            .confirmationDialog(
                "This is a repeating entry",
                isPresented: $isShowingScopeChoice,
                titleVisibility: .visible
            ) {
                Button("Change only this one") { commit(scope: .thisOccurrenceOnly) }
                Button("Change this and all future") { commit(scope: .thisAndFutureOccurrences) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Earlier entries keep the amounts they were recorded with.")
            }
            .confirmationDialog(
                deleteTitle,
                isPresented: $isShowingDeleteChoice,
                titleVisibility: .visible
            ) {
                deleteActions
            }
            .overlay(alignment: .bottom) {
                if let confirmation = viewModel.savedConfirmation {
                    SavedToastView(message: confirmation)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(1.6))
                            viewModel.savedConfirmation = nil
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.savedConfirmation)
        }
    }

    // MARK: - Sections

    private var amountAndCategorySection: some View {
        Section("Details") {
            HStack {
                Text("Amount")
                Spacer()
                TextField(
                    "0",
                    text: Binding(
                        get: { viewModel.amountInput },
                        set: { viewModel.handleAmountChange($0) }
                    )
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.title3.weight(.semibold))
                .focused($focusedField, equals: .amount)
                .accessibilityLabel(Text("Amount"))
            }

            // The picker and "add new" sit together, so making a category is
            // part of choosing one rather than a trip to Settings.
            HStack {
                Picker(selection: $viewModel.selectedCategoryID) {
                    ForEach(viewModel.availableCategories) { category in
                        Text("\(category.icon) \(category.localizedName)").tag(category.id)
                    }
                } label: {
                    Text("Category")
                }
                .disabled(viewModel.isLinkedEntry)

                Button {
                    viewModel.isShowingCategoryEditor = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityLabel(Text("Add a new category"))
            }

            DatePicker("Date", selection: $viewModel.date, displayedComponents: [.date])
        }
    }

    private var billSection: some View {
        Section {
            TextField("Note", text: $viewModel.note, axis: .vertical)
                .lineLimit(1...3)
                .focused($focusedField, equals: .note)

            Toggle(isOn: $viewModel.isFeatured) {
                Label("Save as a bill", systemImage: "bookmark")
            }

            AttachmentStripView(attachments: $viewModel.attachments)
        } header: {
            Text("Note and bill")
        } footer: {
            Text(viewModel.isFeatured
                 ? "Bills are collected under Activities so you can find them again."
                 : "Attach a photo or PDF of the bill, and mark it to find it later.")
        }
    }

    private var recurrenceSection: some View {
        Section {
            Picker(selection: $viewModel.recurrenceRule) {
                ForEach(RecurrenceRule.allCases) { rule in
                    Text(rule.localizedTitle).tag(rule)
                }
            } label: {
                Text("Repeat")
            }

            if viewModel.recurrenceRule.repeats {
                Toggle("Has an end date", isOn: $viewModel.hasEndDate)

                if viewModel.hasEndDate {
                    DatePicker(
                        "Ends",
                        selection: $viewModel.endDate,
                        in: viewModel.date...,
                        displayedComponents: [.date]
                    )
                }
            }
        } header: {
            Text("Repeat")
        } footer: {
            if viewModel.recurrenceRule.repeats {
                Text("Dates up to today are recorded as real entries. Later dates are shown as forecasts until they arrive.")
            }
        }
    }

    private var saveActionsSection: some View {
        Section {
            Button {
                attemptSave(thenDismiss: true)
            } label: {
                Text("Save")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isFormValid)

            Button {
                attemptSave(thenDismiss: false)
            } label: {
                Text("Save and add another")
                    .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
            }
            .disabled(!viewModel.isFormValid)
        } footer: {
            Text("Save and add another keeps the type, category and date so a stack of receipts goes in quickly.")
        }
    }

    // MARK: - Delete

    private var deleteTitle: LocalizedStringKey {
        guard let occurrence = viewModel.editingOccurrence, occurrence.isRecurring else {
            return "Delete this entry?"
        }
        return "This is a repeating entry"
    }

    @ViewBuilder
    private var deleteActions: some View {
        if let occurrence = viewModel.editingOccurrence {
            if occurrence.isRecurring {
                Button("Delete only this one", role: .destructive) {
                    viewModel.store.deleteOccurrence(occurrence, scope: .thisOccurrenceOnly)
                    dismiss()
                }
                Button("Delete this and all future", role: .destructive) {
                    viewModel.store.deleteOccurrence(occurrence, scope: .thisAndFutureOccurrences)
                    dismiss()
                }
                Button("Delete the whole series, including history", role: .destructive) {
                    viewModel.store.deleteOccurrence(occurrence, scope: .entireSeriesIncludingHistory)
                    dismiss()
                }
            } else {
                Button("Delete", role: .destructive) {
                    viewModel.store.deleteOccurrence(occurrence, scope: .thisOccurrenceOnly)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Actions

    private func attemptSave(thenDismiss: Bool) {
        focusedField = nil

        guard viewModel.draft() != nil else {
            viewModel.save()
            return
        }

        if viewModel.requiresScopeChoice {
            isShowingScopeChoice = true
            return
        }

        if thenDismiss {
            commit(scope: .thisOccurrenceOnly)
        } else if viewModel.saveAndStartAnother() {
            focusedField = .amount
        }
    }

    private func commit(scope: RecurrenceEditScope) {
        if viewModel.save(scope: scope) {
            dismiss()
        }
    }
}

/// Brief inline confirmation, so "Save and add another" visibly did something.
struct SavedToastView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.incomeSurface, in: Capsule())
            .foregroundStyle(AppTheme.incomeAccent)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .accessibilityAddTraits(.isStaticText)
    }
}
