import SwiftUI

/// The Overview tab: where the money went, by category, for the chosen period.
///
/// The pie is the headline because "which category eats my month" is the
/// question a list of totals never answered at a glance.
struct OverviewView: View {
    @EnvironmentObject private var store: AppStore

    /// The filter: which side of the ledger the chart is showing.
    @State private var side: TransactionType = .expense

    private var period: DateInterval { store.selectedPeriod }
    private var summary: TransactionSummary { store.summary(in: period) }
    private var currency: Currency { store.state.settings.currency }

    private var slices: [CategorySpending] {
        store.categorySpending(in: period, type: side)
    }

    private var sideTotal: Decimal {
        side == .expense ? summary.expense : summary.income
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                periodStrip

                Picker(selection: $side) {
                    ForEach(TransactionType.allCases) { type in
                        Text(type.localizedTitle).tag(type)
                    }
                } label: {
                    Text("Show")
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                CategoryPieChartView(
                    slices: slices,
                    total: sideTotal,
                    currency: currency,
                    centerCaption: side == .expense ? "Spent" : "Earned"
                )
                .cozyCard()

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
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("Overview")
    }

    private var periodStrip: some View {
        HStack(spacing: 4) {
            Button {
                store.movePeriod(byMonths: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
            }
            .accessibilityLabel(Text("Previous period"))

            Text(DateRangeCalculator.periodDisplayText(for: period))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)

            Button {
                store.movePeriod(byMonths: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
            }
            .accessibilityLabel(Text("Next period"))

            if !store.isViewingCurrentPeriod {
                Button {
                    store.resetPeriodToToday()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
                }
                .accessibilityLabel(Text("Back to today"))
            }
        }
    }
}

#Preview {
    NavigationStack {
        OverviewView()
            .environmentObject(MockData.previewStore())
    }
}
