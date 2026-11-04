import SwiftUI

/// The full ledger.
///
/// This is a `List`, not a `ScrollView` of stacked rows. `swipeActions` only
/// works on `List` rows, which is why swipe-to-delete did nothing before and
/// why the delete confirmation was unreachable code.
struct ActivitiesView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var viewModel: HomeViewModel

    private var browsedInterval: DateInterval {
        viewModel.browsedInterval(defaultPeriod: store.selectedPeriod)
    }

    private var sections: [DailyTransactionSection] {
        store.sections(in: browsedInterval, filter: viewModel.filter)
    }

    private var resultCount: Int {
        sections.reduce(0) { $0 + $1.items.count }
    }

    private var currency: Currency { store.state.settings.currency }

    var body: some View {
        List {
            if viewModel.filter.isActive {
                Section {
                    ActiveFilterSummaryView(
                        filter: viewModel.filter,
                        intervalText: viewModel.filter.dateInterval.map {
                            DateRangeCalculator.periodDisplayText(for: $0)
                        },
                        resultCount: resultCount,
                        onClear: { viewModel.clearFilters() }
                    )
                }
            } else {
                Section {
                    HStack {
                        Text(DateRangeCalculator.periodDisplayText(for: browsedInterval))
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(
                            String(
                                format: NSLocalizedString("%d entries", comment: "Count"),
                                resultCount
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            if sections.isEmpty {
                Section { emptyState }
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            row(item)
                        }
                    } header: {
                        HStack {
                            Text(section.title)
                            Spacer()
                            Text(CurrencyFormatting.format(amount: section.net, currency: currency))
                                .foregroundStyle(AppTheme.netAccent(for: section.net))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Activities")
        .searchable(
            text: $viewModel.filter.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Search notes and categories")
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    FilterMenuContent(
                        filter: $viewModel.filter,
                        categories: store.categories,
                        onEditDateRange: { viewModel.isShowingDateFilter = true }
                    )
                } label: {
                    Image(
                        systemName: viewModel.filter.isActive
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                }
                .accessibilityLabel(Text("Filters"))
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.beginAdd()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text("Add income or expense"))
            }
        }
    }

    @ViewBuilder
    private func row(_ item: TransactionOccurrence) -> some View {
        Button {
            viewModel.editingOccurrence = item
        } label: {
            TransactionRowView(
                item: item,
                category: DefaultCategories.category(for: item.categoryID),
                currency: currency
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.pendingDelete = item
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                viewModel.editingOccurrence = item
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.accentColor)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !store.hasAnyData {
            EmptyStateView.noData(onAdd: { viewModel.beginAdd() })
        } else if viewModel.filter.isActive {
            // Telling someone with 200 entries to "add your first" was the bug.
            EmptyStateView.noMatches(onClear: { viewModel.clearFilters() })
        } else {
            EmptyStateView.emptyPeriod(
                isCurrent: store.isViewingCurrentPeriod,
                onGoToToday: { store.resetPeriodToToday() }
            )
        }
    }
}

#Preview {
    NavigationStack {
        ActivitiesView(viewModel: HomeViewModel())
            .environmentObject(MockData.previewStore())
    }
}
