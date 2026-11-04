import SwiftUI

/// Period navigation plus the three headline figures, compact enough that the
/// transaction list still starts near the top of the screen.
struct PeriodHeaderView: View {
    let periodText: String
    let isCurrentPeriod: Bool
    let income: Decimal
    let expense: Decimal
    let netBalance: Decimal
    let currency: Currency
    let hasProjections: Bool

    let onPrevious: () -> Void
    let onNext: () -> Void
    let onPickPeriod: () -> Void
    let onGoToToday: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
                }
                .accessibilityLabel(Text("Previous period"))

                // A real bordered control, so it is visibly tappable. The old
                // plain-styled text gave no hint that it opened a picker.
                Button(action: onPickPeriod) {
                    HStack(spacing: 5) {
                        Text(periodText)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(Text("Change period"))
                .accessibilityValue(periodText)

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
                }
                .accessibilityLabel(Text("Next period"))
            }

            HStack(alignment: .top, spacing: 10) {
                figure(title: "Income", amount: income, accent: AppTheme.incomeAccent)
                figure(title: "Expense", amount: expense, accent: AppTheme.expenseAccent)
                figure(title: "Net", amount: netBalance, accent: AppTheme.netAccent(for: netBalance))
            }

            if !isCurrentPeriod {
                // Previously there was no way back to the current month at all.
                Button(action: onGoToToday) {
                    Label("Back to today", systemImage: "arrow.uturn.backward")
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: AppTheme.minimumTapTarget)
                }
            }

            if hasProjections {
                Label("Includes forecast rows from repeating entries.", systemImage: "repeat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func figure(title: LocalizedStringKey, amount: Decimal, accent: Color) -> some View {
        let text = CurrencyFormatting.format(amount: amount, currency: currency)

        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(text)
    }
}
