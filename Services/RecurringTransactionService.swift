import Foundation

protocol RecurringTransactionServicing {
    func occurrences(for transactions: [Transaction], in period: DateInterval) -> [TransactionOccurrence]
}

struct RecurringTransactionService: RecurringTransactionServicing {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func occurrences(for transactions: [Transaction], in period: DateInterval) -> [TransactionOccurrence] {
        transactions.flatMap { transaction in
            generateOccurrences(for: transaction, in: period)
        }
        .sorted(by: { $0.date > $1.date })
    }

    private func generateOccurrences(for transaction: Transaction, in period: DateInterval) -> [TransactionOccurrence] {
        let rule = transaction.recurrenceRule ?? .none

        if rule == .none {
            guard period.contains(transaction.date) else { return [] }
            return [
                TransactionOccurrence(
                    id: "\(transaction.id.uuidString)-base",
                    sourceTransaction: transaction,
                    date: transaction.date,
                    isGenerated: false
                )
            ]
        }

        var occurrenceDate = transaction.date
        var results: [TransactionOccurrence] = []
        var safetyCounter = 0

        while occurrenceDate < period.start, safetyCounter < 5_000 {
            safetyCounter += 1
            guard let next = nextDate(from: occurrenceDate, rule: rule) else { break }
            occurrenceDate = next
        }

        while occurrenceDate < period.end, safetyCounter < 10_000 {
            safetyCounter += 1
            if occurrenceDate >= period.start {
                let isGenerated = !calendar.isDate(occurrenceDate, equalTo: transaction.date, toGranularity: .minute)
                results.append(
                    TransactionOccurrence(
                        id: "\(transaction.id.uuidString)-\(occurrenceDate.timeIntervalSince1970)",
                        sourceTransaction: transaction,
                        date: occurrenceDate,
                        isGenerated: isGenerated
                    )
                )
            }

            guard let next = nextDate(from: occurrenceDate, rule: rule) else { break }
            occurrenceDate = next
        }

        return results
    }

    private func nextDate(from date: Date, rule: RecurrenceRule) -> Date? {
        switch rule {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }
}
