import SwiftUI

/// A category's symbol in a tinted, rounded tile.
///
/// One component for every place a category appears — rows, chips, charts,
/// pickers — so the app has exactly one category "look" instead of five
/// slightly different emoji renderings.
struct CategoryIconView: View {
    enum Size {
        case small
        case medium
        case large

        var side: CGFloat {
            switch self {
            case .small: return 30
            case .medium: return 40
            case .large: return 52
            }
        }

        var symbolSize: CGFloat {
            switch self {
            case .small: return 13
            case .medium: return 17
            case .large: return 22
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 9
            case .medium: return 12
            case .large: return 16
            }
        }
    }

    let category: TransactionCategory
    var size: Size = .medium
    /// Filled tiles read as "selected"; otherwise the tint stays a wash.
    var isProminent = false

    private var tint: Color { CategoryVisuals.tint(for: category) }

    var body: some View {
        Image(systemName: CategoryVisuals.symbolName(for: category))
            .font(.system(size: size.symbolSize, weight: .semibold))
            .foregroundStyle(isProminent ? .white : tint)
            .frame(width: size.side, height: size.side)
            .background(
                isProminent ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.16)),
                in: RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
            )
            // VoiceOver reads the category name from the surrounding row, so the
            // glyph itself must stay silent.
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 14) {
        CategoryIconView(category: DefaultCategories.category(for: "groceries"), size: .small)
        CategoryIconView(category: DefaultCategories.category(for: "cafe"))
        CategoryIconView(category: DefaultCategories.category(for: "salary"), size: .large)
        CategoryIconView(
            category: DefaultCategories.category(for: "travel"),
            size: .large,
            isProminent: true
        )
    }
    .padding(40)
    .background(AppBackgroundView())
}
