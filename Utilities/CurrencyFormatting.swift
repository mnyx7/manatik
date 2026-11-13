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
        // Looked up before taking the lock: `symbol(for:)` takes it too, and
        // NSLock is not reentrant.
        let glyph = symbol(for: currency)

        lock.lock()
        defer { lock.unlock() }

        if let cached = formatters[key] {
            return cached
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.currencyCode = currency.rawValue
        formatter.currencySymbol = glyph
        pinSymbolLeft(formatter, glyph)
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        formatters[key] = formatter
        return formatter
    }

    /// The symbol always leads, "₼1.552,86", even where the language puts
    /// it after the number. Grouping and decimal marks still follow the phone.
    private static func pinSymbolLeft(_ formatter: NumberFormatter, _ glyph: String) {
        formatter.positivePrefix = glyph
        formatter.positiveSuffix = ""
        formatter.negativePrefix = "-" + glyph
        formatter.negativeSuffix = ""
    }

    private static var symbols: [String: String] = [:]

    /// See `Currency.symbol`. Cached because pickers ask for every currency.
    static func symbol(for currency: Currency) -> String {
        let key = "\(currency.rawValue)|\(Locale.current.identifier)"
        lock.lock()
        if let cached = symbols[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.currencyCode = currency.rawValue
        let value: String
        if let local = formatter.currencySymbol, local != currency.rawValue {
            value = local
        } else {
            value = Currency.nativeSymbols[currency.rawValue] ?? currency.rawValue
        }

        lock.lock()
        symbols[key] = value
        lock.unlock()
        return value
    }

    /// Totals in other currencies, e.g. "+$200 · −€30", for the line under a
    /// balance. Empty when everything is in the main currency.
    static func formatOthers(_ others: [CurrencyTotal]) -> String {
        others.map { total in
            [
                total.income > 0 ? formatSigned(amount: total.income, type: .income, currency: total.currency) : nil,
                total.expense > 0 ? formatSigned(amount: total.expense, type: .expense, currency: total.currency) : nil
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        }
        .joined(separator: " \u{00B7} ")
    }

    static func format(amount: Decimal, currency: Currency) -> String {
        if AmountPrivacy.shared.isHidden { return masked(currency) }
        let number = NSDecimalNumber(decimal: amount)
        return formatter(for: currency).string(from: number)
            ?? "\(currency.symbol)\(amount)"
    }

    /// Keeps the currency so the layout reads the same, minus the figure.
    private static func masked(_ currency: Currency) -> String {
        "\(currency.symbol)\(AmountPrivacy.mask)"
    }

    /// Whole units only, e.g. "₼1 960", for labels too small for cents.
    static func formatWhole(amount: Decimal, currency: Currency) -> String {
        if AmountPrivacy.shared.isHidden { return masked(currency) }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.currencyCode = currency.rawValue
        formatter.currencySymbol = symbol(for: currency)
        pinSymbolLeft(formatter, symbol(for: currency))
        formatter.maximumFractionDigits = 0
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? "\(currency.symbol)\(amount)"
    }

    /// Signed string for a ledger row, e.g. "-$4.20" / "+$3,200.00".
    static func formatSigned(amount: Decimal, type: TransactionType, currency: Currency) -> String {
        let magnitude = format(amount: amount, currency: currency)
        return (type == .expense ? "-" : "+") + magnitude
    }

    /// Spelled-out value for VoiceOver, avoiding a bare "-" being read as a dash.
    static func accessibleDescription(amount: Decimal, type: TransactionType, currency: Currency) -> String {
        if AmountPrivacy.shared.isHidden {
            return NSLocalizedString("amount hidden", comment: "Accessibility amount")
        }
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
        symbols.removeAll()
        lock.unlock()
    }
}
