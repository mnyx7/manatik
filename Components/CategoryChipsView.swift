import SwiftUI

/// Categories as tappable chips.
///
/// Collapsed, it shows the five you reach for most recently plus a chip that
/// opens the rest, so the common case is one tap and the full list is never
/// more than two.
struct CategoryChipsView: View {
    let recent: [TransactionCategory]
    let all: [TransactionCategory]
    @Binding var selectedID: String
    var accent: Color = .accentColor
    var onAddNew: (() -> Void)?

    @State private var isExpanded = false

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 8)]

    /// Always includes the current selection, even when it is not one of the
    /// recent five, so the chosen category is never hidden behind "more".
    private var collapsed: [TransactionCategory] {
        guard !recent.contains(where: { $0.id == selectedID }) else { return recent }
        guard let selected = all.first(where: { $0.id == selectedID }) else { return recent }
        return [selected] + recent.dropLast()
    }

    private var visible: [TransactionCategory] {
        isExpanded ? all : collapsed
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(visible) { category in
                chip(for: category)
            }

            if isExpanded {
                if let onAddNew {
                    actionChip(systemImage: "plus", title: "New", dashed: true, action: onAddNew)
                }
                actionChip(systemImage: "chevron.up", title: "Less", dashed: false) {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded = false }
                }
            } else if all.count > collapsed.count {
                actionChip(systemImage: "ellipsis", title: "More", dashed: false) {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true }
                }
            }
        }
    }

    @ViewBuilder
    private func chip(for category: TransactionCategory) -> some View {
        let isSelected = category.id == selectedID

        Button {
            selectedID = category.id
        } label: {
            VStack(spacing: 3) {
                Text(category.icon)
                    .font(.title3)
                Text(category.localizedName)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
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

    @ViewBuilder
    private func actionChip(
        systemImage: String,
        title: LocalizedStringKey,
        dashed: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.body)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                AppTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.innerCornerRadius, style: .continuous)
                    .strokeBorder(
                        accent.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, dash: dashed ? [4, 3] : [])
                    )
            )
            .foregroundStyle(accent)
        }
        .buttonStyle(.plain)
    }
}
