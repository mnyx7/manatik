import Foundation

enum TransactionType: String, Codable, CaseIterable, Identifiable, Hashable {
    case income
    case expense

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .income: return NSLocalizedString("Income", comment: "Transaction type")
        case .expense: return NSLocalizedString("Expense", comment: "Transaction type")
        }
    }
}

/// `none` is a UI-level "does not repeat" marker. A `RecurringSeries` is never
/// created with it -- see `RecurringSeries.init`.
enum RecurrenceRule: String, Codable, CaseIterable, Identifiable, Hashable {
    case none
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var repeats: Bool { self != .none }

    var calendarComponent: Calendar.Component? {
        switch self {
        case .none: return nil
        case .daily: return .day
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .yearly: return .year
        }
    }

    var localizedTitle: String {
        switch self {
        case .none: return NSLocalizedString("Never", comment: "Recurrence rule")
        case .daily: return NSLocalizedString("Daily", comment: "Recurrence rule")
        case .weekly: return NSLocalizedString("Weekly", comment: "Recurrence rule")
        case .monthly: return NSLocalizedString("Monthly", comment: "Recurrence rule")
        case .yearly: return NSLocalizedString("Yearly", comment: "Recurrence rule")
        }
    }
}

enum CategoryKind: String, Codable {
    case income
    case expense
    case both
}

struct TransactionCategory: Identifiable, Codable, Hashable {
    let id: String
    /// English source string, also the localization key.
    let name: String
    let icon: String
    let kind: CategoryKind

    var localizedName: String {
        NSLocalizedString(name, comment: "Category name")
    }
}

/// A concrete ledger entry. Either entered by hand (`seriesID == nil`) or
/// materialized from a recurring series (`seriesID != nil`). Once materialized
/// it is an independent row: editing it never touches the series or its siblings.
struct Transaction: Identifiable, Codable, Hashable {
    let id: UUID
    var amount: Decimal
    var note: String
    var categoryID: String
    var type: TransactionType
    var date: Date
    let createdAt: Date
    var updatedAt: Date
    var seriesID: UUID?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        note: String,
        categoryID: String,
        type: TransactionType,
        date: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        seriesID: UUID? = nil
    ) {
        self.id = id
        self.amount = amount
        self.note = note
        self.categoryID = categoryID
        self.type = type
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.seriesID = seriesID
    }
}

/// The definition of a repeating entry. It is not itself a ledger entry: dates
/// at or before the materialization boundary become real `Transaction` rows,
/// dates after it are shown as projections.
struct RecurringSeries: Identifiable, Codable, Hashable {
    let id: UUID
    var amount: Decimal
    var note: String
    var categoryID: String
    var type: TransactionType
    var startDate: Date
    var rule: RecurrenceRule
    var endDate: Date?
    var isPaused: Bool
    /// Days the user explicitly removed from the series, normalized to start of day.
    var skippedDays: Set<Date>
    /// Last day already turned into `Transaction` rows, normalized to start of day.
    var materializedThrough: Date?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        amount: Decimal,
        note: String,
        categoryID: String,
        type: TransactionType,
        startDate: Date,
        rule: RecurrenceRule,
        endDate: Date? = nil,
        isPaused: Bool = false,
        skippedDays: Set<Date> = [],
        materializedThrough: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.note = note
        self.categoryID = categoryID
        self.type = type
        self.startDate = startDate
        self.rule = rule.repeats ? rule : .monthly
        self.endDate = endDate
        self.isPaused = isPaused
        self.skippedDays = skippedDays
        self.materializedThrough = materializedThrough
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// One dated row as shown in the UI. Flattens concrete transactions and
/// projected series dates into a single list.
struct TransactionOccurrence: Identifiable, Hashable {
    let id: String
    /// Non-nil when this row is backed by a stored `Transaction`.
    let transactionID: UUID?
    /// Non-nil when this row came from, or was materialized by, a series.
    let seriesID: UUID?
    let amount: Decimal
    let note: String
    let categoryID: String
    let type: TransactionType
    let date: Date
    /// True when the row is a forecast rather than a recorded entry.
    let isProjected: Bool

    var isRecurring: Bool { seriesID != nil }

    /// Signed contribution to a balance: income positive, expense negative.
    var signedAmount: Decimal {
        type == .income ? amount : -amount
    }
}

struct DailyTransactionSection: Identifiable, Hashable {
    let id: String
    let title: String
    let date: Date
    let items: [TransactionOccurrence]

    var net: Decimal {
        items.reduce(Decimal.zero) { $0 + $1.signedAmount }
    }

    var containsProjection: Bool {
        items.contains(where: \.isProjected)
    }
}

/// Which rows a change to a recurring entry should affect.
enum RecurrenceEditScope: Hashable {
    case thisOccurrenceOnly
    case thisAndFutureOccurrences
}

enum RecurrenceDeleteScope: Hashable {
    case thisOccurrenceOnly
    case thisAndFutureOccurrences
    case entireSeriesIncludingHistory
}
