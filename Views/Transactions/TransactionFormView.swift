import SwiftUI

struct TransactionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: TransactionFormViewModel
    @FocusState private var amountFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $viewModel.type) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Details") {
                    TextField("Amount", text: Binding(
                        get: { viewModel.amountInput },
                        set: { viewModel.handleAmountChange($0) }
                    ))
                    .keyboardType(.decimalPad)
                    .focused($amountFieldFocused)

                    TextField("Note", text: $viewModel.note, axis: .vertical)
                        .lineLimit(1...3)

                    Picker("Category", selection: $viewModel.selectedCategoryID) {
                        ForEach(viewModel.availableCategories) { category in
                            Text("\(category.icon) \(category.name)").tag(category.id)
                        }
                    }

                    DatePicker("Date", selection: $viewModel.date, displayedComponents: [.date])

                    Picker("Recurring", selection: $viewModel.recurrenceRule) {
                        ForEach(RecurrenceRule.allCases) { rule in
                            Text(rule.title).tag(rule)
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(viewModel.title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.saveButtonTitle) {
                        if viewModel.save() {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isFormValid)
                }
            }
            .onChange(of: viewModel.type) {
                if !viewModel.availableCategories.contains(where: { $0.id == viewModel.selectedCategoryID }) {
                    viewModel.selectedCategoryID = viewModel.availableCategories.first?.id ?? "other"
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    amountFieldFocused = true
                }
            }
        }
    }
}

#Preview {
    TransactionFormView(
        viewModel: TransactionFormViewModel(
            store: AppStore(),
            mode: .add(preselectedCategoryID: "groceries")
        )
    )
}
