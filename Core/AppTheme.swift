import SwiftUI

/// Cozy palette: warm cream pages, soft sage for money in, terracotta for money
/// out, muted teal for savings, soft plum for debt.
///
/// Every colour is an asset-catalog pair, so dark mode is a real design rather
/// than a light pastel dimmed with opacity.
enum AppTheme {
    static let pageBackground = Color("AppBackground")
    static let cardBackground = Color("CardSurface")

    static let incomeSurface = Color("IncomeSurface")
    static let incomeAccent = Color("IncomeAccent")
    static let expenseSurface = Color("ExpenseSurface")
    static let expenseAccent = Color("ExpenseAccent")
    static let savingsSurface = Color("SavingsSurface")
    static let savingsAccent = Color("SavingsAccent")
    static let loanSurface = Color("LoanSurface")
    static let loanAccent = Color("LoanAccent")

    /// Apple's minimum comfortable hit target.
    static let minimumTapTarget: CGFloat = 44

    // Generous, soft geometry reads calmer than tight boxes.
    static let cardCornerRadius: CGFloat = 20
    static let innerCornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 18

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

extension View {
    /// Standard cozy card: warm surface, soft corners, a hint of lift.
    func cozyCard(
        _ surface: Color = AppTheme.cardBackground,
        padding: CGFloat = AppTheme.cardPadding
    ) -> some View {
        self
            .padding(padding)
            .background(
                surface,
                in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}
