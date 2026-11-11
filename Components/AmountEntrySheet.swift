import SwiftUI

/// One amount, one date, one note.
///
/// Used both for putting money into a savings goal and for recording a loan
/// instalment, since both create a linked ledger entry and nothing else.
struct AmountEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: LocalizedStringKey
    let subtitle: String
    let actionTitle: LocalizedStringKey
    let accent: Color
    let currency: Currency
    /// Shown as a shortcut, e.g. the remaining balance or the monthly instalment.
    let suggestedAmount: Decimal?
    let onSubmit: (Decimal, Date, String) -> Void

    @State private var amountInput: String = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var errorMessage: String?
    @FocusState private var isAmountFocused: Bool

    private var parsedAmount: Decimal? {
        DecimalAmountValidator.parsed(from: amountInput)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField(
                            "0",
                            text: Binding(
                                get: { amountInput },
                                set: { amountInput = DecimalAmountValidator.sanitize($0) }
                            )
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($isAmountFocused)
                        .accessibilityLabel(Text("Amount"))
                    }
                    .frame(minHeight: AppTheme.minimumTapTarget)
                    .contentShape(.rect)
                    .onTapGesture { isAmountFocused = true }

                    if let suggestedAmount, suggestedAmount > 0 {
                        Button {
                            amountInput = DecimalAmountValidator.editingText(for: suggestedAmount)
                        } label: {
                            Label(
                                String(
                                    format: NSLocalizedString("Use %@", comment: "Suggested amount"),
                                    CurrencyFormatting.format(amount: suggestedAmount, currency: currency)
                                ),
                                systemImage: "wand.and.stars"
                            )
                            .font(.footnote)
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: [.date])

                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text(subtitle)
                } footer: {
                    Text("This is recorded as an expense so your Left to spend stays accurate.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.expenseAccent)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .defaultFocus($isAmountFocused, true)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(actionTitle) { submit() }
                        .disabled(parsedAmount == nil)
                        .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isAmountFocused = false }
                }
            }
            .tint(accent)
        }
    }

    private func submit() {
        guard let amount = parsedAmount else {
            errorMessage = DecimalAmountValidator.validationMessage(for: amountInput)
            return
        }
        onSubmit(amount, date, note.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss()
    }
}
