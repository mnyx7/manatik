import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel

    @State private var showingDateFilterSheet = false
    @State private var showingPeriodPicker = false
    @State private var quickAddCategoryID: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    periodHeader
                    summaryCards
                    savingsCard
                    statsCard
                    quickAddBar
                    filterBar
                    categoryTotals
                    transactionsSection
                }
                .padding()
            }
            .background(AppTheme.groupedBackground)
            .navigationTitle("manatik")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        quickAddCategoryID = nil
                        viewModel.editingTransactionID = nil
                        viewModel.isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingAddSheet) {
                TransactionFormView(
                    viewModel: TransactionFormViewModel(
                        store: viewModel.store,
                        mode: .add(preselectedCategoryID: quickAddCategoryID)
                    )
                )
            }
            .sheet(isPresented: $viewModel.isShowingSettings) {
                SettingsView(viewModel: SettingsViewModel(store: viewModel.store))
            }
            .sheet(isPresented: $viewModel.isShowingYearlyOverview) {
                YearlyOverviewView(
                    viewModel: YearlyOverviewViewModel(
                        store: viewModel.store,
                        year: viewModel.store.selectedYear
                    )
                )
            }
            .sheet(isPresented: $showingDateFilterSheet) {
                DateFilterSheetView(filter: $viewModel.filter)
            }
            .sheet(isPresented: $showingPeriodPicker) {
                PeriodPickerSheet(
                    selectedDate: viewModel.store.state.selectedPeriodAnchorDate,
                    onSelect: { viewModel.setPeriodAnchorDate($0) }
                )
            }
            .confirmationDialog(
                "Delete this transaction?",
                isPresented: Binding(
                    get: { viewModel.pendingDeleteID != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.pendingDeleteID = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    viewModel.deletePendingTransaction()
                }
                Button("Cancel", role: .cancel) {
                    viewModel.pendingDeleteID = nil
                }
            }
        }
    }

    private var periodHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                viewModel.isShowingYearlyOverview = true
            } label: {
                Text(viewModel.selectedYearText)
                    .font(.title2.bold())
            }
            .buttonStyle(.plain)

            Button {
                showingPeriodPicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.selectedPeriodText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            HStack {
                Button("Previous") { viewModel.movePeriod(by: -1) }
                Spacer()
                Button("Next") { viewModel.movePeriod(by: 1) }
            }
            .font(.footnote.weight(.medium))
        }
    }

    private var summaryCards: some View {
        let summary = viewModel.summary
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            SummaryCardView(
                title: "Income",
                value: viewModel.amountText(summary.income),
                backgroundColor: AppTheme.incomeColor,
                valueColor: .green
            )
            SummaryCardView(
                title: "Expense",
                value: viewModel.amountText(summary.expense),
                backgroundColor: AppTheme.expenseColor,
                valueColor: .red
            )
            SummaryCardView(
                title: "Amount Left",
                value: viewModel.amountText(summary.amountLeft),
                backgroundColor: AppTheme.savingsColor,
                valueColor: summary.amountLeft < 0 ? .red : .blue
            )
            SummaryCardView(
                title: "Avg/day",
                value: viewModel.amountText(summary.averageSpendingPerDay),
                backgroundColor: Color(.secondarySystemBackground),
                valueColor: .primary
            )
        }
    }

    private var savingsCard: some View {
        let progress = viewModel.monthlySavingsProgress()
        return SavingsGoalCardView(
            currentText: viewModel.amountText(progress.current),
            targetText: viewModel.amountText(progress.target),
            progress: progress.progress
        )
    }

    private var statsCard: some View {
        let summary = viewModel.summary
        return StatisticsCardView(
            averagePerDay: viewModel.amountText(summary.averageSpendingPerDay),
            biggestExpense: viewModel.amountText(summary.biggestExpense),
            transactionCount: summary.totalTransactions,
            amountLeft: viewModel.amountText(summary.amountLeft)
        )
    }

    private var quickAddBar: some View {
        QuickAddBarView(categories: viewModel.quickAddCategories) { category in
            quickAddCategoryID = category.id
            viewModel.isShowingAddSheet = true
        }
    }

    private var filterBar: some View {
        FilterBarView(
            filter: $viewModel.filter,
            categories: viewModel.store.categories,
            onDateFilterTap: { showingDateFilterSheet = true }
        )
    }

    private var categoryTotals: some View {
        CategoryTotalsCardView(
            totals: viewModel.categoryTotals,
            amountText: viewModel.amountText
        )
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transactions")
                .font(.headline)

            if viewModel.sections.isEmpty {
                EmptyStateView(
                    title: "No transactions",
                    subtitle: "Tap + to add your first income or expense."
                )
            } else {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            let category = DefaultCategories.category(for: item.categoryID)
                            TransactionRowView(
                                item: item,
                                category: category,
                                amountText: viewModel.amountText(item.amount)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.editingTransactionID = item.transactionID
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.pendingDeleteID = item.transactionID
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.editingTransactionID != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.editingTransactionID = nil
                    }
                }
            )
        ) {
            if let id = viewModel.editingTransactionID {
                TransactionFormView(
                    viewModel: TransactionFormViewModel(
                        store: viewModel.store,
                        mode: .edit(transactionID: id)
                    )
                )
            }
        }
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel(store: AppStore()))
}
