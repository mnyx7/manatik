import SwiftUI

/// Categories as tappable chips laid out in place.
///
/// A `Picker` pushed a separate list just to choose a category, which is two
/// extra taps for the most common choice on the screen.
struct CategoryChipsView: View {
    let categories: [TransactionCategory]
    @Binding var selectedID: String
    var accent: Color = .accentColor
    var onAddNew: (() -> Void)?

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(categories) { category in
                chip(for: category)
            }

            if let onAddNew {
                Button(action: onAddNew) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.title3)
                        Text("New")
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(
                        AppTheme.cardBackground,
                        in: RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius, style: .continuous)
                            .strokeBorder(accent.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    )
                    .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Add a new category"))
            }
        }
    }

    @ViewBuilder
    private func chip(for category: TransactionCategory) -> some View {
        let isSelected = category.id == selectedID

        Button {
            selectedID = category.id
        } label: {
            VStack(spacing: 4) {
                Text(category.icon)
                    .font(.title3)
                Text(category.localizedName)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                isSelected ? accent.opacity(0.18) : AppTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? accent : .clear, lineWidth: 2)
            )
            .foregroundStyle(isSelected ? accent : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(category.localizedName))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    CategoryChipsView(
        categories: Array(DefaultCategories.all.prefix(8)),
        selectedID: .constant("cafe"),
        onAddNew: {}
    )
    .padding()
    .background(AppTheme.pageBackground)
}
