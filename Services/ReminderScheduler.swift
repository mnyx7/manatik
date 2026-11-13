//
//  ReminderScheduler.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import Foundation
import UserNotifications
import Observation

/// Schedules local notifications for payment reminders.
///
/// The app holds no server, so every reminder is a local notification. State on
/// disk is the source of truth: `sync` reconciles the pending notification set
/// against it rather than trying to track individual adds and removals.
@MainActor
@Observable
final class ReminderScheduler {
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var lastError: String?

    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    var needsPermissionPrompt: Bool {
        authorizationStatus == .notDetermined
    }

    var isBlockedInSystemSettings: Bool {
        authorizationStatus == .denied
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            lastError = error.localizedDescription
            await refreshAuthorizationStatus()
            return false
        }
    }

    /// Makes the pending notification set match `reminders`.
    func sync(reminders: [PaymentReminder], currency: Currency) async {
        await refreshAuthorizationStatus()

        let pending = await center.pendingNotificationRequests()
        let managedPrefix = "payment-reminder-"

        // Drop everything we own, then re-add what still applies. Cheap at this
        // scale and immune to drift between state and the notification centre.
        let ours = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(managedPrefix) }
        if !ours.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ours)
        }

        guard isAuthorized else { return }

        for reminder in reminders where reminder.isEnabled && !reminder.hasLapsed() {
            do {
                try await schedule(reminder, currency: currency)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func cancel(_ reminder: PaymentReminder) {
        center.removePendingNotificationRequests(withIdentifiers: [reminder.notificationIdentifier])
    }

    private func schedule(_ reminder: PaymentReminder, currency: Currency) async throws {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Payment due", comment: "Notification title")
        content.body = body(for: reminder, currency: currency)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: reminder.notificationIdentifier,
            content: content,
            trigger: trigger(for: reminder)
        )
        try await center.add(request)
    }

    private func body(for reminder: PaymentReminder, currency: Currency) -> String {
        let subtitle = reminder.localizedSubtitle(currency: currency)
        guard !subtitle.isEmpty else { return reminder.title }
        return "\(reminder.title) \u{00B7} \(subtitle)"
    }

    private func trigger(for reminder: PaymentReminder) -> UNNotificationTrigger {
        // Only the components the rule actually repeats on are included, which
        // is what makes a repeating calendar trigger fire on the right cadence.
        var components = DateComponents()
        let all = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .weekday],
            from: reminder.fireDate
        )
        components.hour = all.hour
        components.minute = all.minute

        switch reminder.repeatRule {
        case .daily:
            break
        case .weekly:
            components.weekday = all.weekday
        case .monthly:
            components.day = all.day
        case .yearly:
            components.month = all.month
            components.day = all.day
        case .none:
            components.year = all.year
            components.month = all.month
            components.day = all.day
        }

        return UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: reminder.repeatRule.repeats
        )
    }
}
