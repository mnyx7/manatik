//
//  TransactionModels.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import Foundation

enum TransactionType: String, Codable, CaseIterable, Identifiable, Hashable {
    case income
    case expense

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .income: return AppLocalization.string("Income", comment: "Transaction type")
        case .expense: return AppLocalization.string("Expense", comment: "Transaction type")
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
        case .none: return AppLocalization.string("Never", comment: "Recurrence rule")
        case .daily: return AppLocalization.string("Daily", comment: "Recurrence rule")
        case .weekly: return AppLocalization.string("Weekly", comment: "Recurrence rule")
        case .monthly: return AppLocalization.string("Monthly", comment: "Recurrence rule")
        case .yearly: return AppLocalization.string("Yearly", comment: "Recurrence rule")
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
    /// For built-in categories this is the English source string and doubles as
    /// the localization key. For user-made ones it is literal text.
    let name: String
    let icon: String
    let kind: CategoryKind
    var isCustom: Bool

    init(id: String, name: String, icon: String, kind: CategoryKind, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.kind = kind
        self.isCustom = isCustom
    }

    var localizedName: String {
        isCustom ? name : AppLocalization.string(name, comment: "Category name")
    }

    enum CodingKeys: String, CodingKey {
        case id, name, icon, kind, isCustom
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        kind = try container.decode(CategoryKind.self, forKey: .kind)
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? true
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

    /// Bookmarked by the user as a bill worth finding again.
    var isFeatured: Bool
    var attachments: [Attachment]
    /// Set when this entry is money put into a savings goal.
    var savingsGoalID: UUID?
    /// Set when this entry is a payment against a loan.
    var loanID: UUID?
    /// The currency the amount was entered in. Nil only in files written
    /// before entries had their own currency; the store fills it in on load.
    var currency: Currency?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        note: String,
        categoryID: String,
        type: TransactionType,
        date: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        seriesID: UUID? = nil,
        isFeatured: Bool = false,
        attachments: [Attachment] = [],
        savingsGoalID: UUID? = nil,
        loanID: UUID? = nil,
        currency: Currency? = nil
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
        self.isFeatured = isFeatured
        self.attachments = attachments
        self.savingsGoalID = savingsGoalID
        self.loanID = loanID
        self.currency = currency
    }

    var isSavingsContribution: Bool { savingsGoalID != nil }
    var isLoanPayment: Bool { loanID != nil }
    var hasAttachments: Bool { !attachments.isEmpty }

    enum CodingKeys: String, CodingKey {
        case id, amount, note, categoryID, type, date, createdAt, updatedAt, seriesID
        case isFeatured, attachments, savingsGoalID, loanID, currency
    }

    /// New fields decode permissively so files written by earlier versions keep
    /// loading instead of failing and looking like lost data.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        amount = try container.decode(Decimal.self, forKey: .amount)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        categoryID = try container.decode(String.self, forKey: .categoryID)
        type = try container.decode(TransactionType.self, forKey: .type)
        date = try container.decode(Date.self, forKey: .date)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        seriesID = try container.decodeIfPresent(UUID.self, forKey: .seriesID)
        isFeatured = try container.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        savingsGoalID = try container.decodeIfPresent(UUID.self, forKey: .savingsGoalID)
        loanID = try container.decodeIfPresent(UUID.self, forKey: .loanID)
        // A malformed code leaves the entry in the default currency rather
        // than failing the whole file.
        currency = (try? container.decodeIfPresent(Currency.self, forKey: .currency)) ?? nil
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
    /// See `Transaction.currency`; every row the series creates inherits it.
    var currency: Currency?

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
        updatedAt: Date = Date(),
        currency: Currency? = nil
    ) {
        self.currency = currency
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
    let isFeatured: Bool
    let attachmentCount: Int
    let savingsGoalID: UUID?
    let loanID: UUID?
    /// Nil means the default currency from Settings.
    let currency: Currency?

    init(
        id: String,
        transactionID: UUID?,
        seriesID: UUID?,
        amount: Decimal,
        note: String,
        categoryID: String,
        type: TransactionType,
        date: Date,
        isProjected: Bool,
        isFeatured: Bool = false,
        attachmentCount: Int = 0,
        savingsGoalID: UUID? = nil,
        loanID: UUID? = nil,
        currency: Currency? = nil
    ) {
        self.currency = currency
        self.id = id
        self.transactionID = transactionID
        self.seriesID = seriesID
        self.amount = amount
        self.note = note
        self.categoryID = categoryID
        self.type = type
        self.date = date
        self.isProjected = isProjected
        self.isFeatured = isFeatured
        self.attachmentCount = attachmentCount
        self.savingsGoalID = savingsGoalID
        self.loanID = loanID
    }

    var isRecurring: Bool { seriesID != nil }
    var hasAttachments: Bool { attachmentCount > 0 }
    var isSavingsContribution: Bool { savingsGoalID != nil }
    var isLoanPayment: Bool { loanID != nil }

    /// Linked rows are managed from their goal or loan, not edited freehand.
    var isLinkedToGoalOrLoan: Bool { isSavingsContribution || isLoanPayment }

    /// Signed contribution to a balance: income positive, expense negative.
    var signedAmount: Decimal {
        type == .income ? amount : -amount
    }

    func isIn(_ main: Currency) -> Bool {
        (currency ?? main) == main
    }
}

/// Which slice of the ledger the Activities screen is showing.
enum ActivityScope: String, CaseIterable, Identifiable, Hashable {
    case all
    case income
    case expense
    case bills

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .all: return AppLocalization.string("All", comment: "Activity scope")
        case .income: return AppLocalization.string("Income", comment: "Activity scope")
        case .expense: return AppLocalization.string("Expense", comment: "Activity scope")
        case .bills: return AppLocalization.string("Bills", comment: "Activity scope")
        }
    }

    var transactionType: TransactionType? {
        switch self {
        case .income: return .income
        case .expense: return .expense
        case .all, .bills: return nil
        }
    }

    var onlyFeatured: Bool { self == .bills }
}

struct DailyTransactionSection: Identifiable, Hashable {
    let id: String
    let title: String
    let date: Date
    let items: [TransactionOccurrence]

    /// Only entries in `currency` count; amounts are never converted.
    func net(in currency: Currency) -> Decimal {
        items.filter { $0.isIn(currency) }.reduce(Decimal.zero) { $0 + $1.signedAmount }
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
