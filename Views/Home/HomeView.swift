import SwiftUI

/// The main page. Kept deliberately short: what is left, the goals and debts
/// being worked on, a fast way to add something, and the latest few entries.
/// Charts and breakdowns live behind Insights.
struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var viewModel: HomeViewModel

    let onOpenActivities: () -> Void
    let onOpenSavings: () -> Void
    let onOpenLoans: () -> Void

    private let recentLimit = 4

    private var period: DateInterval { store.selectedPeriod }
    private var summary: TransactionSummary { store.summary(in: period) }
    private var currency: Currency { store.state.settings.currency }

    private var recentOccurrences: [TransactionOccurrence] {
        Array(store.occurrences(in: period).prefix(recentLimit))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                periodStrip

                HeroBalanceCardView(
                    income: summary.income,
                    expense: summary.expense,
                    netBalance: summary.netBalance,
                    currency: currency,
                    periodText: DateRangeCalculator.periodDisplayText(for: period),
                    hasProjections: summary.hasProjections
                )

                quickAdd
                savingsSection
                loansSection
                recentActivity
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("manatik")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Period

    private var periodStrip: some View {
        HStack(spacing: 4) {
            Button {
                store.movePeriod(byMonths: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
            }
            .accessibilityLabel(Text("Previous period"))

            Button {
                viewModel.isShowingPeriodPicker = true
            } label: {
                HStack(spacing: 5) {
                    Text(DateRangeCalculator.periodDisplayText(for: period))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text("Change period"))

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

    // MARK: - Quick add

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Add")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            QuickAddBarView(categories: viewModel.quickAddCategories) { category in
                viewModel.beginQuickAdd(category)
            }
        }
    }

    // MARK: - Savings

    @ViewBuilder
    private var savingsSection: some View {
        let goals = store.activeSavingsGoals

        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Savings",
                actionTitle: goals.isEmpty ? nil : "All",
                action: goals.isEmpty ? nil : onOpenSavings
            )

            if goals.isEmpty {
                Button {
                    viewModel.newGoal()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "target")
                            .font(.title3)
                            .foregroundStyle(AppTheme.savingsAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set a savings goal")
                                .font(.subheadline.weight(.semibold))
                            Text("Track what you are putting aside.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.savingsAccent)
                    }
                    .frame(minHeight: AppTheme.minimumTapTarget)
                    .cozyCard(AppTheme.savingsSurface)
                }
                .buttonStyle(.plain)
            } else {
                // Scrolls sideways like Quick Add, so several goals fit without
                // pushing the rest of the page down.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(goals) { progress in
                            SavingsGoalCardView(
                                progress: progress,
                                currency: currency,
                                onAddMoney: { viewModel.contributingGoal = progress.goal },
                                onOpen: onOpenSavings
                            )
                            .frame(width: 290)
                        }
                    }
                    .padding(.vertical, 2)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
            }
        }
    }

    // MARK: - Loans

    @ViewBuilder
    private var loansSection: some View {
        let loans = store.activeLoans

        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Loans",
                actionTitle: loans.isEmpty ? nil : "All",
                action: loans.isEmpty ? nil : onOpenLoans
            )

            if loans.isEmpty {
                Button {
                    viewModel.newLoan()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "building.columns")
                            .font(.title3)
                            .foregroundStyle(AppTheme.loanAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Track a loan")
                                .font(.subheadline.weight(.semibold))
                            Text("See what you borrowed, paid and still owe.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.loanAccent)
                    }
                    .frame(minHeight: AppTheme.minimumTapTarget)
                    .cozyCard(AppTheme.loanSurface)
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(loans) { progress in
                            LoanCardView(
                                progress: progress,
                                currency: currency,
                                onRecordPayment: { viewModel.payingLoan = progress.loan },
                                onOpen: onOpenLoans
                            )
                            .frame(width: 290)
                        }
                    }
                    .padding(.vertical, 2)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
            }
        }
    }

    // MARK: - Recent

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Recent", actionTitle: "See all", action: onOpenActivities)

            if recentOccurrences.isEmpty {
                if store.hasAnyData {
                    EmptyStateView.emptyPeriod(
                        isCurrent: store.isViewingCurrentPeriod,
                        onGoToToday: { store.resetPeriodToToday() }
                    )
                } else {
                    EmptyStateView.noData(onAdd: { viewModel.beginAdd() })
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(recentOccurrences) { item in
                        Button {
                            viewModel.editingOccurrence = item
                        } label: {
                            TransactionRowView(
                                item: item,
                                category: store.category(for: item.categoryID),
                                currency: currency
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 14)

                        if item.id != recentOccurrences.last?.id {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
                .padding(.vertical, 6)
                .background(
                    AppTheme.cardBackground,
                    in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(
        title: LocalizedStringKey,
        actionTitle: LocalizedStringKey?,
        action: (() -> Void)?
    ) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: 32)
                }
            }
        }
    }
}
