//
//  PaymentReminder.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import Foundation

/// A scheduled nudge about money going out: a loan instalment, a utility bill,
/// a subscription. Independent of recurring entries, because a reminder is
/// about being told in advance, not about recording a figure.
struct PaymentReminder: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    /// Optional expected amount, shown in the notification when present.
    var amount: Decimal?
    var categoryID: String?
    /// Date and time of the next reminder.
    var fireDate: Date
    /// `.none` means remind once, then stop.
    var repeatRule: RecurrenceRule
    var isEnabled: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal? = nil,
        categoryID: String? = nil,
        fireDate: Date,
        repeatRule: RecurrenceRule = .monthly,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.categoryID = categoryID
        self.fireDate = fireDate
        self.repeatRule = repeatRule
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var repeatsForever: Bool { repeatRule.repeats }

    /// True once a one-shot reminder's moment has passed.
    func hasLapsed(now: Date = Date()) -> Bool {
        !repeatsForever && fireDate < now
    }

    var notificationIdentifier: String { "payment-reminder-\(id.uuidString)" }

    func localizedSubtitle(currency: Currency) -> String {
        if let amount {
            return CurrencyFormatting.format(amount: amount, currency: currency)
        }
        if let categoryID {
            return DefaultCategories.category(for: categoryID).localizedName
        }
        return ""
    }
}
