import Charts
import SwiftUI

/// Donut chart of where the money went, with the total in the middle and a
/// legend underneath carrying the real figures.
struct CategoryPieChartView: View {
    let slices: [CategorySpending]
    let total: Decimal
    let currency: Currency
    let centerCaption: LocalizedStringKey

    /// A slice is drawn in its own category's colour, which is the same colour
    /// that category's icon carries in every list and picker. A cycled palette
    /// meant the chart said "blue" while the row above it said "green".
    private func color(for category: TransactionCategory) -> Color {
        guard category.id != Self.aggregateID else { return Color(hex: 0x8E8E96) }
        return CategoryVisuals.tint(for: category)
    }

    private static let aggregateID = "__other__"

    /// Long tails make an unreadable donut, so everything past the eighth
    /// category is folded into one slice.
    private var displaySlices: [(category: TransactionCategory, total: Decimal, share: Double)] {
        let limit = 8
        // A slice under this share draws as a hairline the eye reads as a
        // rendering artefact rather than a category.
        let minimumShare = 0.02
        let significant = slices.filter { $0.share >= minimumShare }
        let keptCount = min(significant.count, limit - 1)

        guard slices.count > keptCount else {
            return slices.map { ($0.category, $0.total, $0.share) }
        }

        let head = slices.prefix(keptCount).map { ($0.category, $0.total, $0.share) }
        let tail = slices.dropFirst(keptCount)
        let tailTotal = tail.reduce(Decimal.zero) { $0 + $1.total }
        let tailShare = tail.reduce(0.0) { $0 + $1.share }

        let other = TransactionCategory(
            id: Self.aggregateID,
            name: NSLocalizedString("Other categories", comment: "Chart slice"),
            icon: "ellipsis",
            kind: .both,
            isCustom: true
        )
        return head + [(other, tailTotal, tailShare)]
    }

    var body: some View {
        VStack(spacing: 14) {
            if displaySlices.isEmpty {
                Text("Nothing to chart for this period yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                chart
                    .frame(height: 210)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Category breakdown chart"))
                    .accessibilityValue(accessibilitySummary)

                legend
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(Array(displaySlices.enumerated()), id: \.offset) { _, slice in
                SectorMark(
                    angle: .value(
                        Text("Amount"),
                        NSDecimalNumber(decimal: slice.total).doubleValue
                    ),
                    innerRadius: .ratio(0.58),
                    angularInset: 1.5
                )
                .cornerRadius(5)
                .foregroundStyle(color(for: slice.category))
            }
        }
        .chartLegend(.hidden)
        .chartBackground { _ in
            VStack(spacing: 2) {
                Text(centerCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatting.format(amount: total, currency: currency))
                    .font(.headline)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)
        }
    }

    private var legend: some View {
        VStack(spacing: 8) {
            ForEach(Array(displaySlices.enumerated()), id: \.offset) { _, slice in
                let amount = CurrencyFormatting.format(amount: slice.total, currency: currency)
                let percent = Int((slice.share * 100).rounded())

                HStack(spacing: 10) {
                    // The symbol is the swatch: it names the slice and carries
                    // its colour, so a separate dot would say the same twice.
                    Image(systemName: CategoryVisuals.symbolName(for: slice.category))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color(for: slice.category))
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    Text(slice.category.localizedName)
                        .font(.subheadline)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text("\(percent)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Text(amount)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(slice.category.localizedName))
                .accessibilityValue(
                    String(
                        format: NSLocalizedString("%1$@, %2$d percent", comment: "Accessibility"),
                        amount,
                        percent
                    )
                )
            }
        }
    }

    private var accessibilitySummary: String {
        let top = displaySlices.prefix(3).map { slice in
            "\(slice.category.localizedName) \(Int((slice.share * 100).rounded()))%"
        }
        return top.joined(separator: ", ")
    }
}
