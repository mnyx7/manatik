import SwiftUI

struct SavingsGoalCardView: View {
    let currentAmount: Decimal
    let targetAmount: Decimal
    let currency: Currency
    /// True when progress tracks what is left this period rather than a figure
    /// the user maintains by hand.
    let tracksAmountLeft: Bool

    private var isOverspent: Bool { currentAmount < 0 }

    private var progress: Double {
        guard targetAmount > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: currentAmount).doubleValue
            / NSDecimalNumber(decimal: targetAmount).doubleValue
        return min(max(ratio, 0), 1)
    }

    private var percentText: String {
        isOverspent ? "0%" : "\(Int((progress * 100).rounded()))%"
    }

    private var currentText: String {
        CurrencyFormatting.format(amount: currentAmount, currency: currency)
    }

    private var targetText: String {
        CurrencyFormatting.format(amount: targetAmount, currency: currency)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Savings Goal")
                    .font(.headline)
                Spacer()
                Text(percentText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            Text("\(currentText) / \(targetText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: progress)
                .tint(isOverspent ? AppTheme.expenseAccent : AppTheme.savingsAccent)
                .accessibilityHidden(true)

            // A negative balance used to render as 0%, indistinguishable from
            // "no progress yet".
            if isOverspent {
                Text("You spent more than you earned this period.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.expenseAccent)
            } else {
                Text(
                    tracksAmountLeft
                        ? "Tracking what is left this period."
                        : "Tracking the saved amount you entered in Settings."
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(
            AppTheme.savingsSurface,
            in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Savings goal"))
        .accessibilityValue(
            isOverspent
                ? NSLocalizedString("Overspent this period", comment: "Accessibility")
                : String(
                    format: NSLocalizedString("%1$@ of %2$@, %3$@ complete", comment: "Accessibility"),
                    currentText,
                    targetText,
                    percentText
                )
        )
    }
}

#Preview {
    VStack {
        SavingsGoalCardView(currentAmount: 420, targetAmount: 1_000, currency: .azn, tracksAmountLeft: true)
        SavingsGoalCardView(currentAmount: -120, targetAmount: 1_000, currency: .azn, tracksAmountLeft: true)
    }
    .padding()
}
