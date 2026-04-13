import SwiftUI

struct SummaryCardView: View {
    let title: String
    let value: String
    let backgroundColor: Color
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(backgroundColor.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    SummaryCardView(
        title: "Total Income",
        value: "$1,234.00",
        backgroundColor: AppTheme.incomeColor,
        valueColor: .green
    )
    .padding()
}
