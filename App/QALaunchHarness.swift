//
//  QALaunchHarness.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

#if DEBUG
import Foundation
import UIKit

/// Launch-argument hooks used to drive the app for screenshot QA, so every
/// screen can be opened and captured without tapping through the simulator.
///
/// DEBUG only, and inert unless `-qa-seed` is passed, so a normal Debug run
/// still loads the real file from Documents.
///
/// Usage:
///   xcrun simctl launch <device> com.minayayagubova.manatik \
///       -qa-seed -qa-tab overview -qa-route savings
enum QALaunch {
    private static var arguments: [String] { CommandLine.arguments }

    /// Replace the on-disk store with in-memory demo data.
    static var isSeeding: Bool { arguments.contains("-qa-seed") }

    /// Which tab to open on: home (default), activities, settings, overview.
    static var tab: String? { value(for: "-qa-tab") }

    /// A screen to push or present on top: savings, loans, year, goal, loan,
    /// add, category.
    static var route: String? { value(for: "-qa-route") }

    /// A home page style to show, by `HomeStyle` raw value, e.g. posterGirl.
    static var homeStyle: HomeStyle? { value(for: "-qa-home").flatMap(HomeStyle.init(rawValue:)) }

    static func value(for flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.index(after: index) < arguments.endIndex else { return nil }
        let next = arguments[arguments.index(after: index)]
        return next.hasPrefix("-") ? nil : next
    }

    // Fixed ids so `-qa-route goal` always opens the same demo goal.
    static let goalID = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
    static let secondGoalID = UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!
    static let loanID = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
    static let secondLoanID = UUID(uuidString: "00000000-0000-0000-0000-00000000B002")!
    static let billTransactionID = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!

    /// Draws a receipt-looking image and stores it like a picked photo.
    private static func demoBillAttachment() -> Attachment? {
        let size = CGSize(width: 600, height: 840)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let title: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 44),
                .foregroundColor: UIColor.black
            ]
            let line: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 26, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            ("Azərişıq" as NSString).draw(at: CGPoint(x: 40, y: 50), withAttributes: title)
            let rows = ["Account  0012 4471", "Period   October", "Usage    412 kWh", "", "TOTAL    60.00 ₼"]
            for (offset, text) in rows.enumerated() {
                (text as NSString).draw(
                    at: CGPoint(x: 40, y: 160 + CGFloat(offset) * 48),
                    withAttributes: line
                )
            }
        }
        return try? AttachmentStore.store(image: image, displayName: "Electricity bill")
    }

    /// A believable month: salary and rent as series, a spread of everyday
    /// spending, two goals, two loans and a reminder.
    static func demoState(calendar: Calendar = .current) -> AppState {
        let now = Date()
        func daysAgo(_ value: Int) -> Date {
            calendar.date(byAdding: .day, value: -value, to: now) ?? now
        }
        func daysAhead(_ value: Int) -> Date {
            calendar.date(byAdding: .day, value: value, to: now) ?? now
        }
        func money(_ text: String) -> Decimal {
            Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? .zero
        }

        let salary = RecurringSeries(
            amount: money("3200"),
            note: "Monthly salary",
            categoryID: "salary",
            type: .income,
            startDate: daysAgo(70),
            rule: .monthly
        )

        let rent = RecurringSeries(
            amount: money("900"),
            note: "Apartment rent",
            categoryID: "rent",
            type: .expense,
            startDate: daysAgo(68),
            rule: .monthly
        )

        let netflix = RecurringSeries(
            amount: money("12.99"),
            note: "Streaming",
            categoryID: "subscription",
            type: .expense,
            startDate: daysAgo(64),
            rule: .monthly
        )

        let spending: [(String, String, String, Int, Bool)] = [
            ("84.50", "Weekly groceries", "groceries", 1, false),
            ("4.20", "Morning coffee", "cafe", 1, false),
            ("22.00", "Metro top-up", "transport", 2, false),
            ("156.30", "Winter jacket", "shopping", 3, false),
            ("48.00", "Dinner with Leyla", "restaurant", 4, false),
            ("31.75", "Pharmacy", "pharmacy", 5, true),
            ("12.40", "Bus card", "transport", 6, false),
            ("96.10", "Big shop", "groceries", 8, false),
            ("60.00", "Electricity", "utility", 9, true),
            ("18.90", "Cinema", "entertainment", 11, false),
            ("240.00", "Flight to Tbilisi", "travel", 13, false),
            ("7.60", "Coffee and cake", "cafe", 14, false),
            ("35.00", "Petrol", "fuel", 16, false),
            ("120.00", "Birthday gift", "gift", 18, false),
            ("29.99", "Course", "education", 21, false)
        ]

        var transactions = spending.map { amount, note, category, days, featured in
            Transaction(
                id: note == "Electricity" ? billTransactionID : UUID(),
                amount: money(amount),
                note: note,
                categoryID: category,
                type: .expense,
                date: daysAgo(days),
                isFeatured: featured
            )
        }

        // A real file on the Electricity bill, so `-qa-route bill` has
        // something to show.
        if let index = transactions.firstIndex(where: { $0.id == billTransactionID }),
           let bill = demoBillAttachment() {
            transactions[index].attachments = [bill]
        }

        transactions.append(
            Transaction(
                amount: money("450"),
                note: "Side project",
                categoryID: "freelance",
                type: .income,
                date: daysAgo(7)
            )
        )

        // Paid abroad, so the other-currency line and row have something to show.
        transactions.append(
            Transaction(
                amount: money("38"),
                note: "Hotel, Tbilisi",
                categoryID: "travel",
                type: .expense,
                date: daysAgo(0),
                currency: .usd
            )
        )

        // Linked rows: the goal and loan figures derive from these.
        transactions.append(
            Transaction(
                amount: money("200"),
                note: "",
                categoryID: DefaultCategories.savingsCategoryID,
                type: .expense,
                date: daysAgo(10),
                savingsGoalID: goalID
            )
        )
        transactions.append(
            Transaction(
                amount: money("150"),
                note: "",
                categoryID: DefaultCategories.savingsCategoryID,
                type: .expense,
                date: daysAgo(3),
                savingsGoalID: goalID
            )
        )
        transactions.append(
            Transaction(
                amount: money("300"),
                note: "",
                categoryID: DefaultCategories.loanCategoryID,
                type: .expense,
                date: daysAgo(12),
                loanID: loanID
            )
        )

        let goals = [
            SavingsGoal(
                id: goalID,
                name: "Trip to Japan",
                targetAmount: money("4000"),
                openingAmount: money("650"),
                dueDate: daysAhead(210),
                note: "Flights first, then the rail pass."
            ),
            SavingsGoal(
                id: secondGoalID,
                name: "New laptop",
                targetAmount: money("2200"),
                openingAmount: money("1900"),
                dueDate: daysAhead(45)
            )
        ]

        let loans = [
            Loan(
                id: loanID,
                name: "Car loan",
                initialAmount: money("12000"),
                openingPaidAmount: money("4500"),
                monthlyPayment: money("300"),
                startDate: daysAgo(400),
                dueDate: daysAhead(700)
            ),
            Loan(
                id: secondLoanID,
                name: "Phone instalments",
                initialAmount: money("1400"),
                openingPaidAmount: money("1250"),
                monthlyPayment: money("150"),
                startDate: daysAgo(280),
                dueDate: daysAhead(30)
            )
        ]

        let reminders = [
            PaymentReminder(
                title: "Car loan instalment",
                amount: money("300"),
                categoryID: "loan",
                fireDate: daysAhead(4),
                repeatRule: .monthly
            ),
            PaymentReminder(
                title: "Internet bill",
                amount: money("28"),
                categoryID: "utility",
                fireDate: daysAhead(9),
                repeatRule: .monthly,
                isEnabled: false
            )
        ]

        return AppState(
            transactions: transactions,
            recurringSeries: [salary, rent, netflix],
            paymentReminders: reminders,
            customCategories: [
                TransactionCategory(
                    id: "custom-garden",
                    name: "Garden",
                    icon: "leaf.fill",
                    kind: .expense,
                    isCustom: true
                )
            ],
            savingsGoals: goals,
            loans: loans,
            feedbackNotes: [
                FeedbackNote(text: "The period picker could remember where I was.")
            ],
            settings: .default
        )
    }
}
#endif
