//
//  StatisticsCardView.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import SwiftUI

/// Secondary statistics for a period.
///
/// Deliberately excludes income, expense and net: those lead the screen as
/// summary cards, and showing them twice a hundred points apart was noise.
struct StatisticsCardView: View {
    let averagePerDay: String
    let biggestExpense: String
    let transactionCount: Int
    let projectedCount: Int
    let elapsedDays: Int
    let totalDays: Int

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Period Stats")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 10) {
                statItem(
                    title: "Avg/day so far",
                    value: averagePerDay,
                    footnote: String(
                        format: AppLocalization.string("over %d of %d days", comment: "Average basis"),
                        elapsedDays,
                        totalDays
                    )
                )
                statItem(title: "Biggest expense", value: biggestExpense, footnote: nil)
                statItem(title: "Entries", value: "\(transactionCount)", footnote: nil)
                statItem(
                    title: "Forecast rows",
                    value: "\(projectedCount)",
                    footnote: projectedCount > 0
                        ? AppLocalization.string("not yet recorded", comment: "Forecast note")
                        : nil
                )
            }
        }
        .padding()
        .background(
            AppTheme.cardBackground,
            in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
        )
    }

    @ViewBuilder
    private func statItem(title: LocalizedStringKey, value: String, footnote: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            Color(.tertiarySystemBackground),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}
