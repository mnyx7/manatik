import SwiftUI

struct SummaryCardView: View {
    let title: LocalizedStringKey
    let value: String
    let surface: Color
    let accent: Color
    /// Spoken form of `value`, when the written form reads badly.
    var accessibilityValue: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .foregroundStyle(accent)
                // No lineLimit/minimumScaleFactor: at accessibility text sizes
                // a long amount must wrap, not get clipped or shrunk away.
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(surface, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue ?? value)
    }
}

#Preview {
    VStack {
        SummaryCardView(
            title: "Income",
            value: "\u{20BC}3,200.00",
            surface: AppTheme.incomeSurface,
            accent: AppTheme.incomeAccent
        )
        SummaryCardView(
            title: "Expense",
            value: "\u{20BC}1,010.70",
            surface: AppTheme.expenseSurface,
            accent: AppTheme.expenseAccent
        )
    }
    .padding()
}
