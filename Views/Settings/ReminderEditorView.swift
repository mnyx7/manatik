import SwiftUI

/// Create or edit one payment reminder.
struct ReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let existing: PaymentReminder?
    private let currency: Currency
    private let onSave: (PaymentReminder) -> Void

    @State private var title: String
    @State private var amountInput: String
    @State private var categoryID: String?
    @State private var fireDate: Date
    @State private var repeatRule: RecurrenceRule
    @State private var isEnabled: Bool
    @FocusState private var isAmountFocused: Bool

    init(
        reminder: PaymentReminder?,
        currency: Currency,
        onSave: @escaping (PaymentReminder) -> Void
    ) {
        self.existing = reminder
        self.currency = currency
        self.onSave = onSave

        _title = State(initialValue: reminder?.title ?? "")
        _amountInput = State(
            initialValue: reminder?.amount.map { DecimalAmountValidator.editingText(for: $0) } ?? ""
        )
        _categoryID = State(initialValue: reminder?.categoryID)
        _fireDate = State(initialValue: reminder?.fireDate ?? Self.defaultFireDate())
        _repeatRule = State(initialValue: reminder?.repeatRule ?? .monthly)
        _isEnabled = State(initialValue: reminder?.isEnabled ?? true)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmedTitle.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("What is due") {
                    TextField("For example: Home loan instalment", text: $title, axis: .vertical)
                        .lineLimit(1...2)

                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField(
                            NSLocalizedString("Optional", comment: "Placeholder"),
                            text: Binding(
                                get: { amountInput },
                                set: { amountInput = DecimalAmountValidator.sanitize($0) }
                            )
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($isAmountFocused)
                    }
                    .frame(minHeight: AppTheme.minimumTapTarget)
                    .contentShape(.rect)
                    .onTapGesture { isAmountFocused = true }

                    Picker(selection: $categoryID) {
                        Text("None").tag(String?.none)
                        ForEach(DefaultCategories.all) { category in
                            Label(
                                category.localizedName,
                                systemImage: CategoryVisuals.symbolName(for: category)
                            )
                            .tag(String?.some(category.id))
                        }
                    } label: {
                        Text("Category")
                    }
                }

                Section {
                    DatePicker(
                        "Remind me",
                        selection: $fireDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Picker(selection: $repeatRule) {
                        ForEach(RecurrenceRule.allCases) { rule in
                            Text(rule.localizedTitle).tag(rule)
                        }
                    } label: {
                        Text("Repeat")
                    }

                    Toggle("Enabled", isOn: $isEnabled)
                } header: {
                    Text("When")
                } footer: {
                    Text(repeatRule.repeats
                         ? NSLocalizedString("You will be reminded at this time on every matching date.", comment: "Reminder footer")
                         : NSLocalizedString("You will be reminded once, at this date and time.", comment: "Reminder footer"))
                }
            }
            .navigationTitle(existing == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isAmountFocused = false }
                }
            }
        }
    }

    private func save() {
        var reminder = existing ?? PaymentReminder(title: trimmedTitle, fireDate: fireDate)
        reminder.title = trimmedTitle
        reminder.amount = DecimalAmountValidator.parsed(from: amountInput)
        reminder.categoryID = categoryID
        reminder.fireDate = fireDate
        reminder.repeatRule = repeatRule
        reminder.isEnabled = isEnabled
        reminder.updatedAt = Date()

        onSave(reminder)
        dismiss()
    }

    /// Tomorrow at 10:00 is a more useful default than "right now", which would
    /// already have passed by the time the user saves.
    private static func defaultFireDate() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return calendar.date(
            bySettingHour: 10,
            minute: 0,
            second: 0,
            of: tomorrow
        ) ?? tomorrow
    }
}

#Preview {
    ReminderEditorView(reminder: nil, currency: .azn) { _ in }
}
