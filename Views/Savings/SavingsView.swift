//
//  SavingsView.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import SwiftUI

/// All savings goals: the ones in flight, then the ones already reached.
struct SavingsView: View {
    @Environment(AppStore.self) private var store
    @Bindable var viewModel: HomeViewModel
    let onOpenGoal: (UUID) -> Void

    private var currency: Currency { store.state.settings.currency }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                if store.activeSavingsGoals.isEmpty && store.completedSavingsGoals.isEmpty {
                    EmptyStateView(
                        systemImage: "target",
                        title: "No savings goals yet",
                        subtitle: "Set a goal and put money aside towards it.",
                        actionTitle: "Add a savings goal",
                        action: { viewModel.newGoal() }
                    )
                } else {
                    if !store.activeSavingsGoals.isEmpty {
                        sectionHeader("In progress")
                        ForEach(store.activeSavingsGoals) { progress in
                            SavingsGoalCardView(
                                progress: progress,
                                currency: currency,
                                onAddMoney: { viewModel.contributingGoal = progress.goal },
                                onOpen: { onOpenGoal(progress.goal.id) }
                            )
                        }
                    }

                    if !store.completedSavingsGoals.isEmpty {
                        sectionHeader("Completed")
                        ForEach(store.completedSavingsGoals) { progress in
                            Button {
                                onOpenGoal(progress.goal.id)
                            } label: {
                                completedRow(progress)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        viewModel.newGoal()
                    } label: {
                        Label("Add a savings goal", systemImage: "plus.circle.fill")
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
        .navigationTitle("Savings")
    }

    @ViewBuilder
    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func completedRow(_ progress: SavingsGoalProgress) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.incomeAccent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(progress.goal.name)
                    .font(.subheadline.weight(.medium))
                if let completedAt = progress.goal.completedAt {
                    Text(
                        String(
                            format: NSLocalizedString("Reached %@", comment: "Completed goal"),
                            DateFormatting.dayMonthYear(completedAt)
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Text(CurrencyFormatting.format(amount: progress.savedAmount, currency: currency))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.incomeAccent)
        }
        .glassCard()
        .accessibilityElement(children: .combine)
    }
}

/// One goal, its figures, and every time money went in.
struct SavingsGoalDetailView: View {
    @Environment(AppStore.self) private var store
    @Bindable var viewModel: HomeViewModel

    let goalID: UUID

    init(goalID: UUID, viewModel: HomeViewModel) {
        self.goalID = goalID
        self.viewModel = viewModel
    }

    private var currency: Currency { store.state.settings.currency }

    var body: some View {
        Group {
            if let goal = store.state.savingsGoal(id: goalID) {
                content(for: goal)
            } else {
                EmptyStateView(
                    systemImage: "questionmark.folder",
                    title: "This goal no longer exists",
                    subtitle: "It may have been deleted."
                )
            }
        }
        .background(AppTheme.pageBackground)
        .contentMargins(.bottom, AppTheme.tabBarClearance, for: .scrollContent)
        .navigationTitle(store.state.savingsGoal(id: goalID)?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(for goal: SavingsGoal) -> some View {
        let progress = store.progress(for: goal)
        let contributions = store.contributions(for: goal)

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                SavingsGoalCardView(
                    progress: progress,
                    currency: currency,
                    onAddMoney: goal.isCompleted ? nil : { viewModel.contributingGoal = goal }
                )

                if !goal.note.isEmpty {
                    Text(goal.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                }

                HStack(spacing: 10) {
                    Button {
                        viewModel.edit(goal: goal)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        store.setSavingsGoalCompleted(id: goal.id, completed: !goal.isCompleted)
                    } label: {
                        Label(
                            goal.isCompleted ? "Reopen" : "Mark complete",
                            systemImage: goal.isCompleted ? "arrow.uturn.backward" : "checkmark"
                        )
                        .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Paid in")
                        .font(.headline)

                    if goal.openingAmount > 0 {
                        logRow(
                            title: NSLocalizedString("Already saved before tracking", comment: "Opening balance"),
                            amount: goal.openingAmount,
                            date: nil
                        )
                    }

                    if contributions.isEmpty && goal.openingAmount == 0 {
                        Text("Nothing paid in yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(contributions) { entry in
                            logRow(
                                title: entry.note.isEmpty ? goal.name : entry.note,
                                amount: entry.amount,
                                date: entry.date
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()

                Button(role: .destructive) {
                    store.deleteSavingsGoal(id: goal.id)
                } label: {
                    Label("Delete this goal", systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func logRow(title: String, amount: Decimal, date: Date?) -> some View {
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
                .foregroundStyle(AppTheme.savingsAccent)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Create or edit a savings goal.
struct SavingsGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let existing: SavingsGoal?
    let currency: Currency
    let onSave: (String, Decimal, Decimal, Date?, String) -> Void

    @State private var name: String
    @State private var targetInput: String
    @State private var openingInput: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var note: String
    @FocusState private var isNameFocused: Bool

    init(
        goal: SavingsGoal?,
        currency: Currency,
        onSave: @escaping (String, Decimal, Decimal, Date?, String) -> Void
    ) {
        self.existing = goal
        self.currency = currency
        self.onSave = onSave

        _name = State(initialValue: goal?.name ?? "")
        _targetInput = State(
            initialValue: goal.map { DecimalAmountValidator.editingText(for: $0.targetAmount) } ?? ""
        )
        _openingInput = State(
            initialValue: goal.map { DecimalAmountValidator.editingText(for: $0.openingAmount) } ?? ""
        )
        _hasDueDate = State(initialValue: goal?.dueDate != nil)
        _dueDate = State(initialValue: goal?.dueDate ?? Date())
        _note = State(initialValue: goal?.note ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && DecimalAmountValidator.parsed(from: targetInput) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("For example: New laptop", text: $name)
                        .focused($isNameFocused)

                    AmountFieldRow(title: "Target amount", text: $targetInput)
                }

                Section {
                    AmountFieldRow(title: "Already saved", text: $openingInput)
                } footer: {
                    // Avoids inventing a past expense just to show a balance.
                    Text("Money you had put aside before tracking it here. It counts towards the goal without appearing as an expense.")
                }

                Section {
                    Toggle("Has a due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date])
                    }
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Optional")
                }
            }
            .navigationTitle(existing == nil ? "New Goal" : "Edit Goal")
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
        guard let target = DecimalAmountValidator.parsed(from: targetInput) else { return }
        onSave(
            trimmedName,
            target,
            DecimalAmountValidator.parsed(from: openingInput) ?? 0,
            hasDueDate ? dueDate : nil,
            note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        dismiss()
    }
}
