import SwiftUI

struct FilterBarView: View {
    @Binding var filter: TransactionFilter
    let categories: [TransactionCategory]
    let onDateFilterTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            TextField("Search note", text: $filter.searchText)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Menu {
                    Button("All Categories") { filter.categoryID = nil }
                    ForEach(categories) { category in
                        Button("\(category.icon) \(category.name)") {
                            filter.categoryID = category.id
                        }
                    }
                } label: {
                    filterChip(title: selectedCategoryTitle)
                }

                Menu {
                    Button("All Types") { filter.type = nil }
                    ForEach(TransactionType.allCases) { type in
                        Button(type.title) { filter.type = type }
                    }
                } label: {
                    filterChip(title: filter.type?.title ?? "Type")
                }

                Button(action: onDateFilterTap) {
                    filterChip(title: filter.dateInterval == nil ? "Date" : "Date ✓")
                }

                if filter.isActive {
                    Button("Clear") {
                        filter = .empty
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
    }

    private var selectedCategoryTitle: String {
        guard let id = filter.categoryID else { return "Category" }
        let category = categories.first(where: { $0.id == id }) ?? DefaultCategories.category(for: id)
        return "\(category.icon) \(category.name)"
    }

    private func filterChip(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground), in: Capsule())
    }
}
