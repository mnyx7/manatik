import QuickLook
import SwiftUI

/// The full ledger, split into All, Income, Expense and Bills.
///
/// This is a `List`, not a `ScrollView` of stacked rows. `swipeActions` only
/// works on `List` rows, which is why swipe-to-delete did nothing before.
struct ActivitiesView: View {
    @Environment(AppStore.self) private var store
    @Bindable var viewModel: HomeViewModel

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

    @State private var billPreviewURL: URL?
    @State private var billPreviewURLs: [URL] = []

    /// Opens an entry's files in the system viewer, straight from its row.
    private func openAttachments(of item: TransactionOccurrence) {
        let urls = (store.transaction(id: item.transactionID)?.attachments ?? [])
            .filter(AttachmentStore.exists)
            .map(AttachmentStore.url(for:))
        billPreviewURLs = urls
        billPreviewURL = urls.first
    }

    /// Days of the period that have something on them, for the strip's dots.
    private var daysWithActivity: Set<Date> {
        let calendar = Calendar.current
        return Set(
            store.occurrences(in: store.selectedPeriod)
                .map { calendar.startOfDay(for: $0.date) }
        )
    }

    var body: some View {
        List {
            Section {
                Picker("Show", selection: $viewModel.scope) {
                    ForEach(ActivityScope.allCases) { scope in
                        Text(scope.localizedTitle).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            }

            // A plain day picker for the period, which is quicker than opening
            // a range sheet for the common "what did I spend on Tuesday".
            Section {
                DayStripView(
                    interval: store.selectedPeriod,
                    daysWithActivity: daysWithActivity,
                    selectedDay: Binding(
                        get: { viewModel.selectedDay },
                        set: { viewModel.selectedDay = $0 }
                    )
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .listRowBackground(Color.clear)
            }

            if viewModel.filter.hasUserChosenFilters {
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
        .quickLookPreview($billPreviewURL, in: billPreviewURLs)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
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
                        systemName: viewModel.filter.hasUserChosenFilters
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                }
                .accessibilityLabel(Text("Filters"))
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
                category: store.category(for: item.categoryID),
                currency: currency,
                // Rows sit under a day heading already.
                showsDate: false
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
            if item.hasAttachments {
                Button {
                    openAttachments(of: item)
                } label: {
                    Label("Open bill", systemImage: "paperclip")
                }
                .tint(AppTheme.savingsAccent)
            }

            // Bookmarking from the list as well as the form, so a bill can be
            // flagged after the fact.
            if item.transactionID != nil {
                Button {
                    store.toggleFeatured(item)
                } label: {
                    Label(
                        item.isFeatured ? "Unmark" : "Bill",
                        systemImage: item.isFeatured ? "bookmark.slash" : "bookmark.fill"
                    )
                }
                .tint(AppTheme.expenseAccent)
            }

            Button {
                viewModel.editingOccurrence = item
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.accentColor)
        }
        .contextMenu {
            if item.hasAttachments {
                Button {
                    openAttachments(of: item)
                } label: {
                    Label("Open bill", systemImage: "paperclip")
                }
            }
            if item.transactionID != nil {
                Button {
                    store.toggleFeatured(item)
                } label: {
                    Label(
                        item.isFeatured ? "Remove from Bills" : "Save as a bill",
                        systemImage: item.isFeatured ? "bookmark.slash" : "bookmark"
                    )
                }
            }
            Button {
                viewModel.editingOccurrence = item
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.pendingDelete = item
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !store.hasAnyData {
            EmptyStateView.noData(onAdd: { viewModel.beginAdd() })
        } else if viewModel.scope == .bills && !viewModel.filter.hasUserChosenFilters {
            EmptyStateView(
                systemImage: "bookmark",
                title: "No bills saved yet",
                subtitle: "Mark an entry as a bill and it will show up here."
            )
        } else if viewModel.filter.hasUserChosenFilters {
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
