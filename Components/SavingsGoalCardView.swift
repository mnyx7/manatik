import SwiftUI

/// One savings goal: saved, left, optional due date, and a way to put more in.
///
/// Rows are fixed in number and names are single-line, so cards in a
/// side-scrolling row come out the same height whatever their content.
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
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(Int((progress.fraction * 100).rounded()))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.savingsAccent)
                    .monospacedDigit()
            }

            ProgressView(value: progress.fraction)
                .tint(AppTheme.savingsAccent)
                .accessibilityHidden(true)

            HStack(alignment: .top) {
                MoneyFactView(title: "Saved", value: savedText, accent: AppTheme.savingsAccent)
                MoneyFactView(
                    title: progress.isReached ? "Target reached" : "Still to go",
                    value: progress.isReached ? targetText : remainingText,
                    accent: .secondary
                )
            }

            // Always present, so every card is the same height.
            MetaLineView(
                systemImage: metaIcon,
                text: metaText,
                tint: isOverdue ? AppTheme.expenseAccent : .secondary
            )

            if onAddMoney != nil || onOpen != nil {
                HStack(spacing: 8) {
                    if let onAddMoney {
                        Button(action: onAddMoney) {
                            Label("Add money", systemImage: "plus")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(AppTheme.savingsAccent)
                    }

                    if let onOpen {
                        Button(action: onOpen) {
                            Text("Details")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Spacer(minLength: 0)
                }
                .frame(minHeight: AppTheme.minimumTapTarget)
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

    private var isOverdue: Bool {
        (progress.daysRemaining ?? 0) < 0 && progress.goal.dueDate != nil
    }

    private var metaIcon: String {
        guard progress.goal.dueDate != nil else { return "infinity" }
        return isOverdue ? "exclamationmark.circle" : "calendar"
    }

    private var metaText: String {
        guard let dueDate = progress.goal.dueDate, let days = progress.daysRemaining else {
            return NSLocalizedString("No deadline", comment: "Goal meta")
        }
        if days < 0 {
            return String(format: NSLocalizedString("%d days overdue", comment: "Due date"), abs(days))
        }
        if days == 0 {
            return NSLocalizedString("Due today", comment: "Due date")
        }
        return String(
            format: NSLocalizedString("%1$d days left, due %2$@", comment: "Due date"),
            days,
            DateFormatting.dayAndMonth(dueDate)
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
                    .lineLimit(1)
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

            // One line carrying both the instalment estimate and the deadline,
            // so a loan card matches a goal card row for row.
            MetaLineView(
                systemImage: metaIcon,
                text: metaText,
                tint: isOverdue ? AppTheme.expenseAccent : .secondary
            )

            if onRecordPayment != nil || onOpen != nil {
                HStack(spacing: 8) {
                    if let onRecordPayment {
                        Button(action: onRecordPayment) {
                            Label("Record payment", systemImage: "arrow.up")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(AppTheme.loanAccent)
                    }

                    if let onOpen {
                        Button(action: onOpen) {
                            Text("Details")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Spacer(minLength: 0)
                }
                .frame(minHeight: AppTheme.minimumTapTarget)
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

    private var isOverdue: Bool {
        (daysUntilDue ?? 0) < 0 && progress.loan.dueDate != nil
    }

    private var metaIcon: String {
        if isOverdue { return "exclamationmark.circle" }
        if progress.estimatedPaymentsRemaining != nil { return "number" }
        return progress.loan.dueDate == nil ? "infinity" : "calendar"
    }

    private var metaText: String {
        var parts: [String] = []

        if let instalments = progress.estimatedPaymentsRemaining {
            parts.append(
                String(
                    format: NSLocalizedString("about %d payments left", comment: "Loan forecast"),
                    instalments
                )
            )
        }

        if let days = daysUntilDue {
            if days < 0 {
                parts.append(
                    String(format: NSLocalizedString("%d days overdue", comment: "Due date"), abs(days))
                )
            } else if days == 0 {
                parts.append(NSLocalizedString("due today", comment: "Due date"))
            } else {
                parts.append(
                    String(format: NSLocalizedString("%d days left", comment: "Due date"), days)
                )
            }
        }

        guard !parts.isEmpty else {
            return NSLocalizedString("No deadline", comment: "Loan meta")
        }
        return parts.joined(separator: " \u{00B7} ")
    }
}

/// The single always-present detail line on a goal or loan card.
struct MetaLineView: View {
    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2)
            .foregroundStyle(tint)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                .lineLimit(1)
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
