import SwiftUI

/// Filter controls as a toolbar menu.
///
/// The old inline filter bar sat mid-page inside a ScrollView, so it scrolled
/// out of sight and the user could not tell a filter was still applied.
struct FilterMenuContent: View {
    @Binding var filter: TransactionFilter
    let categories: [TransactionCategory]
    let onEditDateRange: () -> Void

    var body: some View {
        Group {
            Picker(selection: $filter.type) {
                Text("All types").tag(TransactionType?.none)
                ForEach(TransactionType.allCases) { type in
                    Text(type.localizedTitle).tag(TransactionType?.some(type))
                }
            } label: {
                Text("Type")
            }

            Picker(selection: $filter.categoryID) {
                Text("All categories").tag(String?.none)
                ForEach(categories) { category in
                    Text("\(category.icon) \(category.localizedName)")
                        .tag(String?.some(category.id))
                }
            } label: {
                Text("Category")
            }

            Button {
                onEditDateRange()
            } label: {
                Label("Date range\u{2026}", systemImage: "calendar")
            }

            if filter.isActive {
                Divider()
                Button(role: .destructive) {
                    filter = .empty
                } label: {
                    Label("Clear filters", systemImage: "xmark.circle")
                }
            }
        }
    }
}

/// A persistent, visible summary of what is currently being filtered.
struct ActiveFilterSummaryView: View {
    let filter: TransactionFilter
    let intervalText: String?
    let resultCount: Int
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text(
                    String(
                        format: NSLocalizedString("%d matching entries", comment: "Filter summary"),
                        resultCount
                    )
                )
                .font(.subheadline.weight(.medium))

                Spacer(minLength: 8)

                Button(role: .destructive) {
                    onClear()
                } label: {
                    Text("Clear")
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: AppTheme.minimumTapTarget)
                }
            }

            if let intervalText {
                // Without this, a date range outside the browsed month looked
                // like an empty month rather than a deliberate range.
                Text(
                    String(
                        format: NSLocalizedString("Date range: %@", comment: "Filter summary"),
                        intervalText
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let descriptor = narrowingDescription {
                Text(descriptor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var narrowingDescription: String? {
        var parts: [String] = []

        if let type = filter.type {
            parts.append(type.localizedTitle)
        }
        if let categoryID = filter.categoryID {
            parts.append(DefaultCategories.category(for: categoryID).localizedName)
        }
        if !filter.trimmedSearchText.isEmpty {
            parts.append("\u{201C}\(filter.trimmedSearchText)\u{201D}")
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " \u{00B7} ")
    }
}
