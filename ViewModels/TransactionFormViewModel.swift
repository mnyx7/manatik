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

    /// Shown only after a failed save attempt, so the form does not scold the
    /// user while they are still typing.
    @Published var errorMessage: String?

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

    var availableCategories: [TransactionCategory] {
        DefaultCategories.categories(for: type)
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

    var isEditingProjection: Bool {
        editingOccurrence?.isProjected ?? false
    }

    /// Recurrence is a property of the series, so it is only editable when
    /// creating an entry or when changing a whole series going forward.
    var canEditRecurrence: Bool {
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

    // MARK: - Saving

    func draft() -> TransactionDraft? {
        guard let amount = parsedAmount else { return nil }
        return TransactionDraft(
            amount: amount,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryID: selectedCategoryID,
            type: type,
            date: date,
            recurrenceRule: recurrenceRule,
            recurrenceEndDate: hasEndDate ? endDate : nil
        )
    }

    /// True when saving requires asking how much of a series to affect.
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

    // MARK: - Setup

    private func configureInitialState() {
        switch mode {
        case .add(let preselectedCategoryID):
            guard let categoryID = preselectedCategoryID else { return }
            selectedCategoryID = categoryID
            switch DefaultCategories.category(for: categoryID).kind {
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
