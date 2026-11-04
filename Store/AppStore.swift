import Foundation
import SwiftUI

struct TransactionDraft {
    var amount: Decimal
    var note: String
    var categoryID: String
    var type: TransactionType
    var date: Date
    var recurrenceRule: RecurrenceRule
    var recurrenceEndDate: Date?
    var isFeatured: Bool = false
    var attachments: [Attachment] = []
}

struct MonthOverviewItem: Identifiable, Hashable {
    var id: String { "\(year)-\(month)" }
    let month: Int
    let year: Int
    let interval: DateInterval
    let income: Decimal
    let expense: Decimal

    var net: Decimal { income - expense }
    var hasActivity: Bool { income != 0 || expense != 0 }
}

/// A problem the user must know about, because it affects whether their data is
/// being saved at all.
struct PersistenceIssue: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let backupCopy: URL?
    /// Blocking issues stop all saving until the user decides what to do.
    let isBlocking: Bool
}

struct PendingImport {
    let state: AppState
    let incomingTransactionCount: Int
    let incomingSeriesCount: Int
    let currentTransactionCount: Int
    let currentSeriesCount: Int
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var state: AppState

    /// Which period is being viewed. Deliberately NOT persisted: a budget app
    /// must open on the current month, not on whatever month was last browsed.
    @Published private(set) var periodAnchorDate: Date

    @Published var persistenceIssue: PersistenceIssue?

    /// True after an unreadable data file. While set, nothing is written, so a
    /// decode failure cannot overwrite real data with an empty state.
    @Published private(set) var isPersistenceSuspended = false

    private let persistence: AppStatePersisting
    private let recurringService: RecurringTransactionServicing
    private let calendar: Calendar

    /// Bumped on every mutation; invalidates the derived caches below.
    private var revision = 0
    private var categoryCacheRevision = -1
    private var mergedCategories: [TransactionCategory] = []
    private var occurrenceCache: [DateInterval: [TransactionOccurrence]] = [:]
    private var summaryCache: [DateInterval: TransactionSummary] = [:]
    private var categorySpendCache: [CategoryCacheKey: [CategorySpending]] = [:]
    private var yearCache: [Int: [MonthOverviewItem]] = [:]

    private struct CategoryCacheKey: Hashable {
        let interval: DateInterval
        let type: TransactionType
    }

    init(
        persistence: AppStatePersisting = AppStatePersistence(),
        recurringService: RecurringTransactionServicing = RecurringTransactionService(),
        calendar: Calendar = .current,
        initialState: AppState? = nil
    ) {
        self.persistence = persistence
        self.recurringService = recurringService
        self.calendar = calendar
        self.periodAnchorDate = Date()

        if let initialState {
            self.state = initialState
            return
        }

        switch persistence.load() {
        case .fresh:
            self.state = .default

        case .loaded(let loaded):
            self.state = loaded

        case .migrated(let migrated, let fromVersion):
            self.state = migrated
            self.persistenceIssue = PersistenceIssue(
                title: NSLocalizedString("Data upgraded", comment: "Alert title"),
                message: String(
                    format: NSLocalizedString(
                        "Your data was saved in an older format (version %d) and has been upgraded. Recurring entries now keep their own history, and your savings goal moved into the new goals list.",
                        comment: "Alert message"
                    ),
                    fromVersion
                ),
                backupCopy: nil,
                isBlocking: false
            )

        case .unreadable(let message, let backupCopy):
            self.state = .default
            self.isPersistenceSuspended = true
            self.persistenceIssue = PersistenceIssue(
                title: NSLocalizedString("Could not read your data", comment: "Alert title"),
                message: message,
                backupCopy: backupCopy,
                isBlocking: true
            )
        }
    }

    // MARK: - Categories

    /// Built-in plus the user's own, in the order the user arranged, with
    /// hidden ones removed. This is what the pickers and filters offer.
    var categories: [TransactionCategory] {
        if categoryCacheRevision != revision {
            mergedCategories = orderedCategories.filter {
                !state.hiddenCategoryIDs.contains($0.id)
            }
            categoryCacheRevision = revision
        }
        return mergedCategories
    }

    /// Every category including hidden ones, in the user's order. The manager
    /// in Settings needs the hidden ones listed so they can be brought back.
    var allCategoriesInOrder: [TransactionCategory] {
        orderedCategories
    }

    private var orderedCategories: [TransactionCategory] {
        let merged = DefaultCategories.merged(with: state.customCategories)
        guard !state.categoryOrder.isEmpty else { return merged }

        let rank = Dictionary(
            state.categoryOrder.enumerated().map { ($1, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Decorated sort: Swift's sort is not stable, so anything the user has
        // not explicitly ranked keeps its original position instead of
        // shuffling about on every read.
        return merged.enumerated()
            .sorted { lhs, rhs in
                let left = rank[lhs.element.id] ?? Int.max
                let right = rank[rhs.element.id] ?? Int.max
                if left != right { return left < right }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    func categories(for type: TransactionType) -> [TransactionCategory] {
        DefaultCategories.filtered(categories, for: type)
    }

    func category(for id: String) -> TransactionCategory {
        DefaultCategories.category(for: id, custom: state.customCategories)
    }

    /// The categories this person actually reaches for, most recent first.
    ///
    /// `state.transactions` is kept sorted newest-first, so the first unique
    /// ids encountered are the recent ones. Padded with the standard list when
    /// there is not enough history yet.
    func recentCategories(for type: TransactionType, limit: Int = 5) -> [TransactionCategory] {
        let allowed = categories(for: type)

        // Turned off, the form simply follows the order set in Settings.
        guard state.settings.showsRecentCategoriesFirst else {
            return Array(allowed.prefix(limit))
        }

        let allowedIDs = Set(allowed.map(\.id))

        var seen = Set<String>()
        var result: [TransactionCategory] = []

        for transaction in state.transactions where transaction.type == type {
            let id = transaction.categoryID
            guard allowedIDs.contains(id), !seen.contains(id) else { continue }
            seen.insert(id)
            result.append(category(for: id))
            if result.count >= limit { return result }
        }

        for candidate in allowed where !seen.contains(candidate.id) {
            seen.insert(candidate.id)
            result.append(candidate)
            if result.count >= limit { break }
        }

        return result
    }

    @discardableResult
    func addCustomCategory(name: String, icon: String, kind: CategoryKind) -> TransactionCategory? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let id = DefaultCategories.makeCustomID(
            from: trimmed,
            existing: categories.map(\.id)
        )
        let category = TransactionCategory(
            id: id,
            name: trimmed,
            icon: icon.isEmpty ? "\u{1F516}" : icon,
            kind: kind,
            isCustom: true
        )
        state.customCategories.append(category)
        mutated()
        return category
    }

    /// Entries keep their category id, so removing a custom category leaves
    /// them showing the fallback rather than silently changing their amounts.
    func deleteCustomCategory(id: String) {
        state.customCategories.removeAll { $0.id == id }
        mutated()
    }

    func transactionCount(usingCategory id: String) -> Int {
        state.transactions.filter { $0.categoryID == id }.count
    }

    /// Categories the app itself writes to. Hiding these would leave savings
    /// contributions and loan payments pointing at something the user cannot
    /// see, so they stay available.
    static let protectedCategoryIDs: Set<String> = [
        DefaultCategories.savingsCategoryID,
        DefaultCategories.loanCategoryID,
        "other"
    ]

    func canHideCategory(_ id: String) -> Bool {
        !Self.protectedCategoryIDs.contains(id)
    }

    func isCategoryHidden(_ id: String) -> Bool {
        state.hiddenCategoryIDs.contains(id)
    }

    func setCategoryHidden(_ id: String, hidden: Bool) {
        guard canHideCategory(id) || !hidden else { return }
        if hidden {
            state.hiddenCategoryIDs.insert(id)
        } else {
            state.hiddenCategoryIDs.remove(id)
        }
        mutated()
    }

    /// Reorders using offsets taken against `allCategoriesInOrder`, so the
    /// stored order always covers every category and stays unambiguous.
    func moveCategories(from source: IndexSet, to destination: Int) {
        var ids = allCategoriesInOrder.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        state.categoryOrder = ids
        mutated()
    }

    func resetCategoryOrder() {
        state.categoryOrder = []
        mutated()
    }

    /// Only user-made categories can be renamed: the built-in names are
    /// localization keys, so editing one would break its translations.
    func updateCustomCategory(
        id: String,
        name: String,
        icon: String,
        kind: CategoryKind
    ) {
        guard let index = state.customCategories.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.customCategories[index] = TransactionCategory(
            id: id,
            name: trimmed,
            icon: icon.isEmpty ? "\u{1F516}" : icon,
            kind: kind,
            isCustom: true
        )
        mutated()
    }

    // MARK: - Feedback

    var feedbackNotes: [FeedbackNote] {
        state.feedbackNotes.sorted { $0.createdAt > $1.createdAt }
    }

    func addFeedback(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.feedbackNotes.append(FeedbackNote(text: trimmed))
        mutated()
    }

    func deleteFeedback(id: UUID) {
        state.feedbackNotes.removeAll { $0.id == id }
        mutated()
    }

    // MARK: - Period

    var selectedPeriod: DateInterval {
        DateRangeCalculator.period(
            for: periodAnchorDate,
            monthStartDay: state.settings.monthStartDay,
            calendar: calendar
        )
    }

    var selectedYear: Int {
        calendar.component(.year, from: periodAnchorDate)
    }

    var isViewingCurrentPeriod: Bool {
        DateRangeCalculator.isCurrentPeriod(selectedPeriod, calendar: calendar)
    }

    func setPeriodAnchor(_ date: Date) {
        periodAnchorDate = date
    }

    func movePeriod(byMonths value: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: value, to: periodAnchorDate) else {
            return
        }
        periodAnchorDate = shifted
    }

    func resetPeriodToToday() {
        periodAnchorDate = Date()
    }

    /// Everything at or before this instant is a recorded entry; after it, a forecast.
    private var materializationBoundary: Date {
        calendar.startOfDay(for: Date())
    }

    // MARK: - Derived ledger data (cached per revision)

    func occurrences(in interval: DateInterval) -> [TransactionOccurrence] {
        if let cached = occurrenceCache[interval] { return cached }

        let concrete = state.transactions
            .filter { interval.contains($0.date) }
            .map { transaction in
                TransactionOccurrence(
                    id: "tx-\(transaction.id.uuidString)",
                    transactionID: transaction.id,
                    seriesID: transaction.seriesID,
                    amount: transaction.amount,
                    note: transaction.note,
                    categoryID: transaction.categoryID,
                    type: transaction.type,
                    date: transaction.date,
                    isProjected: false,
                    isFeatured: transaction.isFeatured,
                    attachmentCount: transaction.attachments.count,
                    savingsGoalID: transaction.savingsGoalID,
                    loanID: transaction.loanID
                )
            }

        let projected = recurringService.projections(
            for: state.recurringSeries,
            in: interval,
            after: materializationBoundary
        )

        let combined = (concrete + projected).sorted { lhs, rhs in
            if lhs.date == rhs.date { return lhs.id < rhs.id }
            return lhs.date > rhs.date
        }

        occurrenceCache[interval] = combined
        return combined
    }

    func summary(in interval: DateInterval) -> TransactionSummary {
        if let cached = summaryCache[interval] { return cached }

        let value = TransactionAnalytics.summary(
            occurrences: occurrences(in: interval),
            elapsedDayCount: DateRangeCalculator.elapsedDayCount(for: interval, calendar: calendar)
        )
        summaryCache[interval] = value
        return value
    }

    func categorySpending(
        in interval: DateInterval,
        type: TransactionType = .expense
    ) -> [CategorySpending] {
        let key = CategoryCacheKey(interval: interval, type: type)
        if let cached = categorySpendCache[key] { return cached }

        let value = TransactionAnalytics.categorySpending(
            from: occurrences(in: interval),
            categories: categories,
            type: type
        )
        categorySpendCache[key] = value
        return value
    }

    func dailySpend(in interval: DateInterval) -> [DailySpendPoint] {
        TransactionAnalytics.dailySpend(
            occurrences: occurrences(in: interval),
            in: interval,
            calendar: calendar
        )
    }

    func sections(in interval: DateInterval, filter: TransactionFilter) -> [DailyTransactionSection] {
        let filtered = apply(filter: filter, to: occurrences(in: interval))
        return TransactionAnalytics.groupedByDay(filtered, calendar: calendar)
    }

    func monthsOverview(for year: Int) -> [MonthOverviewItem] {
        if let cached = yearCache[year] { return cached }

        let items = (1...12).map { month -> MonthOverviewItem in
            let anchor = DateRangeCalculator.monthAnchor(
                year: year,
                month: month,
                monthStartDay: state.settings.monthStartDay,
                calendar: calendar
            )
            let interval = DateRangeCalculator.period(
                for: anchor,
                monthStartDay: state.settings.monthStartDay,
                calendar: calendar
            )
            let periodSummary = summary(in: interval)
            return MonthOverviewItem(
                month: month,
                year: year,
                interval: interval,
                income: periodSummary.income,
                expense: periodSummary.expense
            )
        }

        yearCache[year] = items
        return items
    }

    func series(for id: UUID?) -> RecurringSeries? {
        guard let id else { return nil }
        return state.series(id: id)
    }

    var hasAnyData: Bool { !state.isEmpty }
    var hasAnythingAtAll: Bool { state.hasAnythingAtAll }

    var featuredTransactionCount: Int {
        state.transactions.filter(\.isFeatured).count
    }

    // MARK: - Transactions

    @discardableResult
    func addTransaction(_ draft: TransactionDraft) -> UUID? {
        if draft.recurrenceRule.repeats {
            let series = RecurringSeries(
                amount: draft.amount,
                note: draft.note,
                categoryID: draft.categoryID,
                type: draft.type,
                startDate: draft.date,
                rule: draft.recurrenceRule,
                endDate: draft.recurrenceEndDate,
                materializedThrough: nil
            )
            state.recurringSeries.append(series)
            mutated()
            materializeDueOccurrences()
            return series.id
        }

        let transaction = Transaction(
            amount: draft.amount,
            note: draft.note,
            categoryID: draft.categoryID,
            type: draft.type,
            date: draft.date,
            isFeatured: draft.isFeatured,
            attachments: draft.attachments
        )
        state.transactions.append(transaction)
        mutated()
        return transaction.id
    }

    /// Applies an edit to one row, honouring how much of a series it should affect.
    func updateOccurrence(
        _ occurrence: TransactionOccurrence,
        draft: TransactionDraft,
        scope: RecurrenceEditScope
    ) {
        guard occurrence.isRecurring else {
            if let id = occurrence.transactionID {
                updatePlainTransaction(id: id, draft: draft)
            }
            return
        }

        switch scope {
        case .thisOccurrenceOnly:
            if let id = occurrence.transactionID {
                updatePlainTransaction(id: id, draft: draft, keepSeriesLink: true)
            } else if let seriesID = occurrence.seriesID {
                skipDay(occurrence.date, inSeries: seriesID)
                state.transactions.append(
                    Transaction(
                        amount: draft.amount,
                        note: draft.note,
                        categoryID: draft.categoryID,
                        type: draft.type,
                        date: draft.date,
                        seriesID: seriesID,
                        isFeatured: draft.isFeatured,
                        attachments: draft.attachments
                    )
                )
                mutated()
            }

        case .thisAndFutureOccurrences:
            guard let seriesID = occurrence.seriesID else { return }
            splitSeries(seriesID, at: occurrence.date, using: draft, replacing: occurrence)
        }
    }

    func deleteOccurrence(_ occurrence: TransactionOccurrence, scope: RecurrenceDeleteScope) {
        guard occurrence.isRecurring, let seriesID = occurrence.seriesID else {
            if let id = occurrence.transactionID {
                removeTransactions { $0.id == id }
                mutated()
            }
            return
        }

        switch scope {
        case .thisOccurrenceOnly:
            if let id = occurrence.transactionID {
                removeTransactions { $0.id == id }
            }
            skipDay(occurrence.date, inSeries: seriesID)
            mutated()

        case .thisAndFutureOccurrences:
            let day = calendar.startOfDay(for: occurrence.date)
            if let index = indexOfSeries(seriesID) {
                state.recurringSeries[index].endDate = calendar.date(byAdding: .day, value: -1, to: day) ?? day
                state.recurringSeries[index].updatedAt = Date()
            }
            removeTransactions {
                $0.seriesID == seriesID && self.calendar.startOfDay(for: $0.date) >= day
            }
            mutated()

        case .entireSeriesIncludingHistory:
            state.recurringSeries.removeAll { $0.id == seriesID }
            removeTransactions { $0.seriesID == seriesID }
            mutated()
        }
    }

    /// Bookmarks an entry as a bill worth finding again.
    func toggleFeatured(_ occurrence: TransactionOccurrence) {
        guard let id = occurrence.transactionID,
              let index = state.transactions.firstIndex(where: { $0.id == id }) else {
            return
        }
        state.transactions[index].isFeatured.toggle()
        state.transactions[index].updatedAt = Date()
        mutated()
    }

    func transaction(id: UUID?) -> Transaction? {
        guard let id else { return nil }
        return state.transactions.first { $0.id == id }
    }

    private func updatePlainTransaction(
        id: UUID,
        draft: TransactionDraft,
        keepSeriesLink: Bool = false
    ) {
        guard let index = state.transactions.firstIndex(where: { $0.id == id }) else { return }

        var updated = state.transactions[index]
        let removedAttachments = updated.attachments.filter { existing in
            !draft.attachments.contains { $0.id == existing.id }
        }

        updated.amount = draft.amount
        updated.note = draft.note
        updated.categoryID = draft.categoryID
        updated.type = draft.type
        updated.date = draft.date
        updated.isFeatured = draft.isFeatured
        updated.attachments = draft.attachments
        updated.updatedAt = Date()
        if !keepSeriesLink {
            updated.seriesID = nil
        }
        // One assignment, so one change notification instead of seven.
        state.transactions[index] = updated

        AttachmentStore.delete(removedAttachments)
        mutated()
    }

    /// Ends the old series the day before `date` and starts a new one carrying
    /// the edited values, so past rows keep what actually happened.
    private func splitSeries(
        _ seriesID: UUID,
        at date: Date,
        using draft: TransactionDraft,
        replacing occurrence: TransactionOccurrence
    ) {
        guard let index = indexOfSeries(seriesID) else { return }

        let day = calendar.startOfDay(for: date)
        let original = state.recurringSeries[index]

        state.recurringSeries[index].endDate = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        state.recurringSeries[index].updatedAt = Date()

        let rule = draft.recurrenceRule.repeats ? draft.recurrenceRule : original.rule
        let replacement = RecurringSeries(
            amount: draft.amount,
            note: draft.note,
            categoryID: draft.categoryID,
            type: draft.type,
            startDate: draft.date,
            rule: rule,
            endDate: draft.recurrenceEndDate ?? original.endDate,
            isPaused: original.isPaused,
            skippedDays: original.skippedDays.filter { $0 >= day },
            materializedThrough: calendar.date(byAdding: .day, value: -1, to: day)
        )
        state.recurringSeries.append(replacement)

        removeTransactions {
            $0.seriesID == seriesID && self.calendar.startOfDay(for: $0.date) >= day
        }

        if occurrence.transactionID != nil || day <= materializationBoundary {
            state.transactions.append(
                Transaction(
                    amount: draft.amount,
                    note: draft.note,
                    categoryID: draft.categoryID,
                    type: draft.type,
                    date: draft.date,
                    seriesID: replacement.id,
                    isFeatured: draft.isFeatured,
                    attachments: draft.attachments
                )
            )
        }

        mutated()
        materializeDueOccurrences()
    }

    // MARK: - Savings goals

    var activeSavingsGoals: [SavingsGoalProgress] {
        state.savingsGoals
            .filter { !$0.isCompleted }
            .map(progress(for:))
            .sorted { lhs, rhs in
                switch (lhs.goal.dueDate, rhs.goal.dueDate) {
                case let (left?, right?): return left < right
                case (nil, _?): return false
                case (_?, nil): return true
                default: return lhs.goal.createdAt < rhs.goal.createdAt
                }
            }
    }

    var completedSavingsGoals: [SavingsGoalProgress] {
        state.savingsGoals
            .filter(\.isCompleted)
            .map(progress(for:))
            .sorted { ($0.goal.completedAt ?? .distantPast) > ($1.goal.completedAt ?? .distantPast) }
    }

    func progress(for goal: SavingsGoal) -> SavingsGoalProgress {
        let linked = state.transactions.filter { $0.savingsGoalID == goal.id }
        let contributed = linked.reduce(Decimal.zero) { $0 + $1.amount }
        return SavingsGoalProgress(
            goal: goal,
            savedAmount: goal.openingAmount + contributed,
            contributionCount: linked.count
        )
    }

    /// The contribution log: the linked ledger entries, newest first.
    func contributions(for goal: SavingsGoal) -> [Transaction] {
        state.transactions
            .filter { $0.savingsGoalID == goal.id }
            .sorted { $0.date > $1.date }
    }

    @discardableResult
    func addSavingsGoal(
        name: String,
        targetAmount: Decimal,
        openingAmount: Decimal,
        dueDate: Date?,
        note: String
    ) -> SavingsGoal? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, targetAmount > 0 else { return nil }

        let goal = SavingsGoal(
            name: trimmed,
            targetAmount: targetAmount,
            openingAmount: max(openingAmount, 0),
            dueDate: dueDate,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        state.savingsGoals.append(goal)
        mutated()
        return goal
    }

    func updateSavingsGoal(_ goal: SavingsGoal) {
        guard let index = state.savingsGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        var updated = goal
        updated.updatedAt = Date()
        state.savingsGoals[index] = updated
        refreshGoalCompletion()
        mutated()
    }

    /// Removes the goal but keeps its entries: the money really did leave the
    /// account, so the expenses stay and simply stop being linked.
    func deleteSavingsGoal(id: UUID) {
        state.savingsGoals.removeAll { $0.id == id }
        for index in state.transactions.indices where state.transactions[index].savingsGoalID == id {
            state.transactions[index].savingsGoalID = nil
        }
        mutated()
    }

    /// Records money put aside. Per the chosen behaviour this is a real expense
    /// in the Savings category, so Left Amount reflects it.
    func contribute(to goal: SavingsGoal, amount: Decimal, date: Date, note: String) {
        guard amount > 0 else { return }

        state.transactions.append(
            Transaction(
                amount: amount,
                note: note.isEmpty ? goal.name : note,
                categoryID: DefaultCategories.savingsCategoryID,
                type: .expense,
                date: date,
                savingsGoalID: goal.id
            )
        )
        refreshGoalCompletion()
        mutated()
    }

    func setSavingsGoalCompleted(id: UUID, completed: Bool) {
        guard let index = state.savingsGoals.firstIndex(where: { $0.id == id }) else { return }
        state.savingsGoals[index].completedAt = completed ? Date() : nil
        state.savingsGoals[index].updatedAt = Date()
        mutated()
    }

    /// Marks a goal finished as soon as it is funded, which is what feeds the
    /// completed list.
    private func refreshGoalCompletion() {
        for index in state.savingsGoals.indices {
            let goal = state.savingsGoals[index]
            guard !goal.isCompleted else { continue }
            if progress(for: goal).isReached {
                state.savingsGoals[index].completedAt = Date()
            }
        }
    }

    // MARK: - Loans

    var activeLoans: [LoanProgress] {
        state.loans
            .filter { !$0.isClosed }
            .map(progress(for:))
            .sorted { lhs, rhs in
                switch (lhs.loan.dueDate, rhs.loan.dueDate) {
                case let (left?, right?): return left < right
                case (nil, _?): return false
                case (_?, nil): return true
                default: return lhs.loan.createdAt < rhs.loan.createdAt
                }
            }
    }

    var closedLoans: [LoanProgress] {
        state.loans
            .filter(\.isClosed)
            .map(progress(for:))
            .sorted { ($0.loan.closedAt ?? .distantPast) > ($1.loan.closedAt ?? .distantPast) }
    }

    func progress(for loan: Loan) -> LoanProgress {
        let linked = state.transactions.filter { $0.loanID == loan.id }
        let paid = linked.reduce(Decimal.zero) { $0 + $1.amount }
        return LoanProgress(
            loan: loan,
            paidAmount: loan.openingPaidAmount + paid,
            paymentCount: linked.count
        )
    }

    func payments(for loan: Loan) -> [Transaction] {
        state.transactions
            .filter { $0.loanID == loan.id }
            .sorted { $0.date > $1.date }
    }

    @discardableResult
    func addLoan(
        name: String,
        initialAmount: Decimal,
        openingPaidAmount: Decimal,
        monthlyPayment: Decimal?,
        startDate: Date,
        dueDate: Date?,
        note: String
    ) -> Loan? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, initialAmount > 0 else { return nil }

        let loan = Loan(
            name: trimmed,
            initialAmount: initialAmount,
            openingPaidAmount: max(openingPaidAmount, 0),
            monthlyPayment: monthlyPayment,
            startDate: startDate,
            dueDate: dueDate,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        state.loans.append(loan)
        mutated()
        return loan
    }

    func updateLoan(_ loan: Loan) {
        guard let index = state.loans.firstIndex(where: { $0.id == loan.id }) else { return }
        var updated = loan
        updated.updatedAt = Date()
        state.loans[index] = updated
        refreshLoanClosure()
        mutated()
    }

    func deleteLoan(id: UUID) {
        state.loans.removeAll { $0.id == id }
        for index in state.transactions.indices where state.transactions[index].loanID == id {
            state.transactions[index].loanID = nil
        }
        mutated()
    }

    func recordPayment(on loan: Loan, amount: Decimal, date: Date, note: String) {
        guard amount > 0 else { return }

        state.transactions.append(
            Transaction(
                amount: amount,
                note: note.isEmpty ? loan.name : note,
                categoryID: DefaultCategories.loanCategoryID,
                type: .expense,
                date: date,
                loanID: loan.id
            )
        )
        refreshLoanClosure()
        mutated()
    }

    func setLoanClosed(id: UUID, closed: Bool) {
        guard let index = state.loans.firstIndex(where: { $0.id == id }) else { return }
        state.loans[index].closedAt = closed ? Date() : nil
        state.loans[index].updatedAt = Date()
        mutated()
    }

    private func refreshLoanClosure() {
        for index in state.loans.indices {
            let loan = state.loans[index]
            guard !loan.isClosed else { continue }
            if progress(for: loan).isSettled {
                state.loans[index].closedAt = Date()
            }
        }
    }

    // MARK: - Series controls

    func setSeriesPaused(_ seriesID: UUID, paused: Bool) {
        guard let index = indexOfSeries(seriesID) else { return }
        state.recurringSeries[index].isPaused = paused
        // Move the watermark forward so unpausing does not backfill the gap.
        state.recurringSeries[index].materializedThrough = materializationBoundary
        state.recurringSeries[index].updatedAt = Date()
        mutated()
    }

    func setSeriesEndDate(_ seriesID: UUID, endDate: Date?) {
        guard let index = indexOfSeries(seriesID) else { return }
        state.recurringSeries[index].endDate = endDate.map { calendar.startOfDay(for: $0) }
        state.recurringSeries[index].updatedAt = Date()
        mutated()
    }

    private func skipDay(_ date: Date, inSeries seriesID: UUID) {
        guard let index = indexOfSeries(seriesID) else { return }
        state.recurringSeries[index].skippedDays.insert(calendar.startOfDay(for: date))
        state.recurringSeries[index].updatedAt = Date()
    }

    private func indexOfSeries(_ id: UUID) -> Int? {
        state.recurringSeries.firstIndex { $0.id == id }
    }

    // MARK: - Materialization

    /// Turns every series date at or before today into a stored row.
    func materializeDueOccurrences() {
        guard !isPersistenceSuspended else { return }

        let boundary = materializationBoundary
        var existingKeys = Set(
            state.transactions.compactMap { transaction -> String? in
                guard let seriesID = transaction.seriesID else { return nil }
                return "\(seriesID.uuidString)-\(RecurringTransactionService.dayKey(transaction.date, calendar: calendar))"
            }
        )

        var created: [Transaction] = []
        var touched = false

        for index in state.recurringSeries.indices {
            let series = state.recurringSeries[index]
            let dates = recurringService.pendingMaterializationDates(for: series, through: boundary)

            for date in dates {
                let key = "\(series.id.uuidString)-\(RecurringTransactionService.dayKey(date, calendar: calendar))"
                guard !existingKeys.contains(key) else { continue }
                existingKeys.insert(key)
                created.append(
                    Transaction(
                        amount: series.amount,
                        note: series.note,
                        categoryID: series.categoryID,
                        type: series.type,
                        date: date,
                        seriesID: series.id
                    )
                )
            }

            if series.materializedThrough != boundary {
                state.recurringSeries[index].materializedThrough = boundary
                touched = true
            }
        }

        guard touched || !created.isEmpty else { return }
        state.transactions.append(contentsOf: created)
        mutated()
    }

    /// Deletes attachment files nothing references, e.g. after the user picked a
    /// bill photo and then cancelled the form.
    func pruneAttachmentOrphans() {
        let referenced = Set(state.transactions.flatMap { $0.attachments.map(\.fileName) })
        AttachmentStore.pruneOrphans(keeping: referenced)
    }

    // MARK: - Payment reminders

    func addReminder(_ reminder: PaymentReminder) {
        state.paymentReminders.append(reminder)
        sortReminders()
        mutated()
    }

    func updateReminder(_ reminder: PaymentReminder) {
        guard let index = state.paymentReminders.firstIndex(where: { $0.id == reminder.id }) else {
            return
        }
        var updated = reminder
        updated.updatedAt = Date()
        state.paymentReminders[index] = updated
        sortReminders()
        mutated()
    }

    func deleteReminder(id: UUID) {
        state.paymentReminders.removeAll { $0.id == id }
        mutated()
    }

    func setReminderEnabled(id: UUID, isEnabled: Bool) {
        guard let index = state.paymentReminders.firstIndex(where: { $0.id == id }) else { return }
        state.paymentReminders[index].isEnabled = isEnabled
        state.paymentReminders[index].updatedAt = Date()
        mutated()
    }

    private func sortReminders() {
        state.paymentReminders.sort { $0.fireDate < $1.fireDate }
    }

    // MARK: - Settings

    func updateSettings(
        currency: Currency? = nil,
        monthStartDay: Int? = nil,
        showsRecentCategoriesFirst: Bool? = nil
    ) {
        var settings = state.settings
        if let currency { settings.currency = currency }
        if let monthStartDay { settings.monthStartDay = monthStartDay }
        if let showsRecentCategoriesFirst {
            settings.showsRecentCategoriesFirst = showsRecentCategoriesFirst
        }
        settings.normalize()

        guard settings != state.settings else { return }
        state.settings = settings
        mutated()
    }

    // MARK: - Backup

    func exportStateData() throws -> Data {
        try persistence.exportData(from: state)
    }

    func prepareImport(from data: Data) throws -> PendingImport {
        let incoming = try persistence.decodeState(from: data)
        return PendingImport(
            state: incoming,
            incomingTransactionCount: incoming.transactions.count,
            incomingSeriesCount: incoming.recurringSeries.count,
            currentTransactionCount: state.transactions.count,
            currentSeriesCount: state.recurringSeries.count
        )
    }

    /// Replaces everything. Writes a snapshot of the current data first and
    /// returns where it went, so the user has a way back.
    @discardableResult
    func applyImport(_ pending: PendingImport) -> URL? {
        let snapshot = try? persistence.writeSnapshot(state, tag: "before-import")
        state = pending.state
        isPersistenceSuspended = false
        mutated()
        materializeDueOccurrences()
        return snapshot
    }

    func resumePersistenceWithCurrentState() {
        isPersistenceSuspended = false
        persistenceIssue = nil
        persist()
    }

    // MARK: - Filtering

    private func apply(
        filter: TransactionFilter,
        to occurrences: [TransactionOccurrence]
    ) -> [TransactionOccurrence] {
        guard filter.hasRowFilters else { return occurrences }
        let term = filter.trimmedSearchText

        return occurrences.filter { item in
            if filter.onlyFeatured, !item.isFeatured {
                return false
            }
            if let categoryID = filter.categoryID, categoryID != item.categoryID {
                return false
            }
            if let type = filter.type, type != item.type {
                return false
            }
            if !term.isEmpty {
                let matchesNote = item.note.localizedCaseInsensitiveContains(term)
                let matchesCategory = category(for: item.categoryID)
                    .localizedName
                    .localizedCaseInsensitiveContains(term)
                if !matchesNote && !matchesCategory {
                    return false
                }
            }
            return true
        }
    }

    // MARK: - Persistence plumbing

    /// Removes rows and cleans up any bill files they owned.
    private func removeTransactions(where predicate: (Transaction) -> Bool) {
        let doomed = state.transactions.filter(predicate)
        guard !doomed.isEmpty else { return }
        state.transactions.removeAll(where: predicate)
        AttachmentStore.delete(doomed.flatMap(\.attachments))
    }

    private func mutated() {
        revision += 1
        occurrenceCache.removeAll(keepingCapacity: true)
        summaryCache.removeAll(keepingCapacity: true)
        categorySpendCache.removeAll(keepingCapacity: true)
        yearCache.removeAll(keepingCapacity: true)
        state.transactions.sort { $0.date > $1.date }
        persist()
    }

    private func persist() {
        guard !isPersistenceSuspended else { return }

        do {
            try persistence.save(state)
        } catch {
            // A failed write used to be invisible in release builds, which let
            // the user keep entering data that was never stored.
            persistenceIssue = PersistenceIssue(
                title: NSLocalizedString("Changes may not be saved", comment: "Alert title"),
                message: String(
                    format: NSLocalizedString(
                        "manatik could not write to storage: %@\n\nExport a backup from Settings before closing the app.",
                        comment: "Alert message"
                    ),
                    error.localizedDescription
                ),
                backupCopy: nil,
                isBlocking: false
            )
        }
    }
}
