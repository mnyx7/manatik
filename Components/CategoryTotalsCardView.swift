import SwiftUI

struct CategoryTotalsCardView: View {
    let totals: [CategorySpending]
    let amountText: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top Spending Categories")
                .font(.headline)

            if totals.isEmpty {
                Text("No expense data for this period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(totals.prefix(6)) { item in
                    HStack(spacing: 10) {
                        Text(item.category.icon)
                        Text(item.category.name)
                            .font(.subheadline)
                        Spacer()
                        Text(amountText(item.total))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
