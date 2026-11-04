import Foundation

@MainActor
final class TransactionFormViewModel: ObservableObject {
    enum Mode {
        case add(preselectedCategoryID: String?)
        case edit(occurrence: TransactionOccurrence)
    }

    @Published var amountInput: String = ""
    @Published var note: String = ""
    @Published var selectedCategoryID: String = "other"
    @Published var type: TransactionType = .expense
    @Published var date: Date = Date()
    @Published var recurrenceRule: RecurrenceRule = .none
    @Published var hasEndDate: Bool = false
    @Published var endDate: Date = Date()

    /// Bookmarks the entry as a bill to find again later.
    @Published var isFeatured: Bool = false
    @Published var attachments: [Attachment] = []

    @Published var isShowingCategoryEditor = false

    /// Shown only after a failed save attempt, so the form does not scold the
    /// user while they are still typing.
    @Published var errorMessage: String?
    /// Brief confirmation after "Save and add another".
    @Published var savedConfirmation: String?

    let mode: Mode
    let store: AppStore

    init(store: AppStore, mode: Mode) {
        self.store = store
        self.mode = mode
        configureInitialState()
    }

    // MARK: - Presentation

    var title: String {
        switch mode {
        case .add: return NSLocalizedString("New Entry", comment: "Form title")
        case .edit: return NSLocalizedString("Edit Entry", comment: "Form title")
        }
    }

    var saveButtonTitle: String {
        switch mode {
        case .add: return NSLocalizedString("Save", comment: "Button")
        case .edit: return NSLocalizedString("Update", comment: "Button")
        }
    }

    var isAdding: Bool {
        switch mode {
        case .add: return true
        case .edit: return false
        }
    }

    var availableCategories: [TransactionCategory] {
        store.categories(for: type)
    }

    /// The five the user reached for most recently, shown before the rest.
    var recentCategories: [TransactionCategory] {
        store.recentCategories(for: type, limit: 5)
    }

    var editingOccurrence: TransactionOccurrence? {
        switch mode {
        case .add: return nil
        case .edit(let occurrence): return occurrence
        }
    }

    var isEditingRecurringOccurrence: Bool {
        editingOccurrence?.isRecurring ?? false
    }

    /// Entries created by a savings goal or a loan are managed from there, so
    /// the form keeps its hands off their links.
    var isLinkedEntry: Bool {
        editingOccurrence?.isLinkedToGoalOrLoan ?? false
    }

    var linkedContextDescription: String? {
        guard let occurrence = editingOccurrence else { return nil }
        if let goalID = occurrence.savingsGoalID, let goal = store.state.savingsGoal(id: goalID) {
            return String(
                format: NSLocalizedString("Money put into %@.", comment: "Linked entry note"),
                goal.name
            )
        }
        if let loanID = occurrence.loanID, let loan = store.state.loan(id: loanID) {
            return String(
                format: NSLocalizedString("Payment towards %@.", comment: "Linked entry note"),
                loan.name
            )
        }
        return nil
    }

    var canEditRecurrence: Bool {
        guard !isLinkedEntry else { return false }
        switch mode {
        case .add: return true
        case .edit: return isEditingRecurringOccurrence
        }
    }

    var isFormValid: Bool {
        DecimalAmountValidator.parsed(from: amountInput) != nil && !selectedCategoryID.isEmpty
    }

    var parsedAmount: Decimal? {
        DecimalAmountValidator.parsed(from: amountInput)
    }

    // MARK: - Input handling

    /// Always assigns a sanitized value, so a keystroke or paste never silently
    /// disappears. Extra decimals are truncated and grouping marks interpreted.
    func handleAmountChange(_ newValue: String) {
        let sanitized = DecimalAmountValidator.sanitize(newValue)
        if sanitized != amountInput {
            amountInput = sanitized
        }
        if errorMessage != nil, DecimalAmountValidator.parsed(from: sanitized) != nil {
            errorMessage = nil
        }
    }

    func handleTypeChange() {
        guard !availableCategories.contains(where: { $0.id == selectedCategoryID }) else { return }
        selectedCategoryID = availableCategories.first?.id ?? "other"
    }

    /// Adds a user-made category and selects it straight away.
    func createCategory(name: String, icon: String, kind: CategoryKind) {
        guard let created = store.addCustomCategory(name: name, icon: icon, kind: kind) else {
            return
        }
        selectedCategoryID = created.id
        if created.kind == .income { type = .income }
        if created.kind == .expense { type = .expense }
    }

    // MARK: - Saving

    func draft() -> TransactionDraft? {
        guard let amount = parsedAmount else { return nil }
        return TransactionDraft(
            amount: amount,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryID: selectedCategoryID,
            type: type,
            date: date,
            recurrenceRule: isLinkedEntry ? .none : recurrenceRule,
            recurrenceEndDate: hasEndDate ? endDate : nil,
            isFeatured: isFeatured,
            attachments: attachments
        )
    }

    var requiresScopeChoice: Bool {
        isEditingRecurringOccurrence
    }

    @discardableResult
    func save(scope: RecurrenceEditScope = .thisOccurrenceOnly) -> Bool {
        guard let draft = draft() else {
            errorMessage = DecimalAmountValidator.validationMessage(for: amountInput)
                ?? NSLocalizedString("Enter an amount.", comment: "Amount validation")
            return false
        }

        switch mode {
        case .add:
            store.addTransaction(draft)
        case .edit(let occurrence):
            store.updateOccurrence(occurrence, draft: draft, scope: scope)
        }
        return true
    }

    /// Saves, then clears the amount, note and attachments while keeping type,
    /// category and date, which is what makes entering a stack of receipts fast.
    @discardableResult
    func saveAndStartAnother() -> Bool {
        guard save() else { return false }

        savedConfirmation = String(
            format: NSLocalizedString("Saved %@", comment: "Confirmation"),
            CurrencyFormatting.format(
                amount: parsedAmount ?? 0,
                currency: store.state.settings.currency
            )
        )

        amountInput = ""
        note = ""
        attachments = []
        isFeatured = false
        recurrenceRule = .none
        hasEndDate = false
        errorMessage = nil
        return true
    }

    // MARK: - Setup

    private func configureInitialState() {
        switch mode {
        case .add(let preselectedCategoryID):
            guard let categoryID = preselectedCategoryID else { return }
            selectedCategoryID = categoryID
            switch store.category(for: categoryID).kind {
            case .income: type = .income
            case .expense: type = .expense
            case .both: break
            }

        case .edit(let occurrence):
            amountInput = DecimalAmountValidator.editingText(for: occurrence.amount)
            note = occurrence.note
            selectedCategoryID = occurrence.categoryID
            type = occurrence.type
            date = occurrence.date
            isFeatured = occurrence.isFeatured
            attachments = store.transaction(id: occurrence.transactionID)?.attachments ?? []

            if let series = store.series(for: occurrence.seriesID) {
                recurrenceRule = series.rule
                if let seriesEnd = series.endDate {
                    hasEndDate = true
                    endDate = seriesEnd
                }
            }
        }
    }
}
