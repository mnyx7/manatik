import SwiftUI

/// Charts and breakdowns.
///
/// These used to sit on the main page, which pushed the things people actually
/// open the app for below five cards of analysis.
struct InsightsView: View {
    @EnvironmentObject private var store: AppStore

    private var period: DateInterval { store.selectedPeriod }
    private var summary: TransactionSummary { store.summary(in: period) }
    private var currency: Currency { store.state.settings.currency }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                Text(DateRangeCalculator.periodDisplayText(for: period))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    SummaryCardView(
                        title: "Income",
                        value: CurrencyFormatting.format(amount: summary.income, currency: currency),
                        surface: AppTheme.incomeSurface,
                        accent: AppTheme.incomeAccent
                    )
                    SummaryCardView(
                        title: "Expense",
                        value: CurrencyFormatting.format(amount: summary.expense, currency: currency),
                        surface: AppTheme.expenseSurface,
                        accent: AppTheme.expenseAccent
                    )
                }

                SpendingChartView(
                    points: store.dailySpend(in: period),
                    averagePerDay: summary.averageSpendingPerDay,
                    currency: currency
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

                NavigationLink(value: RootDestination.yearOverview) {
                    HStack {
                        Label("Year Overview", systemImage: "calendar")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: AppTheme.minimumTapTarget)
                    .cozyCard()
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("Insights")
    }
}

#Preview {
    NavigationStack {
        InsightsView()
            .environmentObject(MockData.previewStore())
    }
}
