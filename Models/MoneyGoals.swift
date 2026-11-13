//
//  MoneyGoals.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import Foundation

// MARK: - Attachments

enum AttachmentKind: String, Codable, Hashable {
    case image
    case pdf

    var systemImage: String {
        switch self {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        }
    }
}

/// A bill photo or document kept alongside an entry.
///
/// Only the reference lives in app state; the bytes are files under
/// `Documents/Attachments`. That keeps the state file small, and it is why the
/// JSON backup cannot restore attachments on its own.
struct Attachment: Identifiable, Codable, Hashable {
    let id: UUID
    var fileName: String
    var kind: AttachmentKind
    var displayName: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        fileName: String,
        kind: AttachmentKind,
        displayName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.kind = kind
        self.displayName = displayName
        self.createdAt = createdAt
    }
}

// MARK: - Savings goals

/// A named savings target.
///
/// The amount saved is derived from the linked ledger entries plus
/// `openingAmount`, so there is exactly one place a figure can come from. Money
/// already put aside before using the app goes in `openingAmount` rather than
/// being invented as a past expense.
struct SavingsGoal: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var targetAmount: Decimal
    var openingAmount: Decimal
    var dueDate: Date?
    var note: String
    var completedAt: Date?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Decimal,
        openingAmount: Decimal = 0,
        dueDate: Date? = nil,
        note: String = "",
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.openingAmount = openingAmount
        self.dueDate = dueDate
        self.note = note
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isCompleted: Bool { completedAt != nil }

    enum CodingKeys: String, CodingKey {
        case id, name, targetAmount, openingAmount, dueDate, note, completedAt, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        targetAmount = try container.decode(Decimal.self, forKey: .targetAmount)
        openingAmount = try container.decodeIfPresent(Decimal.self, forKey: .openingAmount) ?? 0
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

/// A goal with its derived figures resolved, ready to render.
struct SavingsGoalProgress: Identifiable, Hashable {
    let goal: SavingsGoal
    let savedAmount: Decimal
    let contributionCount: Int

    var id: UUID { goal.id }

    var remainingAmount: Decimal {
        max(goal.targetAmount - savedAmount, 0)
    }

    var isReached: Bool {
        goal.targetAmount > 0 && savedAmount >= goal.targetAmount
    }

    var fraction: Double {
        guard goal.targetAmount > 0 else { return 0 }
        let value = NSDecimalNumber(decimal: savedAmount).doubleValue
            / NSDecimalNumber(decimal: goal.targetAmount).doubleValue
        return min(max(value, 0), 1)
    }

    var daysRemaining: Int? {
        guard let dueDate = goal.dueDate else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: dueDate)
        ).day
        return days
    }
}

// MARK: - Loans

/// A debt being paid down.
///
/// `openingPaidAmount` covers the common case of adding a loan that was already
/// part-paid before the app existed, without fabricating past expenses.
struct Loan: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var initialAmount: Decimal
    var openingPaidAmount: Decimal
    var monthlyPayment: Decimal?
    var startDate: Date
    var dueDate: Date?
    var note: String
    var closedAt: Date?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        initialAmount: Decimal,
        openingPaidAmount: Decimal = 0,
        monthlyPayment: Decimal? = nil,
        startDate: Date = Date(),
        dueDate: Date? = nil,
        note: String = "",
        closedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.initialAmount = initialAmount
        self.openingPaidAmount = openingPaidAmount
        self.monthlyPayment = monthlyPayment
        self.startDate = startDate
        self.dueDate = dueDate
        self.note = note
        self.closedAt = closedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isClosed: Bool { closedAt != nil }

    enum CodingKeys: String, CodingKey {
        case id, name, initialAmount, openingPaidAmount, monthlyPayment
        case startDate, dueDate, note, closedAt, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        initialAmount = try container.decode(Decimal.self, forKey: .initialAmount)
        openingPaidAmount = try container.decodeIfPresent(Decimal.self, forKey: .openingPaidAmount) ?? 0
        monthlyPayment = try container.decodeIfPresent(Decimal.self, forKey: .monthlyPayment)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

struct LoanProgress: Identifiable, Hashable {
    let loan: Loan
    let paidAmount: Decimal
    let paymentCount: Int

    var id: UUID { loan.id }

    var remainingAmount: Decimal {
        max(loan.initialAmount - paidAmount, 0)
    }

    var isSettled: Bool {
        loan.initialAmount > 0 && paidAmount >= loan.initialAmount
    }

    var fraction: Double {
        guard loan.initialAmount > 0 else { return 0 }
        let value = NSDecimalNumber(decimal: paidAmount).doubleValue
            / NSDecimalNumber(decimal: loan.initialAmount).doubleValue
        return min(max(value, 0), 1)
    }

    /// Whole instalments left at the stated monthly payment, when there is one.
    var estimatedPaymentsRemaining: Int? {
        guard let monthly = loan.monthlyPayment, monthly > 0, remainingAmount > 0 else { return nil }
        let value = NSDecimalNumber(decimal: remainingAmount).doubleValue
            / NSDecimalNumber(decimal: monthly).doubleValue
        return Int(value.rounded(.up))
    }
}
