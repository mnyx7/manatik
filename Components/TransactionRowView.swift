import SwiftUI

struct TransactionRowView: View {
    let item: TransactionOccurrence
    let category: TransactionCategory
    /// The main currency, used when the entry has none of its own.
    let currency: Currency
    /// Off when the surrounding list already groups rows under a day heading.
    var showsDate = true

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(category: category, size: .medium)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(category.localizedName)
                        .font(.subheadline.weight(.semibold))

                    // Badges are capped at two. The old row could show five at
                    // once, which read as noise rather than information.
                    ForEach(badges.prefix(2), id: \.symbol) { badge in
                        Image(systemName: badge.symbol)
                            .font(.caption2)
                            .foregroundStyle(badge.tint)
                            .accessibilityHidden(true)
                    }
                }

                if item.isProjected {
                    Text("Forecast")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                } else if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(
                    CurrencyFormatting.formatSigned(
                        amount: item.amount,
                        type: item.type,
                        currency: item.currency ?? currency
                    )
                )
                .font(.moneyMedium())
                .foregroundStyle(AppTheme.accent(for: item.type))
                .moneyDigits()
                .multilineTextAlignment(.trailing)

                if showsDate {
                    Text(DateFormatting.shortDate(item.date))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .opacity(item.isProjected ? 0.65 : 1)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private struct Badge {
        let symbol: String
        let tint: Color
    }

    /// Ordered by how much the badge changes what the row means.
    private var badges: [Badge] {
        var result: [Badge] = []
        if item.isSavingsContribution {
            result.append(Badge(symbol: "target", tint: AppTheme.savingsAccent))
        }
        if item.isLoanPayment {
            result.append(Badge(symbol: "building.columns.fill", tint: AppTheme.loanAccent))
        }
        // Ahead of the repeat and bookmark marks: with the two-badge cap, a
        // repeating bookmarked bill used to hide that it had a file at all.
        if item.hasAttachments {
            result.append(Badge(symbol: "paperclip", tint: .secondary))
        }
        if item.isRecurring {
            result.append(Badge(symbol: "repeat", tint: .secondary))
        }
        if item.isFeatured {
            result.append(Badge(symbol: "bookmark.fill", tint: AppTheme.expenseAccent))
        }
        return result
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
                currency: item.currency ?? currency
            )
        )
        parts.append(DateFormatting.shortDate(item.date))

        if item.isProjected {
            parts.append(NSLocalizedString("Forecast, not yet recorded", comment: "Accessibility"))
        } else if item.isRecurring {
            parts.append(NSLocalizedString("Part of a repeating entry", comment: "Accessibility"))
        }

        if item.isFeatured {
            parts.append(NSLocalizedString("Saved as a bill", comment: "Accessibility"))
        }
        if item.hasAttachments {
            parts.append(
                String(
                    format: NSLocalizedString("%d attachments", comment: "Accessibility"),
                    item.attachmentCount
                )
            )
        }
        if item.isSavingsContribution {
            parts.append(NSLocalizedString("Savings contribution", comment: "Accessibility"))
        }
        if item.isLoanPayment {
            parts.append(NSLocalizedString("Loan payment", comment: "Accessibility"))
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
