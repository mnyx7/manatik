import SwiftUI

enum AppTheme {
    /// Card fills and the text colours that are legible on them. Both come from
    /// the asset catalog, so each has a real dark-mode variant instead of a
    /// light pastel dimmed with opacity.
    static let incomeSurface = Color("IncomeSurface")
    static let incomeAccent = Color("IncomeAccent")
    static let expenseSurface = Color("ExpenseSurface")
    static let expenseAccent = Color("ExpenseAccent")
    static let savingsSurface = Color("SavingsSurface")
    static let savingsAccent = Color("SavingsAccent")

    static let cardBackground = Color(.secondarySystemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)

    /// Apple's minimum comfortable hit target.
    static let minimumTapTarget: CGFloat = 44
    static let cardCornerRadius: CGFloat = 14

    static func surface(for type: TransactionType) -> Color {
        type == .income ? incomeSurface : expenseSurface
    }

    static func accent(for type: TransactionType) -> Color {
        type == .income ? incomeAccent : expenseAccent
    }

    /// Colour for a net figure: negative reads as overspend.
    static func netAccent(for amount: Decimal) -> Color {
        amount < 0 ? expenseAccent : savingsAccent
    }
}
