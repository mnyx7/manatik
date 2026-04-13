import Foundation

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income
    case expense

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum RecurrenceRule: String, Codable, CaseIterable, Identifiable {
    case none
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
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
    let name: String
    let icon: String
    let kind: CategoryKind
}

struct Transaction: Identifiable, Codable, Hashable {
    let id: UUID
    var amount: Double
    var note: String
    var categoryID: String
    var type: TransactionType
    var date: Date
    let createdAt: Date
    var updatedAt: Date
    var recurrenceRule: RecurrenceRule?

    init(
        id: UUID = UUID(),
        amount: Double,
        note: String,
        categoryID: String,
        type: TransactionType,
        date: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        recurrenceRule: RecurrenceRule? = RecurrenceRule.none
    ) {
        self.id = id
        self.amount = amount
        self.note = note
        self.categoryID = categoryID
        self.type = type
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.recurrenceRule = recurrenceRule
    }
}

struct TransactionOccurrence: Identifiable, Hashable {
    let id: String
    let sourceTransaction: Transaction
    let date: Date
    let isGenerated: Bool

    var amount: Double { sourceTransaction.amount }
    var type: TransactionType { sourceTransaction.type }
    var note: String { sourceTransaction.note }
    var categoryID: String { sourceTransaction.categoryID }
    var transactionID: UUID { sourceTransaction.id }
}

struct DailyTransactionSection: Identifiable {
    let id: String
    let title: String
    let date: Date
    let items: [TransactionOccurrence]
}
