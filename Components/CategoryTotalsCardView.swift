import SwiftUI

struct CategoryTotalsCardView: View {
    let totals: [CategorySpending]
    let currency: Currency

    private let collapsedLimit = 6
    @State private var isExpanded = false

    private var visible: [CategorySpending] {
        isExpanded ? totals : Array(totals.prefix(collapsedLimit))
    }

    private var hiddenCount: Int {
        max(totals.count - collapsedLimit, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)

            if totals.isEmpty {
                Text("No expenses in this period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visible) { item in
                    row(item)
                }

                if hiddenCount > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(
                            isExpanded
                                ? NSLocalizedString("Show less", comment: "Expand control")
                                : String(
                                    format: NSLocalizedString("Show %d more", comment: "Expand control"),
                                    hiddenCount
                                )
                        )
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: AppTheme.minimumTapTarget, alignment: .leading)
                    }
                }
            }
        }
        .padding()
        .background(
            AppTheme.cardBackground,
            in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
        )
    }

    @ViewBuilder
    private func row(_ item: CategorySpending) -> some View {
        let percent = Int((item.share * 100).rounded())
        let amount = CurrencyFormatting.format(amount: item.total, currency: currency)

        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                CategoryIconView(category: item.category, size: .small)

                Text(item.category.localizedName)
                    .font(.subheadline)

                Spacer(minLength: 8)

                Text("\(percent)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text(amount)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.expenseAccent)
            }

            // The share of total is the insight; a bare total was not comparable.
            ProgressView(value: item.share)
                .tint(AppTheme.expenseAccent)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.category.localizedName)
        .accessibilityValue(
            String(
                format: NSLocalizedString("%1$@, %2$d percent of spending", comment: "Accessibility"),
                amount,
                percent
            )
        )
    }
}
