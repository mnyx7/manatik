import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .frame(minHeight: AppTheme.minimumTapTarget)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

extension EmptyStateView {
    /// Nothing has ever been entered.
    static func noData(onAdd: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            systemImage: "tray",
            title: "No entries yet",
            subtitle: "Add your first income or expense to start tracking.",
            actionTitle: "Add an entry",
            action: onAdd
        )
    }

    /// Data exists, but the active filters exclude all of it. Telling the user
    /// to "add your first entry" here was simply wrong.
    static func noMatches(onClear: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            systemImage: "magnifyingglass",
            title: "No matching entries",
            subtitle: "Nothing in this range matches your filters.",
            actionTitle: "Clear filters",
            action: onClear
        )
    }

    /// Data exists, but not in the period being browsed.
    static func emptyPeriod(isCurrent: Bool, onGoToToday: @escaping () -> Void) -> EmptyStateView {
        if isCurrent {
            return EmptyStateView(
                systemImage: "calendar",
                title: "Nothing recorded this period",
                subtitle: "Entries you add will appear here."
            )
        }
        return EmptyStateView(
            systemImage: "calendar",
            title: "Nothing in this period",
            subtitle: "You have entries in other periods.",
            actionTitle: "Go to today",
            action: onGoToToday
        )
    }
}
