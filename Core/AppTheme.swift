import SwiftUI

enum AppTheme {
    static let incomeColor = Color(red: 0.75, green: 0.93, blue: 0.78)
    static let expenseColor = Color(red: 0.98, green: 0.78, blue: 0.78)
    static let savingsColor = Color(red: 0.77, green: 0.88, blue: 0.98)
    static let cardBackground = Color(.secondarySystemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)

    static func amountColor(for type: TransactionType) -> Color {
        switch type {
        case .income:
            return .green
        case .expense:
            return .red
        }
    }
}
