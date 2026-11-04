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
                Section {
                    Picker(selection: $viewModel.type) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.localizedTitle).tag(type)
                        }
                    } label: {
                        Text("Type")
                    }
                    .pickerStyle(.segmented)
                }

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
                        .focused($focusedField, equals: .amount)
                        .accessibilityLabel(Text("Amount"))
                    }

                    TextField("Note", text: $viewModel.note, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($focusedField, equals: .note)

                    Picker(selection: $viewModel.selectedCategoryID) {
                        ForEach(viewModel.availableCategories) { category in
                            Text("\(category.icon) \(category.localizedName)").tag(category.id)
                        }
                    } label: {
                        Text("Category")
                    }

                    DatePicker("Date", selection: $viewModel.date, displayedComponents: [.date])
                }

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
                    Button(viewModel.saveButtonTitle, action: attemptSave)
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

    private func attemptSave() {
        focusedField = nil

        guard viewModel.draft() != nil else {
            viewModel.save()
            return
        }

        if viewModel.requiresScopeChoice {
            isShowingScopeChoice = true
        } else {
            commit(scope: .thisOccurrenceOnly)
        }
    }

    private func commit(scope: RecurrenceEditScope) {
        if viewModel.save(scope: scope) {
            dismiss()
        }
    }
}

#Preview {
    TransactionFormView(
        store: MockData.previewStore(),
        mode: .add(preselectedCategoryID: "groceries")
    )
}
