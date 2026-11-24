//
//  SpendingChartView.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import Charts
import SwiftUI

/// Daily expense across the period.
///
/// Recorded days are solid; forecast days from repeating entries are hatched
/// back, so a projection is never mistaken for money already spent.
struct SpendingChartView: View {
    let points: [DailySpendPoint]
    let averagePerDay: Decimal
    let currency: Currency

    private var hasAnySpend: Bool {
        points.contains { $0.expense > 0 }
    }

    private var averageValue: Double {
        NSDecimalNumber(decimal: averagePerDay).doubleValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Spending")
                .font(.headline)

            if !hasAnySpend {
                Text("No expenses in this period yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                chart
                    .frame(height: 170)
                    // A chart is decorative for VoiceOver; the same numbers are
                    // available as text in the stats and category cards.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Daily spending chart"))
                    .accessibilityValue(summaryForAccessibility)

                HStack(spacing: 14) {
                    legend(color: AppTheme.expenseAccent, label: "Recorded")
                    legend(color: AppTheme.expenseAccent.opacity(0.35), label: "Forecast")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            AppTheme.cardBackground,
            in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
        )
    }

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value(Text("Day"), point.date, unit: .day),
                    y: .value(Text("Spent"), NSDecimalNumber(decimal: point.expense).doubleValue)
                )
                .foregroundStyle(
                    AppTheme.expenseAccent.opacity(point.isProjected ? 0.35 : 1)
                )
                .cornerRadius(2)
            }

            if averageValue > 0 {
                RuleMark(y: .value(Text("Average"), averageValue))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text(
                            String(
                                format: AppLocalization.string("avg %@", comment: "Chart annotation"),
                                CurrencyFormatting.format(amount: averagePerDay, currency: currency)
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day())
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                // The bar heights still show the shape of the month; the
                // scale is what would give the figures away.
                if !AmountPrivacy.shared.isHidden {
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
        }
    }

    @ViewBuilder
    private func legend(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
        }
        .accessibilityHidden(true)
    }

    private var summaryForAccessibility: String {
        let total = points.reduce(Decimal.zero) { $0 + $1.expense }
        return String(
            format: AppLocalization.string("%1$@ spent over %2$d days, averaging %3$@ a day", comment: "Accessibility"),
            CurrencyFormatting.format(amount: total, currency: currency),
            points.count,
            CurrencyFormatting.format(amount: averagePerDay, currency: currency)
        )
    }
}
