import SwiftUI

/// The fastest path to a new entry: one tap opens the form with the category
/// already chosen.
///
/// Icon above label, rather than an emoji beside it. The tile carries the
/// category's own colour, which makes the row scannable by shape and hue
/// instead of forcing the eye to read six words.
struct QuickAddBarView: View {
    let categories: [TransactionCategory]
    let onTap: (TransactionCategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories) { category in
                    Button {
                        onTap(category)
                    } label: {
                        VStack(spacing: 6) {
                            CategoryIconView(category: category, size: .medium)
                            Text(category.localizedName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(width: 66)
                        .padding(.vertical, 10)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String(
                            format: NSLocalizedString("Add %@ entry", comment: "Accessibility"),
                            category.localizedName
                        )
                    )
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }
}

#Preview {
    ZStack {
        AppBackgroundView()
        QuickAddBarView(
            categories: DefaultCategories.quickAddCategoryIDs.map {
                DefaultCategories.category(for: $0)
            },
            onTap: { _ in }
        )
        .padding()
    }
}
