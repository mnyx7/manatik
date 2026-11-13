import SwiftUI

/// The one figure the main page leads with: what is left this period, the two
/// numbers it comes from, and how much of what came in has gone out.
///
/// The period text was removed: it is the navigation title now, and printing it
/// here as well meant the same range appeared twice within 60pt of itself.
struct HeroBalanceCardView: View {
    let income: Decimal
    let expense: Decimal
    let netBalance: Decimal
    let currency: Currency
    let hasProjections: Bool
    /// e.g. "+$200 · −€30": entries the figures leave out, never converted.
    var otherCurrencies: String = ""
    /// Each part opens Activity on its slice: the balance on everything,
    /// In on income, Out on expenses.
    var onOpen: ((ActivityScope) -> Void)?

    private var isNegative: Bool { netBalance < 0 }

    private var netText: String {
        CurrencyFormatting.format(amount: netBalance, currency: currency)
    }

    /// Share of income already spent, clamped so an over-budget period fills
    /// the bar rather than overflowing it.
    private var spentFraction: Double {
        guard income > 0 else { return expense > 0 ? 1 : 0 }
        let value = NSDecimalNumber(decimal: expense).doubleValue
            / NSDecimalNumber(decimal: income).doubleValue
        return min(max(value, 0), 1)
    }

    private var accent: Color {
        isNegative ? AppTheme.expenseAccent : AppTheme.savingsAccent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isNegative ? "Over budget" : "Left to spend")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(netText)
                    .font(.moneyHero())
                    .foregroundStyle(accent)
                    .moneyDigits()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                if !otherCurrencies.isEmpty {
                    Text("Also \(otherCurrencies)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture { onOpen?(.all) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isNegative ? Text("Over budget") : Text("Left to spend"))
            .accessibilityValue(otherCurrencies.isEmpty ? netText : "\(netText), \(otherCurrencies)")
            .accessibilityAddTraits(onOpen == nil ? [] : .isButton)
            .accessibilityAction { onOpen?(.all) }

            ratioBar

            HStack(spacing: 10) {
                figure(
                    title: "In",
                    amount: income,
                    accent: AppTheme.incomeAccent,
                    systemImage: "arrow.down",
                    scope: .income
                )
                figure(
                    title: "Out",
                    amount: expense,
                    accent: AppTheme.expenseAccent,
                    systemImage: "arrow.up",
                    scope: .expense
                )
            }

            if hasProjections {
                Label("Includes forecasts from repeating entries.", systemImage: "repeat")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: accent, padding: 20)
    }

    /// How much of what came in has gone out. A single glance answer that two
    /// separate totals cannot give on their own.
    private var ratioBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.expenseAccent.opacity(0.75), AppTheme.expenseAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(proxy.size.width * spentFraction, spentFraction > 0 ? 6 : 0))
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel(Text("Share of income spent"))
        .accessibilityValue(Text("\(Int((spentFraction * 100).rounded())) percent"))
    }

    @ViewBuilder
    private func figure(
        title: LocalizedStringKey,
        amount: Decimal,
        accent: Color,
        systemImage: String,
        scope: ActivityScope
    ) -> some View {
        let text = CurrencyFormatting.format(amount: amount, currency: currency)

        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 26, height: 26)
                .background(accent.opacity(0.16), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.moneyMedium())
                    .foregroundStyle(.primary)
                    .moneyDigits()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture { onOpen?(scope) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(text)
        .accessibilityAddTraits(onOpen == nil ? [] : .isButton)
        .accessibilityAction { onOpen?(scope) }
    }
}

#Preview {
    ZStack {
        AppBackgroundView()
        HeroBalanceCardView(
            income: 3_650,
            expense: 1_010,
            netBalance: 2_640,
            currency: .azn,
            hasProjections: true
        )
        .padding()
    }
}
