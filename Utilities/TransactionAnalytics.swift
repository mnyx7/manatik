import Foundation

struct TransactionSummary {
    let income: Double
    let expense: Double
    let amountLeft: Double
    let averageSpendingPerDay: Double
    let biggestExpense: Double
    let totalTransactions: Int
}

struct CategorySpending: Identifiable {
    var id: String { category.id }
    let category: TransactionCategory
    let total: Double
}

enum TransactionAnalytics {
    static func summary(occurrences: [TransactionOccurrence], dayCount: Int) -> TransactionSummary {
        let income = occurrences.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expense = occurrences.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let biggestExpense = occurrences.filter { $0.type == .expense }.map { $0.amount }.max() ?? 0
        let avg = dayCount > 0 ? expense / Double(dayCount) : 0

        return TransactionSummary(
            income: income,
            expense: expense,
            amountLeft: income - expense,
            averageSpendingPerDay: avg,
            biggestExpense: biggestExpense,
            totalTransactions: occurrences.count
        )
    }

    static func topCategorySpending(
        from occurrences: [TransactionOccurrence],
        categories: [TransactionCategory]
    ) -> [CategorySpending] {
        let expenses = occurrences.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses, by: { $0.categoryID })

        return grouped.map { key, values in
            let category = categories.first(where: { $0.id == key }) ?? DefaultCategories.category(for: key)
            let total = values.reduce(0) { $0 + $1.amount }
            return CategorySpending(category: category, total: total)
        }
        .sorted(by: { $0.total > $1.total })
    }

    static func groupedByDay(_ occurrences: [TransactionOccurrence], calendar: Calendar = .current) -> [DailyTransactionSection] {
        let grouped = Dictionary(grouping: occurrences) { calendar.startOfDay(for: $0.date) }

        return grouped
            .map { day, items in
                let sortedItems = items.sorted { $0.date > $1.date }
                return DailyTransactionSection(
                    id: ISO8601DateFormatter().string(from: day),
                    title: DateFormatting.daySectionTitle(day, calendar: calendar),
                    date: day,
                    items: sortedItems
                )
            }
            .sorted { $0.date > $1.date }
    }
}
