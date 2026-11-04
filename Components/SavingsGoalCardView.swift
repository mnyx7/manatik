import SwiftUI

/// One savings goal: saved, left, optional due date, and a way to put more in.
struct SavingsGoalCardView: View {
    let progress: SavingsGoalProgress
    let currency: Currency
    var onAddMoney: (() -> Void)?
    var onOpen: (() -> Void)?

    private var savedText: String {
        CurrencyFormatting.format(amount: progress.savedAmount, currency: currency)
    }

    private var targetText: String {
        CurrencyFormatting.format(amount: progress.goal.targetAmount, currency: currency)
    }

    private var remainingText: String {
        CurrencyFormatting.format(amount: progress.remainingAmount, currency: currency)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(progress.goal.name)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text("\(Int((progress.fraction * 100).rounded()))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.savingsAccent)
                    .monospacedDigit()
            }

            ProgressView(value: progress.fraction)
                .tint(AppTheme.savingsAccent)
                .accessibilityHidden(true)

            HStack {
                MoneyFactView(title: "Saved", value: savedText, accent: AppTheme.savingsAccent)
                MoneyFactView(
                    title: progress.isReached ? "Target reached" : "Still to go",
                    value: progress.isReached ? targetText : remainingText,
                    accent: .secondary
                )
            }

            if let days = progress.daysRemaining {
                DueDateLabel(days: days, dueDate: progress.goal.dueDate)
            }

            if onAddMoney != nil || onOpen != nil {
                HStack(spacing: 10) {
                    if let onAddMoney {
                        Button(action: onAddMoney) {
                            Label("Add money", systemImage: "plus.circle.fill")
                                .font(.footnote.weight(.semibold))
                                .frame(minHeight: AppTheme.minimumTapTarget)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.savingsAccent)
                    }

                    if let onOpen {
                        Button(action: onOpen) {
                            Text("Details")
                                .font(.footnote.weight(.semibold))
                                .frame(minHeight: AppTheme.minimumTapTarget)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cozyCard(AppTheme.savingsSurface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(progress.goal.name))
        .accessibilityValue(
            String(
                format: NSLocalizedString("%1$@ saved of %2$@, %3$@ to go", comment: "Accessibility"),
                savedText, targetText, remainingText
            )
        )
    }
}

/// One loan: what it started at, what has been paid, what is left.
struct LoanCardView: View {
    let progress: LoanProgress
    let currency: Currency
    var onRecordPayment: (() -> Void)?
    var onOpen: (() -> Void)?

    private var initialText: String {
        CurrencyFormatting.format(amount: progress.loan.initialAmount, currency: currency)
    }

    private var paidText: String {
        CurrencyFormatting.format(amount: progress.paidAmount, currency: currency)
    }

    private var remainingText: String {
        CurrencyFormatting.format(amount: progress.remainingAmount, currency: currency)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(progress.loan.name, systemImage: "building.columns")
                    .font(.subheadline.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                Spacer(minLength: 8)
                Text("\(Int((progress.fraction * 100).rounded()))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.loanAccent)
                    .monospacedDigit()
            }

            ProgressView(value: progress.fraction)
                .tint(AppTheme.loanAccent)
                .accessibilityHidden(true)

            HStack(alignment: .top) {
                MoneyFactView(title: "Borrowed", value: initialText, accent: .secondary)
                MoneyFactView(title: "Paid", value: paidText, accent: AppTheme.incomeAccent)
                MoneyFactView(title: "Left", value: remainingText, accent: AppTheme.loanAccent)
            }

            if let instalments = progress.estimatedPaymentsRemaining {
                Text(
                    String(
                        format: NSLocalizedString(
                            "About %d payments left at the current instalment.",
                            comment: "Loan forecast"
                        ),
                        instalments
                    )
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            DueDateLabel(days: daysUntilDue, dueDate: progress.loan.dueDate)

            if onRecordPayment != nil || onOpen != nil {
                HStack(spacing: 10) {
                    if let onRecordPayment {
                        Button(action: onRecordPayment) {
                            Label("Record payment", systemImage: "arrow.up.circle.fill")
                                .font(.footnote.weight(.semibold))
                                .frame(minHeight: AppTheme.minimumTapTarget)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.loanAccent)
                    }

                    if let onOpen {
                        Button(action: onOpen) {
                            Text("Details")
                                .font(.footnote.weight(.semibold))
                                .frame(minHeight: AppTheme.minimumTapTarget)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cozyCard(AppTheme.loanSurface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(progress.loan.name))
        .accessibilityValue(
            String(
                format: NSLocalizedString("%1$@ paid of %2$@, %3$@ left", comment: "Accessibility"),
                paidText, initialText, remainingText
            )
        )
    }

    private var daysUntilDue: Int? {
        guard let dueDate = progress.loan.dueDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: dueDate)
        ).day
    }
}

/// Small label/amount pair used inside the goal and loan cards.
struct MoneyFactView: View {
    let title: LocalizedStringKey
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(accent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

/// States the deadline in plain words, and says so when it has passed.
struct DueDateLabel: View {
    let days: Int?
    let dueDate: Date?

    var body: some View {
        if let days, let dueDate {
            let text: String = {
                if days < 0 {
                    return String(
                        format: NSLocalizedString("%d days overdue", comment: "Due date"),
                        abs(days)
                    )
                }
                if days == 0 {
                    return NSLocalizedString("Due today", comment: "Due date")
                }
                return String(
                    format: NSLocalizedString("%1$d days left, due %2$@", comment: "Due date"),
                    days,
                    DateFormatting.dayAndMonth(dueDate)
                )
            }()

            Label(text, systemImage: days < 0 ? "exclamationmark.circle" : "calendar")
                .font(.caption2)
                .foregroundStyle(days < 0 ? AppTheme.expenseAccent : .secondary)
        }
    }
}
