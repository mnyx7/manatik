import SwiftUI

struct TransactionRowView: View {
    let item: TransactionOccurrence
    let category: TransactionCategory
    let currency: Currency

    var body: some View {
        HStack(spacing: 12) {
            Text(category.icon)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(
                    AppTheme.surface(for: item.type),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                // VoiceOver would otherwise announce the emoji's own name right
                // before the category it stands for.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(category.localizedName)
                        .font(.subheadline.weight(.medium))

                    if item.isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }

                if item.isProjected {
                    Text("Forecast")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(
                    CurrencyFormatting.formatSigned(
                        amount: item.amount,
                        type: item.type,
                        currency: currency
                    )
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent(for: item.type))
                // Amounts must wrap rather than shrink away at large text sizes.
                .multilineTextAlignment(.trailing)

                Text(DateFormatting.shortDate(item.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .opacity(item.isProjected ? 0.65 : 1)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts: [String] = [category.localizedName]

        if !item.note.isEmpty {
            parts.append(item.note)
        }

        parts.append(
            CurrencyFormatting.accessibleDescription(
                amount: item.amount,
                type: item.type,
                currency: currency
            )
        )
        parts.append(DateFormatting.shortDate(item.date))

        if item.isProjected {
            parts.append(NSLocalizedString("Forecast, not yet recorded", comment: "Accessibility"))
        } else if item.isRecurring {
            parts.append(NSLocalizedString("Part of a repeating entry", comment: "Accessibility"))
        }

        return parts.joined(separator: ", ")
    }
}

#Preview {
    List {
        TransactionRowView(
            item: MockData.previewOccurrence(projected: false),
            category: DefaultCategories.category(for: "groceries"),
            currency: .azn
        )
        TransactionRowView(
            item: MockData.previewOccurrence(projected: true),
            category: DefaultCategories.category(for: "rent"),
            currency: .azn
        )
    }
}
