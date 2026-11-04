import SwiftUI

struct QuickAddBarView: View {
    let categories: [TransactionCategory]
    let onTap: (TransactionCategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    Button {
                        onTap(category)
                    } label: {
                        HStack(spacing: 6) {
                            Text(category.icon)
                                .accessibilityHidden(true)
                            Text(category.localizedName)
                                .font(.footnote.weight(.medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        // Chips used to be ~34pt tall, under the 44pt minimum.
                        .frame(minHeight: AppTheme.minimumTapTarget)
                        .background(AppTheme.cardBackground, in: Capsule())
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
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }
}
