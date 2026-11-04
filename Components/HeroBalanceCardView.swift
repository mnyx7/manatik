import SwiftUI

/// The one figure the main page leads with: what is left this period, with the
/// two numbers it comes from underneath.
struct HeroBalanceCardView: View {
    let income: Decimal
    let expense: Decimal
    let netBalance: Decimal
    let currency: Currency
    let periodText: String
    let hasProjections: Bool

    private var isNegative: Bool { netBalance < 0 }

    private var netText: String {
        CurrencyFormatting.format(amount: netBalance, currency: currency)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isNegative ? "Over budget" : "Left to spend")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(netText)
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .foregroundStyle(isNegative ? AppTheme.expenseAccent : AppTheme.savingsAccent)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.7)

                Text(periodText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isNegative ? Text("Over budget") : Text("Left to spend"))
            .accessibilityValue("\(netText), \(periodText)")

            Divider()

            HStack(spacing: 12) {
                figure(
                    title: "Income",
                    amount: income,
                    accent: AppTheme.incomeAccent,
                    systemImage: "arrow.down.left"
                )
                figure(
                    title: "Expense",
                    amount: expense,
                    accent: AppTheme.expenseAccent,
                    systemImage: "arrow.up.right"
                )
            }

            if hasProjections {
                Label("Includes forecasts from repeating entries.", systemImage: "repeat")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cozyCard(AppTheme.savingsSurface, padding: 18)
    }

    @ViewBuilder
    private func figure(
        title: LocalizedStringKey,
        amount: Decimal,
        accent: Color,
        systemImage: String
    ) -> some View {
        let text = CurrencyFormatting.format(amount: amount, currency: currency)

        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(text)
    }
}

#Preview {
    HeroBalanceCardView(
        income: 3_200,
        expense: 1_010,
        netBalance: 2_190,
        currency: .azn,
        periodText: "1 November - 30 November",
        hasProjections: true
    )
    .padding()
    .background(AppTheme.pageBackground)
}
