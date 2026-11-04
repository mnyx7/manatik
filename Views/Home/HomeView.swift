import SwiftUI

/// The main page. Shows where the current period stands and gives one-tap
/// capture; the full ledger lives behind Activities in the bottom bar.
struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var viewModel: HomeViewModel

    let onOpenActivities: () -> Void
    let onOpenYearOverview: () -> Void

    private let recentLimit = 5

    private var period: DateInterval { store.selectedPeriod }
    private var summary: TransactionSummary { store.summary(in: period) }
    private var currency: Currency { store.state.settings.currency }

    private var recentOccurrences: [TransactionOccurrence] {
        Array(store.occurrences(in: period).prefix(recentLimit))
    }

    private var savingsCurrent: Decimal {
        let goal = store.state.settings.savingsGoal
        // Overspend is passed through rather than clamped, so a negative month
        // no longer looks identical to "no progress yet".
        return goal.useAmountLeftForProgress ? summary.netBalance : goal.currentSavedAmount
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PeriodHeaderView(
                    periodText: DateRangeCalculator.periodDisplayText(for: period),
                    isCurrentPeriod: store.isViewingCurrentPeriod,
                    income: summary.income,
                    expense: summary.expense,
                    netBalance: summary.netBalance,
                    currency: currency,
                    hasProjections: summary.hasProjections,
                    onPrevious: { store.movePeriod(byMonths: -1) },
                    onNext: { store.movePeriod(byMonths: 1) },
                    onPickPeriod: { viewModel.isShowingPeriodPicker = true },
                    onGoToToday: { store.resetPeriodToToday() }
                )

                quickAdd

                if store.hasAnyData {
                    SpendingChartView(
                        points: store.dailySpend(in: period),
                        averagePerDay: summary.averageSpendingPerDay,
                        currency: currency
                    )

                    SavingsGoalCardView(
                        currentAmount: savingsCurrent,
                        targetAmount: store.state.settings.savingsGoal.targetAmount,
                        currency: currency,
                        tracksAmountLeft: store.state.settings.savingsGoal.useAmountLeftForProgress
                    )

                    StatisticsCardView(
                        averagePerDay: CurrencyFormatting.format(
                            amount: summary.averageSpendingPerDay,
                            currency: currency
                        ),
                        biggestExpense: CurrencyFormatting.format(
                            amount: summary.biggestExpense,
                            currency: currency
                        ),
                        transactionCount: summary.totalTransactions,
                        projectedCount: summary.projectedTransactions,
                        elapsedDays: DateRangeCalculator.elapsedDayCount(for: period),
                        totalDays: DateRangeCalculator.dayCount(for: period)
                    )

                    CategoryTotalsCardView(
                        totals: store.categorySpending(in: period),
                        currency: currency
                    )

                    recentActivity
                    yearOverviewLink
                } else {
                    EmptyStateView.noData(onAdd: { viewModel.beginAdd() })
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle("manatik")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick Add")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            QuickAddBarView(categories: viewModel.quickAddCategories) { category in
                viewModel.beginQuickAdd(category)
            }
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                Button(action: onOpenActivities) {
                    Text("See all")
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: AppTheme.minimumTapTarget)
                }
            }

            if recentOccurrences.isEmpty {
                EmptyStateView.emptyPeriod(
                    isCurrent: store.isViewingCurrentPeriod,
                    onGoToToday: { store.resetPeriodToToday() }
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(recentOccurrences) { item in
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
                        .padding(.horizontal, 12)

                        if item.id != recentOccurrences.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(
                    AppTheme.cardBackground,
                    in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                )
            }
        }
    }

    private var yearOverviewLink: some View {
        // Previously this screen was reachable only by tapping unstyled year
        // text, which gave no sign it was a control at all.
        Button(action: onOpenYearOverview) {
            HStack {
                Label("Year Overview", systemImage: "calendar")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(minHeight: AppTheme.minimumTapTarget)
            .background(
                AppTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HomeView(viewModel: HomeViewModel(), onOpenActivities: {}, onOpenYearOverview: {})
            .environmentObject(MockData.previewStore())
    }
}
