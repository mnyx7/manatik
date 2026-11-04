import SwiftUI

struct TransactionRowView: View {
    let item: TransactionOccurrence
    let category: TransactionCategory
    let amountText: String

    var body: some View {
        HStack(spacing: 12) {
            Text(category.icon)
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.subheadline.weight(.medium))
                Text(item.note.isEmpty ? "No note" : item.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text((item.type == .expense ? "-" : "+") + amountText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(item.type == .expense ? .red : .green)

                Text(DateFormatting.shortDate(item.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
