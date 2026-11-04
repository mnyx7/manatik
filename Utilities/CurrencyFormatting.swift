import Foundation

/// Formats money for display.
///
/// The number format (grouping, decimal separator, symbol placement) always
/// follows the *device* locale. Only the currency code changes with the user's
/// selection, so picking EUR no longer reformats amounts German-style.
enum CurrencyFormatting {
    private static let lock = NSLock()
    private static var formatters: [String: NumberFormatter] = [:]

    private static func formatter(for currency: Currency) -> NumberFormatter {
        let key = "\(currency.rawValue)|\(Locale.current.identifier)"

        lock.lock()
        defer { lock.unlock() }

        if let cached = formatters[key] {
            return cached
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.currencyCode = currency.rawValue
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        formatters[key] = formatter
        return formatter
    }

    static func format(amount: Decimal, currency: Currency) -> String {
        let number = NSDecimalNumber(decimal: amount)
        return formatter(for: currency).string(from: number)
            ?? "\(currency.symbol)\(amount)"
    }

    /// Signed string for a ledger row, e.g. "-$4.20" / "+$3,200.00".
    static func formatSigned(amount: Decimal, type: TransactionType, currency: Currency) -> String {
        let magnitude = format(amount: amount, currency: currency)
        return (type == .expense ? "-" : "+") + magnitude
    }

    /// Spelled-out value for VoiceOver, avoiding a bare "-" being read as a dash.
    static func accessibleDescription(amount: Decimal, type: TransactionType, currency: Currency) -> String {
        let magnitude = format(amount: amount, currency: currency)
        switch type {
        case .income:
            return String(
                format: NSLocalizedString("%@ income", comment: "Accessibility amount"),
                magnitude
            )
        case .expense:
            return String(
                format: NSLocalizedString("%@ expense", comment: "Accessibility amount"),
                magnitude
            )
        }
    }

    /// Called when the locale may have changed under us.
    static func invalidateCache() {
        lock.lock()
        formatters.removeAll()
        lock.unlock()
    }
}
