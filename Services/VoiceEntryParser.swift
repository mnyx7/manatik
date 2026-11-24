import Foundation

/// Deliberately accepts one entry at a time. No store writes happen here.
enum VoiceEntryParser {
    struct Result {
        var amount: Decimal
        var currency: Currency
        var type: TransactionType
        var categoryID: String
        var isBill: Bool
        var note: String
    }

    static func parse(_ text: String, currency: Currency, categories: [TransactionCategory]) throws -> Result {
        let normalized = text.lowercased().folding(options: [.diacriticInsensitive], locale: nil)
        let tokens = normalized.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
        func contains(_ words: [String]) -> Bool { words.contains { tokens.contains($0) } }
        let regex = try NSRegularExpression(pattern: #"(?<![\p{L}\d])-?\d+(?:[.,]\d+)?(?![\p{L}\d])"#)
        let matches = regex.matches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized))
        var amounts = matches.compactMap { match -> Decimal? in
            guard let range = Range(match.range, in: normalized) else { return nil }
            return Decimal(string: normalized[range].replacingOccurrences(of: ",", with: "."))
        }
        if amounts.isEmpty {
            let formatter = NumberFormatter()
            formatter.numberStyle = .spellOut
            func words(_ value: String) -> String {
                value.lowercased().folding(options: [.diacriticInsensitive], locale: nil)
                    .components(separatedBy: CharacterSet.letters.inverted)
                    .filter { !$0.isEmpty }.joined(separator: " ")
            }
            // Require a round trip: NumberFormatter can partially parse unrelated
            // words, and can misread English spaces in “twenty five”.
            for language in ["en", "ru", "az"] {
                formatter.locale = Locale(identifier: language)
                var found: [Decimal] = []
                var start = 0
                while start < tokens.count {
                    var consumed = 0
                    for length in stride(from: min(8, tokens.count - start), through: 1, by: -1) {
                        let phrase = tokens[start..<(start + length)].joined(separator: " ")
                        let alternatives = [phrase, phrase.replacingOccurrences(of: " ", with: "-")]
                        if let number = alternatives.compactMap({ formatter.number(from: $0) }).first(where: {
                            formatter.string(from: $0).map { words($0) == phrase } ?? false
                        }) {
                            found.append(number.decimalValue)
                            consumed = length
                            break
                        }
                    }
                    start += max(1, consumed)
                }
                if !found.isEmpty { amounts = found; break }
            }
        }
        guard !contains(["minus", "минус", "menfi"]) else { throw ParseError.invalidAmount }
        guard amounts.count == 1, let amount = amounts.first, amount > 0,
              amount <= DecimalAmountValidator.maximumAmount, amount.rounded(scale: 2) == amount else {
            throw ParseError.invalidAmount
        }
        let income = contains(["income", "salary", "доход", "зарплата", "зарплату", "gelir", "maaş", "maas"])
        let expense = contains(["expense", "spent", "расход", "потратила", "потратил", "xerc"])
        guard !(income && expense) else { throw ParseError.ambiguousType }
        let type: TransactionType = income ? .income : .expense
        let aliases: [(Currency, [String])] = [
            (.azn, ["azn", "manat", "manats", "манат", "маната", "манатов"]),
            (.usd, ["usd", "dollar", "dollars", "доллар", "доллара", "долларов"]),
            (.eur, ["eur", "euro", "euros", "евро", "avro"])
        ]
        var currencies = aliases.filter { contains($0.1) }.map { $0.0 }
        for (symbol, value) in [("$", Currency.usd), ("€", Currency.eur), ("₼", Currency.azn)] {
            if normalized.contains(symbol), !currencies.contains(value) { currencies.append(value) }
        }
        for code in Locale.commonISOCurrencyCodes where tokens.contains(code.lowercased()) {
            if let value = Currency(rawValue: code), !currencies.contains(value) { currencies.append(value) }
        }
        guard currencies.count <= 1 else { throw ParseError.ambiguousCurrency }
        let categoryAliases: [String: [String]] = [
            "cafe": ["кафе", "coffee", "кофе", "kafe"],
            "restaurant": ["ресторан", "ресторане", "restoran"],
            "salary": ["зарплата", "зарплату", "maas"],
            "transport": ["taxi", "такси", "taksi"],
            "groceries": ["продукты", "продуктов", "market"],
            "rent": ["аренда", "аренду", "kiraye"]
        ]
        let candidates = categories.filter { category in
            guard category.id != "savings", category.id != "loan" else { return false }
            let compatible = category.kind == .both || (type == .income ? category.kind == .income : category.kind == .expense)
            let names = [category.name, category.localizedName, category.id] + (categoryAliases[category.id] ?? [])
            return compatible && names.contains { name in
                let words = name.lowercased().folding(options: [.diacriticInsensitive], locale: nil)
                    .components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
                guard !words.isEmpty else { return false }
                return normalized.range(of: #"(?<!\p{L})"# + NSRegularExpression.escapedPattern(for: words.joined(separator: " ")) + #"(?!\p{L})"#, options: .regularExpression) != nil
            }
        }
        return Result(amount: amount, currency: currencies.first ?? currency, type: type,
                      categoryID: candidates.count == 1 ? candidates[0].id : "other",
                      isBill: contains(["bill", "bills", "билл", "биллс", "счет", "счёт"]), note: text)
    }

    enum ParseError: LocalizedError {
        case invalidAmount, ambiguousType, ambiguousCurrency
        var errorDescription: String? {
            switch self {
            case .invalidAmount: return "Say one positive amount with up to two decimal places, or type it below."
            case .ambiguousType: return "Say either income or expense for one entry."
            case .ambiguousCurrency: return "Use one currency per entry."
            }
        }
    }
}
