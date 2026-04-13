import Foundation

enum MockData {
    static let sampleTransactions: [Transaction] = {
        let calendar = Calendar.current
        let now = Date()

        let salaryDate = calendar.date(byAdding: .day, value: -10, to: now) ?? now
        let rentDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let groceriesDate = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        let coffeeDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now

        return [
            Transaction(amount: 3_200, note: "Monthly salary", categoryID: "salary", type: .income, date: salaryDate, recurrenceRule: .monthly),
            Transaction(amount: 900, note: "Apartment rent", categoryID: "rent", type: .expense, date: rentDate, recurrenceRule: .monthly),
            Transaction(amount: 84.50, note: "Weekly groceries", categoryID: "groceries", type: .expense, date: groceriesDate, recurrenceRule: .weekly),
            Transaction(amount: 4.20, note: "Morning coffee", categoryID: "cafe", type: .expense, date: coffeeDate, recurrenceRule: .daily)
        ]
    }()
}
