import SwiftUI

struct StatisticsCardView: View {
    let averagePerDay: String
    let biggestExpense: String
    let transactionCount: Int
    let amountLeft: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Period Stats")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statItem(title: "Avg/day", value: averagePerDay)
                statItem(title: "Biggest expense", value: biggestExpense)
                statItem(title: "Transactions", value: "\(transactionCount)")
                statItem(title: "Amount left", value: amountLeft)
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
