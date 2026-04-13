import Combine
import Foundation

@MainActor
final class TransactionFormViewModel: ObservableObject {
    @Published var amountInput: String = ""
    @Published var note: String = ""
    @Published var selectedCategoryID: String = "other"
    @Published var type: TransactionType = .expense
    @Published var date: Date = Date()
    @Published var recurrenceRule: RecurrenceRule = .none
    @Published var errorMessage: String?

    let mode: Mode
    let store: AppStore

    enum Mode {
        case add(preselectedCategoryID: String?)
        case edit(transactionID: UUID)
    }

    init(store: AppStore, mode: Mode) {
        self.store = store
        self.mode = mode
        configureInitialState()
    }

    var title: String {
        switch mode {
        case .add: return "Add Transaction"
        case .edit: return "Edit Transaction"
        }
    }

    var saveButtonTitle: String {
        switch mode {
        case .add: return "Save"
        case .edit: return "Update"
        }
    }

    var availableCategories: [TransactionCategory] {
        DefaultCategories.categories(for: type)
    }

    var isFormValid: Bool {
        DecimalAmountValidator.parsedAmount(from: amountInput) != nil && !selectedCategoryID.isEmpty
    }

    func category(for id: String) -> TransactionCategory {
        DefaultCategories.category(for: id)
    }

    func handleAmountChange(_ newValue: String) {
        if DecimalAmountValidator.isValidAmountInput(newValue) {
            amountInput = DecimalAmountValidator.sanitize(newValue)
        }
    }

    func save() -> Bool {
        guard let amount = DecimalAmountValidator.parsedAmount(from: amountInput) else {
            errorMessage = "Please enter a valid amount with up to 2 decimal places."
            return false
        }

        let draft = TransactionDraft(
            amount: amount,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryID: selectedCategoryID,
            type: type,
            date: date,
            recurrenceRule: recurrenceRule
        )

        switch mode {
        case .add:
            store.addTransaction(draft)
        case .edit(let id):
            store.updateTransaction(id: id, draft: draft)
        }

        return true
    }

    private func configureInitialState() {
        switch mode {
        case .add(let preselectedCategoryID):
            if let categoryID = preselectedCategoryID {
                selectedCategoryID = categoryID
                let category = DefaultCategories.category(for: categoryID)
                switch category.kind {
                case .income: type = .income
                case .expense: type = .expense
                case .both: break
                }
            }

        case .edit(let id):
            guard let transaction = store.state.transactions.first(where: { $0.id == id }) else { return }
            amountInput = String(format: "%.2f", transaction.amount)
            note = transaction.note
            selectedCategoryID = transaction.categoryID
            type = transaction.type
            date = transaction.date
            recurrenceRule = transaction.recurrenceRule ?? .none
        }
    }
}
