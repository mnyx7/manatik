import Foundation

/// Amount entry rules.
///
/// `sanitize` always returns something usable, so a keystroke or a paste never
/// vanishes with no feedback. Extra decimals are truncated and grouping
/// separators are interpreted rather than rejected.
enum DecimalAmountValidator {
    static let maximumFractionDigits = 2
    static let maximumIntegerDigits = 9
    static let maximumAmount = Decimal(string: "999999999.99") ?? Decimal(999_999_999)

    private static let posixLocale = Locale(identifier: "en_US_POSIX")
    private static let separators: Set<Character> = [".", ","]

    // MARK: - Typing

    /// What an amount field shows while typing: the number grouped the way
    /// the device writes it, e.g. "140,983.5" or "140 983,5", keeping a decimal
    /// mark the user has just typed. Every field binds through this.
    static func sanitize(_ raw: String, locale: Locale = .current) -> String {
        grouped(plain(raw, locale: locale), locale: locale)
    }

    /// Plain "1234.5" from typed or displayed text.
    ///
    /// The field shows grouping marks, so they must not be mistaken for a
    /// decimal mark on the next keystroke: a lone mark is read with the
    /// device's meaning (grouping in "140,983" on an English phone, decimal in
    /// "12,5" on an Azerbaijani one). Text holding both kinds, like a paste of
    /// "1,234.56", falls back to "the last one is decimal".
    static func plain(_ raw: String, locale: Locale = .current) -> String {
        let spaces: Set<Character> = [" ", "\u{00A0}", "\u{202F}", "'", "’"]
        var text = String(raw.filter { !spaces.contains($0) })

        let kinds = Set(text.filter { separators.contains($0) })
        if kinds.count == 1, let mark = kinds.first {
            let grouping = locale.groupingSeparator?.first
            let decimal = locale.decimalSeparator?.first ?? "."
            if mark == grouping, mark != decimal {
                text.removeAll { $0 == mark }
            } else if mark == decimal, mark != "." {
                text = text.replacingOccurrences(of: String(mark), with: ".")
            }
        }
        return normalize(text)
    }

    /// Groups the integer part of a plain "1234.5" for display.
    static func grouped(_ plain: String, locale: Locale = .current) -> String {
        guard !plain.isEmpty else { return "" }
        let parts = plain.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let integer = String(parts[0])
        let grouping = locale.groupingSeparator ?? ","
        let decimal = locale.decimalSeparator ?? "."

        var groupedInteger = ""
        for (offset, digit) in integer.reversed().enumerated() {
            if offset > 0, offset.isMultiple(of: 3) { groupedInteger.append(contentsOf: grouping.reversed()) }
            groupedInteger.append(digit)
        }
        groupedInteger = String(groupedInteger.reversed())

        guard parts.count > 1 else { return groupedInteger }
        return groupedInteger + decimal + parts[1]
    }

    // MARK: - Normalizing

    /// Normalizes arbitrary input to a plain `123.45` form.
    ///
    /// - A single separator is read as the decimal separator ("12,50" -> "12.50").
    /// - Several separators of one kind are grouping ("1.234.567" -> "1234567").
    /// - Mixed separators: the last one is decimal ("1,234.56" -> "1234.56").
    private static func normalize(_ raw: String) -> String {
        let filtered = raw.filter { $0.isWholeNumber || separators.contains($0) }
        guard !filtered.isEmpty else { return "" }

        let separatorIndices = filtered.indices.filter { separators.contains(filtered[$0]) }

        var integerPart = ""
        var fractionPart: String?

        if separatorIndices.isEmpty {
            integerPart = String(filtered)
        } else {
            let distinctKinds = Set(separatorIndices.map { filtered[$0] })
            let treatLastAsDecimal = distinctKinds.count > 1 || separatorIndices.count == 1

            if treatLastAsDecimal, let decimalIndex = separatorIndices.last {
                integerPart = String(
                    filtered[filtered.startIndex..<decimalIndex].filter { $0.isWholeNumber }
                )
                let after = filtered.index(after: decimalIndex)
                fractionPart = String(filtered[after...].filter { $0.isWholeNumber })
            } else {
                integerPart = filtered.filter { $0.isWholeNumber }
            }
        }

        if integerPart.count > maximumIntegerDigits {
            integerPart = String(integerPart.prefix(maximumIntegerDigits))
        }

        // Keep a single leading zero at most, unless a fraction follows.
        while integerPart.count > 1, integerPart.hasPrefix("0") {
            integerPart.removeFirst()
        }

        guard var fraction = fractionPart else {
            return integerPart
        }

        if fraction.count > maximumFractionDigits {
            fraction = String(fraction.prefix(maximumFractionDigits))
        }

        let base = integerPart.isEmpty ? "0" : integerPart
        return "\(base).\(fraction)"
    }

    static func parsed(from raw: String) -> Decimal? {
        let sanitized = plain(raw)
        guard !sanitized.isEmpty else { return nil }
        guard let amount = Decimal(string: sanitized, locale: posixLocale) else { return nil }
        guard amount > 0, amount <= maximumAmount else { return nil }
        return amount
    }

    /// A message naming the actual problem, or nil when the input is usable.
    static func validationMessage(for raw: String) -> String? {
        let sanitized = plain(raw)

        if sanitized.isEmpty {
            return NSLocalizedString("Enter an amount.", comment: "Amount validation")
        }
        guard let amount = Decimal(string: sanitized, locale: posixLocale) else {
            return NSLocalizedString("That is not a valid number.", comment: "Amount validation")
        }
        if amount <= 0 {
            return NSLocalizedString("Amount must be greater than zero.", comment: "Amount validation")
        }
        if amount > maximumAmount {
            return String(
                format: NSLocalizedString("Amount cannot exceed %@.", comment: "Amount validation"),
                CurrencyFormatting.format(amount: maximumAmount, currency: .azn)
            )
        }
        return nil
    }

    /// Editable text for an existing stored amount, grouped like typing is.
    static func editingText(for amount: Decimal) -> String {
        let rounded = amount.rounded(scale: maximumFractionDigits)
        return grouped(NSDecimalNumber(decimal: rounded).stringValue)
    }
}

extension Decimal {
    /// Bankers-free half-up rounding at a fixed scale.
    func rounded(scale: Int) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
}
