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
        var reviewMessage: String?
    }

    static func parse(_ text: String, currency: Currency, categories: [TransactionCategory], localeID: String? = nil) throws -> Result {
        let normalized = text.lowercased().folding(options: [.diacriticInsensitive], locale: nil)
        let tokens = normalized.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
        func contains(_ words: [String]) -> Bool { words.contains { tokens.contains($0) } }
        let amounts = try spokenAmounts(in: text, localeID: localeID)
        guard !contains(["minus", "минус", "menfi", "mənfi"]) else { throw ParseError.invalidAmount }
        guard amounts.count == 1, let amount = amounts.first, amount > 0,
              amount <= DecimalAmountValidator.maximumAmount, amount.rounded(scale: 2) == amount else {
            throw ParseError.invalidAmount
        }
        let income = contains(["income", "incomes", "incoming", "доход", "доходы", "дохода", "входящие", "входящий", "входящую", "поступление", "поступления", "инком", "инкам", "gelir", "gəlir"])
        let expense = contains(["expense", "expenses", "spent", "spending", "outgoing", "расход", "расходы", "расхода", "исходящие", "трата", "трату", "потратила", "потратил", "xerc", "xərc"])
        guard !(income && expense) else { throw ParseError.ambiguousType }
        let salary = contains(["salary", "зарплата", "зарплату", "maas"])
        let type: TransactionType = income || (salary && !expense) ? .income : .expense
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
            "cafe": ["кафе", "coffee", "кофе", "kafe", "kafede", "kafeda", "kafedə"],
            "restaurant": ["ресторан", "ресторане", "restoran"],
            "salary": ["зарплата", "зарплату", "maas"],
            "transport": ["transportation", "transit", "транспорт", "транспорта", "транспорте", "taxi", "такси", "taksi", "nəqliyyat", "neqliyyat"],
            "shopping": ["покупки", "покупок", "шоппинг", "alış-veriş", "alisveris"],
            "groceries": ["продукты", "продуктов", "market"],
            "rent": ["аренда", "аренду", "kiraye"]
        ]
        let named = categories.filter { category in
            guard category.id != "savings", category.id != "loan" else { return false }
            let names = [category.name, category.localizedName, category.id] + (categoryAliases[category.id] ?? [])
            return names.contains { name in
                let words = name.lowercased().folding(options: [.diacriticInsensitive], locale: nil)
                    .components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
                guard !words.isEmpty, words.count <= tokens.count else { return false }
                return (0...(tokens.count - words.count)).contains {
                    Array(tokens[$0..<($0 + words.count)]) == words
                }
            }
        }
        let candidates = named.filter { category in
            category.kind == .both || (type == .income ? category.kind == .income : category.kind == .expense)
        }
        let reviewMessage: String?
        if candidates.isEmpty && !named.isEmpty {
            reviewMessage = AppLocalization.string("The named category is not available for this entry type. Other is selected; choose a category before saving.", comment: "Voice category review")
        } else if candidates.count > 1 {
            reviewMessage = AppLocalization.string("More than one category was mentioned. Other is selected; choose a category before saving.", comment: "Voice category review")
        } else { reviewMessage = nil }
        return Result(amount: amount, currency: currencies.first ?? currency, type: type,
                      categoryID: candidates.count == 1 ? candidates[0].id : "other",
                      isBill: contains(["bill", "bills", "билл", "биллс", "счет", "счёт", "счета"]), note: text,
                      reviewMessage: reviewMessage)
    }

    /// Numeric and spoken amounts share one scan, so mixed-language or
    /// mixed numeric/spoken commands cannot silently discard a second amount.
    private static func spokenAmounts(in text: String, localeID: String?) throws -> [Decimal] {
        let source = text.lowercased()
        let range = NSRange(source.startIndex..., in: source)
        let numberPattern = #"(?<![\p{L}\d.,])([-−]?(?:\d{1,3}(?:[ \u00A0\u202F]\d{3})+|\d+)(?:[.,]\d+)?)(?:\s*(тысяч(?:а|и|у)?|тыс\.?|thousand|миллион(?:а|ов)?|million|milyon|min))?(?![\p{L}\d])"#
        let numeric = try NSRegularExpression(pattern: numberPattern).matches(in: source, range: range)
        var amounts = numeric.compactMap { match -> Decimal? in
            guard let valueRange = Range(match.range(at: 1), in: source) else { return nil }
            let digits = source[valueRange].filter { !$0.isWhitespace }.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "−", with: "-")
            guard var value = Decimal(string: digits) else { return nil }
            if let scaleRange = Range(match.range(at: 2), in: source) {
                let scale = source[scaleRange]
                value *= ["million", "milyon"].contains(String(scale)) || scale.hasPrefix("миллион") ? 1_000_000 : 1_000
            }
            return value
        }
        let wordMatches = try NSRegularExpression(pattern: #"\p{L}+"#).matches(in: source, range: range)
        let words = wordMatches.map { String((source as NSString).substring(with: $0.range)) }
        var seen = Set<String>()
        let formatters: [NumberFormatter] = [localeID ?? "en", "en", "ru", "az"].filter { seen.insert($0).inserted }.map {
            let formatter = NumberFormatter()
            formatter.numberStyle = .spellOut
            formatter.locale = Locale(identifier: $0)
            return formatter
        }
        func canonical(_ value: String, formatter: NumberFormatter) -> String {
            value.lowercased().folding(options: [.diacriticInsensitive], locale: nil)
                .components(separatedBy: CharacterSet.letters.inverted)
                .filter { !$0.isEmpty && !(formatter.locale.language.languageCode?.identifier == "en" && $0 == "and") }
                .joined(separator: " ")
        }
        var start = 0
        while start < words.count {
            if numeric.contains(where: { NSIntersectionRange($0.range, wordMatches[start].range).length > 0 }) {
                start += 1
                continue
            }
            var consumed = 0
            for length in stride(from: min(8, words.count - start), through: 1, by: -1) {
                let span = NSUnionRange(wordMatches[start].range, wordMatches[start + length - 1].range)
                guard !numeric.contains(where: { NSIntersectionRange($0.range, span).length > 0 }) else { continue }
                let raw = (source as NSString).substring(with: span)
                guard raw.allSatisfy({ $0.isLetter || $0.isWhitespace || $0 == "-" }) else { continue }
                let phrase = words[start..<(start + length)].joined(separator: " ")
                for formatter in formatters {
                    // Azerbaijani “on” is ten, but English “on shopping” is a
                    // preposition. Do not invent an extra amount from it.
                    if formatter.locale.language.languageCode?.identifier == "az", phrase == "on",
                       Locale(identifier: localeID ?? "en").language.languageCode?.identifier != "az" {
                        let next = start + length < words.count ? words[start + length] : ""
                        guard ["manat", "azn", "dollar", "dollars", "usd", "avro", "euro", "eur"].contains(next) else { continue }
                    }
                    let alternatives = [phrase, phrase.replacingOccurrences(of: " ", with: "-")]
                    if let number = alternatives.compactMap({ formatter.number(from: $0) }).first(where: {
                        formatter.string(from: $0).map { canonical($0, formatter: formatter) == canonical(phrase, formatter: formatter) } ?? false
                    }) {
                        amounts.append(number.decimalValue)
                        consumed = length
                        break
                    }
                }
                if consumed > 0 { break }
            }
            if consumed == 0 && ["тысяч", "тысяча", "тысячи", "тысячу", "тыс", "thousand", "million", "миллион", "миллиона", "миллионов", "milyon", "min"].contains(words[start]) {
                throw ParseError.invalidAmount
            }
            start += max(1, consumed)
        }
        return amounts
    }

    static func recognitionHints(categories: [TransactionCategory], localeID: String) -> [String] {
        let phrases: [String]
        switch Locale(identifier: localeID).language.languageCode?.identifier {
        case "ru":
            phrases = ["доход", "расход", "входящие", "пять тысяч манат", "десять евро", "категория транспорт", "кафе", "покупки", "добавь в биллс", "манат", "доллар", "евро"]
        case "az":
            phrases = ["gəlir", "xərc", "beş manat", "kafedə", "nəqliyyat", "maaş", "manat", "dollar", "avro", "bills"]
        default:
            phrases = ["income", "expense", "ten USD", "transportation", "add to bill", "five dollars", "shopping", "cafe", "manat", "euro"]
        }
        var seen = Set<String>()
        return Array((phrases + categories.flatMap { [$0.name, $0.localizedName] })
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }.prefix(100))
    }

    enum ParseError: LocalizedError {
        case invalidAmount, ambiguousType, ambiguousCurrency
        var errorDescription: String? {
            switch self {
            case .invalidAmount: return AppLocalization.string("Say one positive amount with up to two decimal places, or type it below.", comment: "Voice entry feedback")
            case .ambiguousType: return AppLocalization.string("Say either income or expense for one entry.", comment: "Voice entry feedback")
            case .ambiguousCurrency: return AppLocalization.string("Use one currency per entry.", comment: "Voice entry feedback")
            }
        }
    }
}
