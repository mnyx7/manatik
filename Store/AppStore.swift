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

    let categories: [TransactionCategory]

    private let persistence: AppStatePersisting
    private let recurringService: RecurringTransactionServicing
    private let calendar: Calendar

    /// Bumped on every mutation; invalidates the derived caches below.
    private var revision = 0
    private var occurrenceCache: [DateInterval: [TransactionOccurrence]] = [:]
    private var summaryCache: [DateInterval: TransactionSummary] = [:]
    private var categoryCache: [DateInterval: [CategorySpending]] = [:]
    private var yearCache: [Int: [MonthOverviewItem]] = [:]

    init(
        persistence: AppStatePersisting = AppStatePersistence(),
        recurringService: RecurringTransactionServicing = RecurringTransactionService(),
        categories: [TransactionCategory] = DefaultCategories.all,
        calendar: Calendar = .current,
        initialState: AppState? = nil
    ) {
        self.persistence = persistence
        self.recurringService = recurringService
        self.categories = categories
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
                        "Your data was saved in an older format (version %d) and has been upgraded. Recurring entries now keep their own history.",
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

    // MARK: - Derived data (cached per revision)

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
                    isProjected: false
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

    func categorySpending(in interval: DateInterval) -> [CategorySpending] {
        if let cached = categoryCache[interval] { return cached }

        let value = TransactionAnalytics.categorySpending(
            from: occurrences(in: interval),
            categories: categories
        )
        categoryCache[interval] = value
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

    /// Whether any data exists at all, used to tell "nothing recorded" apart
    /// from "nothing matched your filter".
    var hasAnyData: Bool { !state.isEmpty }

    // MARK: - Transactions

    func addTransaction(_ draft: TransactionDraft) {
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
            return
        }

        state.transactions.append(
            Transaction(
                amount: draft.amount,
                note: draft.note,
                categoryID: draft.categoryID,
                type: draft.type,
                date: draft.date
            )
        )
        mutated()
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
                // Already a real row: edit it and leave the series alone.
                updatePlainTransaction(id: id, draft: draft, keepSeriesLink: true)
            } else if let seriesID = occurrence.seriesID {
                // A forecast: pin it down as a one-off exception.
                skipDay(occurrence.date, inSeries: seriesID)
                state.transactions.append(
                    Transaction(
                        amount: draft.amount,
                        note: draft.note,
                        categoryID: draft.categoryID,
                        type: draft.type,
                        date: draft.date,
                        seriesID: seriesID
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
                state.transactions.removeAll { $0.id == id }
                mutated()
            }
            return
        }

        switch scope {
        case .thisOccurrenceOnly:
            if let id = occurrence.transactionID {
                state.transactions.removeAll { $0.id == id }
            }
            // Record the skip either way, so materialization will not recreate it.
            skipDay(occurrence.date, inSeries: seriesID)
            mutated()

        case .thisAndFutureOccurrences:
            let day = calendar.startOfDay(for: occurrence.date)
            if let index = indexOfSeries(seriesID) {
                state.recurringSeries[index].endDate = calendar.date(byAdding: .day, value: -1, to: day) ?? day
                state.recurringSeries[index].updatedAt = Date()
            }
            state.transactions.removeAll { transaction in
                transaction.seriesID == seriesID && calendar.startOfDay(for: transaction.date) >= day
            }
            mutated()

        case .entireSeriesIncludingHistory:
            state.recurringSeries.removeAll { $0.id == seriesID }
            state.transactions.removeAll { $0.seriesID == seriesID }
            mutated()
        }
    }

    private func updatePlainTransaction(id: UUID, draft: TransactionDraft, keepSeriesLink: Bool = false) {
        guard let index = state.transactions.firstIndex(where: { $0.id == id }) else { return }

        var updated = state.transactions[index]
        updated.amount = draft.amount
        updated.note = draft.note
        updated.categoryID = draft.categoryID
        updated.type = draft.type
        updated.date = draft.date
        updated.updatedAt = Date()
        if !keepSeriesLink {
            updated.seriesID = nil
        }
        // One assignment, so one change notification instead of seven.
        state.transactions[index] = updated
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
            // Nothing from the new series is recorded yet.
            materializedThrough: calendar.date(byAdding: .day, value: -1, to: day)
        )
        state.recurringSeries.append(replacement)

        // Drop rows of the old series at or after the split, then let
        // materialization rebuild them from the new definition.
        state.transactions.removeAll { transaction in
            transaction.seriesID == seriesID && calendar.startOfDay(for: transaction.date) >= day
        }

        if occurrence.transactionID != nil || day <= materializationBoundary {
            state.transactions.append(
                Transaction(
                    amount: draft.amount,
                    note: draft.note,
                    categoryID: draft.categoryID,
                    type: draft.type,
                    date: draft.date,
                    seriesID: replacement.id
                )
            )
        }

        mutated()
        materializeDueOccurrences()
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
    ///
    /// Run at launch and whenever the app becomes active, so history stops
    /// being recomputed from the template and can no longer change under the
    /// user when they edit a future occurrence.
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
        savingsGoal: SavingsGoal? = nil
    ) {
        var settings = state.settings
        if let currency { settings.currency = currency }
        if let monthStartDay { settings.monthStartDay = monthStartDay }
        if let savingsGoal { settings.savingsGoal = savingsGoal }
        settings.normalize()

        guard settings != state.settings else { return }
        state.settings = settings
        mutated()
    }

    // MARK: - Backup

    func exportStateData() throws -> Data {
        try persistence.exportData(from: state)
    }

    /// Decodes and describes an import without applying any of it.
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

    /// After an unreadable file: accept a clean slate and allow saving again.
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
            if let categoryID = filter.categoryID, categoryID != item.categoryID {
                return false
            }
            if let type = filter.type, type != item.type {
                return false
            }
            if !term.isEmpty {
                let matchesNote = item.note.localizedCaseInsensitiveContains(term)
                let matchesCategory = DefaultCategories.name(forID: item.categoryID, matches: term)
                if !matchesNote && !matchesCategory {
                    return false
                }
            }
            return true
        }
    }

    // MARK: - Persistence plumbing

    private func mutated() {
        revision += 1
        occurrenceCache.removeAll(keepingCapacity: true)
        summaryCache.removeAll(keepingCapacity: true)
        categoryCache.removeAll(keepingCapacity: true)
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
