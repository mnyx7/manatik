import SwiftUI

/// Categories as tappable tiles.
///
/// Collapsed, it shows the five you reach for most recently plus a tile that
/// opens the rest, so the common case is one tap and the full list is never
/// more than two.
struct CategoryChipsView: View {
    let recent: [TransactionCategory]
    let all: [TransactionCategory]
    @Binding var selectedID: String
    var onAddNew: (() -> Void)?
    /// Driven by the magnifier beside the card's heading.
    @Binding var isSearching: Bool

    @State private var isExpanded = false
    @State private var query = ""
    @FocusState private var isQueryFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 80), spacing: 10)]

    private var matches: [TransactionCategory] {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return all }
        return all.filter {
            $0.localizedName.localizedStandardContains(term) || $0.name.localizedStandardContains(term)
        }
    }

    /// Always includes the current selection, even when it is not one of the
    /// recent five, so the chosen category is never hidden behind "more".
    private var collapsed: [TransactionCategory] {
        guard !recent.contains(where: { $0.id == selectedID }) else { return recent }
        guard let selected = all.first(where: { $0.id == selectedID }) else { return recent }
        return [selected] + recent.dropLast()
    }

    private var visible: [TransactionCategory] {
        guard isExpanded else { return collapsed }

        // Expanding keeps the collapsed tiles exactly where they were and
        // appends the rest. Showing `all` straight out meant every tile jumped
        // to a new place the moment More was tapped.
        let shown = Set(collapsed.map(\.id))
        return collapsed + all.filter { !shown.contains($0.id) }
    }

    var body: some View {
        if isSearching {
            searchBody
        } else {
            gridBody
        }
    }

    private var searchBody: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Find a category", text: $query)
                    .focused($isQueryFocused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Clear search"))
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: AppTheme.minimumTapTarget)
            .background(.quaternary.opacity(0.6), in: AppTheme.chipShape)

            if matches.isEmpty {
                VStack(spacing: 8) {
                    Text("No category called “\(query)”")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let onAddNew {
                        Button("Create one", action: onAddNew)
                            .font(.footnote.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 70)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(matches) { category in
                        tile(for: category)
                    }
                }
            }
        }
        .onAppear { isQueryFocused = true }
        .onDisappear { query = "" }
    }

    private var gridBody: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(visible) { category in
                tile(for: category)
            }

            if isExpanded {
                if let onAddNew {
                    actionTile(systemImage: "plus", title: "New", action: onAddNew)
                }
                actionTile(systemImage: "chevron.up", title: "Less") {
                    withAnimation(.smooth(duration: 0.22)) { isExpanded = false }
                }
            } else if all.count > collapsed.count {
                actionTile(systemImage: "ellipsis", title: "More") {
                    withAnimation(.smooth(duration: 0.22)) { isExpanded = true }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(for category: TransactionCategory) -> some View {
        let isSelected = category.id == selectedID
        let tint = CategoryVisuals.tint(for: category)

        Button {
            selectedID = category.id
            // A pick from the search is the answer; go back to the tiles.
            if isSearching {
                withAnimation(.smooth(duration: 0.22)) { isSearching = false }
            }
        } label: {
            VStack(spacing: 6) {
                CategoryIconView(category: category, size: .small, isProminent: isSelected)
                Text(category.localizedName)
                    .font(.caption2.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? tint : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                isSelected ? AnyShapeStyle(tint.opacity(0.14)) : AnyShapeStyle(.clear),
                in: AppTheme.chipShape
            )
            .overlay(
                AppTheme.chipShape
                    .strokeBorder(isSelected ? tint.opacity(0.55) : Color.primary.opacity(0.08))
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(category.localizedName))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func actionTile(
        systemImage: String,
        title: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .overlay(
                AppTheme.chipShape
                    .strokeBorder(Color.primary.opacity(0.08))
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
