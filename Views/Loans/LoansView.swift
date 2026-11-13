//
//  LoansView.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import SwiftUI

/// All debts: still being paid, then settled.
struct LoansView: View {
    @Environment(AppStore.self) private var store
    @Bindable var viewModel: HomeViewModel
    let onOpenLoan: (UUID) -> Void

    private var currency: Currency { store.state.settings.currency }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                if store.activeLoans.isEmpty && store.closedLoans.isEmpty {
                    EmptyStateView(
                        systemImage: "building.columns",
                        title: "No loans tracked",
                        subtitle: "Add a loan to follow what you have paid and what is left.",
                        actionTitle: "Add a loan",
                        action: { viewModel.newLoan() }
                    )
                } else {
                    if !store.activeLoans.isEmpty {
                        Text("Being paid")
                            .font(.headline)
                            .padding(.top, 4)

                        ForEach(store.activeLoans) { progress in
                            LoanCardView(
                                progress: progress,
                                currency: currency,
                                onRecordPayment: { viewModel.payingLoan = progress.loan },
                                onOpen: { onOpenLoan(progress.loan.id) }
                            )
                        }
                    }

                    if !store.closedLoans.isEmpty {
                        Text("Settled")
                            .font(.headline)
                            .padding(.top, 4)

                        ForEach(store.closedLoans) { progress in
                            Button {
                                onOpenLoan(progress.loan.id)
                            } label: {
                                settledRow(progress)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        viewModel.newLoan()
                    } label: {
                        Label("Add a loan", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .background(AppTheme.pageBackground)
        .contentMargins(.bottom, AppTheme.tabBarClearance, for: .scrollContent)
        .navigationTitle("Loans")
    }

    @ViewBuilder
    private func settledRow(_ progress: LoanProgress) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.incomeAccent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(progress.loan.name)
                    .font(.subheadline.weight(.medium))
                if let closedAt = progress.loan.closedAt {
                    Text(
                        String(
                            format: NSLocalizedString("Settled %@", comment: "Closed loan"),
                            DateFormatting.dayMonthYear(closedAt)
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Text(CurrencyFormatting.format(amount: progress.paidAmount, currency: currency))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.incomeAccent)
        }
        .glassCard()
        .accessibilityElement(children: .combine)
    }
}

/// One loan, its figures, and every payment made against it.
struct LoanDetailView: View {
    @Environment(AppStore.self) private var store

    let loanID: UUID
    @Bindable var viewModel: HomeViewModel

    @State private var reminderConfirmation: String?

    private var currency: Currency { store.state.settings.currency }

    var body: some View {
        Group {
            if let loan = store.state.loan(id: loanID) {
                content(for: loan)
            } else {
                EmptyStateView(
                    systemImage: "questionmark.folder",
                    title: "This loan no longer exists",
                    subtitle: "It may have been deleted."
                )
            }
        }
        .background(AppTheme.pageBackground)
        .contentMargins(.bottom, AppTheme.tabBarClearance, for: .scrollContent)
        .navigationTitle(store.state.loan(id: loanID)?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(for loan: Loan) -> some View {
        let progress = store.progress(for: loan)
        let payments = store.payments(for: loan)

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                LoanCardView(
                    progress: progress,
                    currency: currency,
                    onRecordPayment: loan.isClosed ? nil : { viewModel.payingLoan = loan }
                )

                if !loan.note.isEmpty {
                    Text(loan.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                }

                HStack(spacing: 10) {
                    Button {
                        viewModel.edit(loan: loan)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        store.setLoanClosed(id: loan.id, closed: !loan.isClosed)
                    } label: {
                        Label(
                            loan.isClosed ? "Reopen" : "Mark settled",
                            systemImage: loan.isClosed ? "arrow.uturn.backward" : "checkmark"
                        )
                        .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                }

                // A loan with a known instalment is exactly the thing worth a
                // monthly nudge, so offer it here instead of making the user
                // retype it in Settings.
                if let monthly = loan.monthlyPayment, monthly > 0, !loan.isClosed {
                    Button {
                        createMonthlyReminder(for: loan, amount: monthly)
                    } label: {
                        Label("Remind me monthly about this payment", systemImage: "bell.badge")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                }

                if let reminderConfirmation {
                    Label(reminderConfirmation, systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.incomeAccent)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Payments")
                        .font(.headline)

                    if loan.openingPaidAmount > 0 {
                        paymentRow(
                            title: NSLocalizedString("Paid before tracking", comment: "Opening balance"),
                            amount: loan.openingPaidAmount,
                            date: nil
                        )
                    }

                    if payments.isEmpty && loan.openingPaidAmount == 0 {
                        Text("No payments recorded yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(payments) { entry in
                            paymentRow(
                                title: entry.note.isEmpty ? loan.name : entry.note,
                                amount: entry.amount,
                                date: entry.date
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()

                Button(role: .destructive) {
                    store.deleteLoan(id: loan.id)
                } label: {
                    Label("Delete this loan", systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func paymentRow(title: String, amount: Decimal, date: Date?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                if let date {
                    Text(DateFormatting.dayMonthYear(date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Starting balance")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            Text(CurrencyFormatting.format(amount: amount, currency: currency))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.loanAccent)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func createMonthlyReminder(for loan: Loan, amount: Decimal) {
        let calendar = Calendar.current
        let base = loan.dueDate ?? calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        let fireDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: base) ?? base

        store.addReminder(
            PaymentReminder(
                title: loan.name,
                amount: amount,
                categoryID: DefaultCategories.loanCategoryID,
                fireDate: fireDate,
                repeatRule: .monthly
            )
        )
        reminderConfirmation = NSLocalizedString(
            "Monthly reminder added. Manage it in Settings.",
            comment: "Confirmation"
        )
    }
}

/// Create or edit a loan.
struct LoanEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let existing: Loan?
    let currency: Currency
    let onSave: (String, Decimal, Decimal, Decimal?, Date, Date?, String) -> Void

    @State private var name: String
    @State private var initialInput: String
    @State private var paidInput: String
    @State private var monthlyInput: String
    @State private var startDate: Date
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var note: String
    @FocusState private var isNameFocused: Bool

    init(
        loan: Loan?,
        currency: Currency,
        onSave: @escaping (String, Decimal, Decimal, Decimal?, Date, Date?, String) -> Void
    ) {
        self.existing = loan
        self.currency = currency
        self.onSave = onSave

        _name = State(initialValue: loan?.name ?? "")
        _initialInput = State(
            initialValue: loan.map { DecimalAmountValidator.editingText(for: $0.initialAmount) } ?? ""
        )
        _paidInput = State(
            initialValue: loan.map { DecimalAmountValidator.editingText(for: $0.openingPaidAmount) } ?? ""
        )
        _monthlyInput = State(
            initialValue: loan?.monthlyPayment.map { DecimalAmountValidator.editingText(for: $0) } ?? ""
        )
        _startDate = State(initialValue: loan?.startDate ?? Date())
        _hasDueDate = State(initialValue: loan?.dueDate != nil)
        _dueDate = State(initialValue: loan?.dueDate ?? Date())
        _note = State(initialValue: loan?.note ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && DecimalAmountValidator.parsed(from: initialInput) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Loan") {
                    TextField("For example: Car loan", text: $name)
                        .focused($isNameFocused)

                    AmountFieldRow(title: "Borrowed amount", text: $initialInput)
                }

                Section {
                    AmountFieldRow(title: "Already paid", text: $paidInput)
                } footer: {
                    Text("What you had already repaid before tracking it here. It counts as paid without appearing as an expense.")
                }

                Section {
                    AmountFieldRow(
                        title: "Monthly payment",
                        text: $monthlyInput,
                        placeholder: NSLocalizedString("Optional", comment: "Placeholder")
                    )

                    DatePicker("Started", selection: $startDate, displayedComponents: [.date])

                    Toggle("Has a final due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date])
                    }

                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Optional")
                } footer: {
                    Text("Giving a monthly payment lets muna estimate how many instalments are left and offer a monthly reminder.")
                }
            }
            .navigationTitle(existing == nil ? "New Loan" : "Edit Loan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { submit() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isNameFocused = false }
                }
            }
            .task {
                if existing == nil { isNameFocused = true }
            }
        }
    }

    private func submit() {
        guard let initial = DecimalAmountValidator.parsed(from: initialInput) else { return }
        onSave(
            trimmedName,
            initial,
            DecimalAmountValidator.parsed(from: paidInput) ?? 0,
            DecimalAmountValidator.parsed(from: monthlyInput),
            startDate,
            hasDueDate ? dueDate : nil,
            note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        dismiss()
    }
}
