import SwiftUI

/// The main page. Deliberately short: what is left, the goals and debts being
/// worked on, a fast way to add something, and the latest few entries.
///
/// The period controls moved into the navigation bar. They used to take a whole
/// content row of their own, and the range was then printed a second time
/// inside the balance card directly below it.
struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Bindable var viewModel: HomeViewModel

    let onOpenActivities: (ActivityScope) -> Void
    let onOpenSavings: () -> Void
    let onOpenLoans: () -> Void
    let onOpenGoal: (UUID) -> Void
    let onOpenLoan: (UUID) -> Void

    private let recentLimit = 4
    private let carouselCardWidth: CGFloat = 268

    private var period: DateInterval { store.selectedPeriod }
    private var summary: TransactionSummary { store.summary(in: period) }
    private var currency: Currency { store.state.settings.currency }

    private var recentOccurrences: [TransactionOccurrence] {
        Array(store.occurrences(in: period).prefix(recentLimit))
    }

    /// A brand new install: no entries, no goals, no loans. One clear next step
    /// beats three competing "add something" prompts.
    private var isFirstRun: Bool {
        !store.hasAnyData
            && store.activeSavingsGoals.isEmpty
            && store.activeLoans.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                if isFirstRun {
                    welcomeCard
                } else {
                    HeroBalanceCardView(
                        income: summary.income,
                        expense: summary.expense,
                        netBalance: summary.netBalance,
                        currency: currency,
                        hasProjections: summary.hasProjections,
                        otherCurrencies: CurrencyFormatting.formatOthers(summary.otherCurrencies),
                        onOpen: onOpenActivities
                    )

                    quickAdd
                    savingsSection
                    loansSection
                    recentActivity
                }
            }
            .padding(.horizontal, AppTheme.pageHorizontalPadding)
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        // The bar floats over the page, so the last row needs room to clear it.
        .contentMargins(.bottom, AppTheme.tabBarClearance, for: .scrollContent)
        .navigationTitle(DateRangeCalculator.periodDisplayText(for: period))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { PeriodToolbar(store: store, viewModel: viewModel) }
    }

    // MARK: - First run

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 6) {
                Text("Start with one entry")
                    .font(.title3.weight(.semibold))
                Text("Add something you spent or earned today. Savings goals and loans can wait until you want them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                viewModel.beginAdd()
            } label: {
                Text("Add an entry")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AppTheme.minimumTapTarget)
            }
            .glassProminentButtonStyle()

            QuickAddBarView(categories: viewModel.quickAddCategories) { category in
                viewModel.beginQuickAdd(category)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Quick add

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Quick add", actionTitle: nil, action: nil)

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
                promptCard(
                    symbol: "target",
                    tint: AppTheme.savingsAccent,
                    title: "Set a savings goal",
                    subtitle: "Track what you are putting aside.",
                    action: { viewModel.newGoal() }
                )
            } else {
                carousel {
                    ForEach(goals) { progress in
                        SavingsGoalCardView(
                            progress: progress,
                            currency: currency,
                            onAddMoney: { viewModel.contributingGoal = progress.goal },
                            onOpen: { onOpenGoal(progress.goal.id) }
                        )
                        .frame(width: carouselCardWidth)
                    }
                }
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
                promptCard(
                    symbol: "building.columns",
                    tint: AppTheme.loanAccent,
                    title: "Track a loan",
                    subtitle: "See what you borrowed, paid and still owe.",
                    action: { viewModel.newLoan() }
                )
            } else {
                carousel {
                    ForEach(loans) { progress in
                        LoanCardView(
                            progress: progress,
                            currency: currency,
                            onRecordPayment: { viewModel.payingLoan = progress.loan },
                            onOpen: { onOpenLoan(progress.loan.id) }
                        )
                        .frame(width: carouselCardWidth)
                    }
                }
            }
        }
    }

    // MARK: - Recent

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Recent", actionTitle: "See all", action: { onOpenActivities(.all) })

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
                                category: store.category(for: item.categoryID),
                                currency: currency
                            )
                        }
                        .buttonStyle(.plain)

                        if item.id != recentOccurrences.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .glassCard(padding: 14)
            }
        }
    }

    // MARK: - Building blocks

    /// Horizontally paged cards, so several goals fit without pushing the rest
    /// of the page down.
    @ViewBuilder
    private func carousel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                content()
            }
            .padding(.vertical, 2)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func promptCard(
        symbol: String,
        tint: Color,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.16), in: AppTheme.innerShape)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "plus")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: AppTheme.minimumTapTarget)
            .interactiveGlassCard(tint: tint)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionHeader(
        title: LocalizedStringKey,
        actionTitle: LocalizedStringKey?,
        action: (() -> Void)?
    ) -> some View {
        HStack {
            Text(title)
                .font(.sectionTitle())
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                            .font(.footnote.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .frame(minHeight: 32)
                }
            }
        }
    }
}
