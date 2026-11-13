import Foundation

struct TransactionSummary: Hashable {
    let income: Decimal
    let expense: Decimal
    /// Income minus expense for the period. A net result, not a spendable budget.
    let netBalance: Decimal
    /// Expense divided by the days of the period that have already happened.
    let averageSpendingPerDay: Decimal
    let biggestExpense: Decimal
    let totalTransactions: Int
    /// How many of those rows are forecasts rather than recorded entries.
    let projectedTransactions: Int

    /// Entries in other currencies, which the figures above leave out because
    /// amounts are never converted.
    var otherCurrencies: [CurrencyTotal] = []

    var hasProjections: Bool { projectedTransactions > 0 }

    static let empty = TransactionSummary(
        income: 0,
        expense: 0,
        netBalance: 0,
        averageSpendingPerDay: 0,
        biggestExpense: 0,
        totalTransactions: 0,
        projectedTransactions: 0
    )
}

struct CurrencyTotal: Identifiable, Hashable {
    var id: String { currency.rawValue }
    let currency: Currency
    let income: Decimal
    let expense: Decimal
}

struct CategorySpending: Identifiable, Hashable {
    var id: String { category.id }
    let category: TransactionCategory
    let total: Decimal
    /// Fraction of total period expense, 0...1.
    let share: Double
}

struct DailySpendPoint: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let expense: Decimal
    let income: Decimal
    /// True for days after today, whose figures are forecasts.
    let isProjected: Bool
}

enum TransactionAnalytics {
    static func summary(
        occurrences: [TransactionOccurrence],
        elapsedDayCount: Int
    ) -> TransactionSummary {
        var income = Decimal.zero
        var expense = Decimal.zero
        var biggestExpense = Decimal.zero
        var projected = 0

        for item in occurrences {
            switch item.type {
            case .income:
                income += item.amount
            case .expense:
                expense += item.amount
                if item.amount > biggestExpense {
                    biggestExpense = item.amount
                }
            }
            if item.isProjected {
                projected += 1
            }
        }

        let average: Decimal
        if elapsedDayCount > 0 {
            average = (expense / Decimal(elapsedDayCount)).rounded(scale: 2)
        } else {
            average = 0
        }

        return TransactionSummary(
            income: income,
            expense: expense,
            netBalance: income - expense,
            averageSpendingPerDay: average,
            biggestExpense: biggestExpense,
            totalTransactions: occurrences.count,
            projectedTransactions: projected
        )
    }

    /// Income and expense per currency other than `main`, largest first.
    static func otherCurrencyTotals(
        _ occurrences: [TransactionOccurrence],
        main: Currency
    ) -> [CurrencyTotal] {
        var income: [Currency: Decimal] = [:]
        var expense: [Currency: Decimal] = [:]
        for item in occurrences {
            guard let currency = item.currency, currency != main else { continue }
            switch item.type {
            case .income: income[currency, default: 0] += item.amount
            case .expense: expense[currency, default: 0] += item.amount
            }
        }
        return Set(income.keys).union(expense.keys)
            .map { CurrencyTotal(currency: $0, income: income[$0] ?? 0, expense: expense[$0] ?? 0) }
            .sorted { ($0.income + $0.expense) > ($1.income + $1.expense) }
    }

    /// Totals per category for one side of the ledger, with each one's share.
    static func categorySpending(
        from occurrences: [TransactionOccurrence],
        categories: [TransactionCategory],
        type: TransactionType = .expense
    ) -> [CategorySpending] {
        let expenses = occurrences.filter { $0.type == type }
        guard !expenses.isEmpty else { return [] }

        let lookup = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        var totals: [String: Decimal] = [:]
        var overall = Decimal.zero

        for item in expenses {
            totals[item.categoryID, default: .zero] += item.amount
            overall += item.amount
        }

        let divisor = NSDecimalNumber(decimal: overall).doubleValue

        return totals
            .map { categoryID, total in
                let share: Double
                if divisor > 0 {
                    share = NSDecimalNumber(decimal: total).doubleValue / divisor
                } else {
                    share = 0
                }
                return CategorySpending(
                    category: lookup[categoryID] ?? DefaultCategories.category(for: categoryID),
                    total: total,
                    share: min(max(share, 0), 1)
                )
            }
            .sorted { lhs, rhs in
                if lhs.total == rhs.total {
                    return lhs.category.id < rhs.category.id
                }
                return lhs.total > rhs.total
            }
    }

    static func groupedByDay(
        _ occurrences: [TransactionOccurrence],
        calendar: Calendar = .current
    ) -> [DailyTransactionSection] {
        let grouped = Dictionary(grouping: occurrences) { calendar.startOfDay(for: $0.date) }

        return grouped
            .map { day, items in
                DailyTransactionSection(
                    id: sectionID(for: day, calendar: calendar),
                    title: DateFormatting.daySectionTitle(day, calendar: calendar),
                    date: day,
                    items: items.sorted { lhs, rhs in
                        if lhs.date == rhs.date {
                            return lhs.id < rhs.id
                        }
                        return lhs.date > rhs.date
                    }
                )
            }
            .sorted { $0.date > $1.date }
    }

    /// Per-day totals across the period, for the chart. Days with no activity
    /// are included so the line does not imply spending on empty days.
    static func dailySpend(
        occurrences: [TransactionOccurrence],
        in interval: DateInterval,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DailySpendPoint] {
        var expenses: [Date: Decimal] = [:]
        var incomes: [Date: Decimal] = [:]

        for item in occurrences {
            let day = calendar.startOfDay(for: item.date)
            switch item.type {
            case .expense: expenses[day, default: .zero] += item.amount
            case .income: incomes[day, default: .zero] += item.amount
            }
        }

        let today = calendar.startOfDay(for: now)
        var points: [DailySpendPoint] = []
        var cursor = calendar.startOfDay(for: interval.start)
        var guardCount = 0

        while cursor < interval.end, guardCount < 400 {
            guardCount += 1
            points.append(
                DailySpendPoint(
                    date: cursor,
                    expense: expenses[cursor] ?? .zero,
                    income: incomes[cursor] ?? .zero,
                    isProjected: cursor > today
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return points
    }

    /// Avoids allocating an ISO8601DateFormatter per section.
    private static func sectionID(for day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
