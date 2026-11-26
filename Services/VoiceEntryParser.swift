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
        var date: Date
    }

    static func parse(_ text: String, currency: Currency, categories: [TransactionCategory], localeID: String? = nil,
                      now: Date = Date(), calendar: Calendar = .current) throws -> Result {
        // Explicit notes are data, not a second command or an extra amount.
        let noteMarkers = ["note", "memo", "заметка", "комментарий", "qeyd"]
        let marker = noteMarkers.flatMap { VoiceVocabulary.matches($0, in: text) }.min { $0.location < $1.location }
        let command = marker.map { (text as NSString).substring(to: $0.location) } ?? text
        var note = marker.map { (text as NSString).substring(from: NSMaxRange($0)).trimmingCharacters(in: .whitespacesAndNewlines) } ?? text
        if marker != nil && note.hasPrefix(":") { note = String(note.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !VoiceVocabulary.contains(VoiceVocabulary.unsupported, in: command) else { throw ParseError.unsupportedAction }
        let initialCategories = VoiceVocabulary.categoryMatches(command, categories: categories)
        let dateCommand = VoiceVocabulary.mask(command, ranges: initialCategories.map { $0.range })
        let (date, dateRanges) = try relativeDate(in: dateCommand, now: now, calendar: calendar)
        let datedCommand = VoiceVocabulary.mask(command, ranges: dateRanges)
        let matches = VoiceVocabulary.categoryMatches(datedCommand, categories: categories)
        let unique = Dictionary(matches.map { ($0.category.id, $0.category) }, uniquingKeysWith: { first, _ in first })
        let named = Array(unique.values)
        // Numeric custom names (e.g. “7 Eleven”) must not become amounts.
        let amountCommand = moneySpacing(VoiceVocabulary.mask(datedCommand, ranges: matches.map { $0.range }))
        let amountSpans = try spokenAmounts(in: amountCommand, localeID: localeID)
        var amounts = amountSpans.map { $0.value }
        let resolvedCurrency = try resolveCurrency(in: amountCommand, fallback: currency, localeID: localeID)
        let currencyValue = resolvedCurrency.currency
        let unit = VoiceVocabulary.minorUnits.filter { VoiceVocabulary.contains($0.value, in: amountCommand) }.map { $0.key }
        let cents = VoiceVocabulary.contains(VoiceVocabulary.cents, in: amountCommand)
        if !unit.isEmpty || cents {
            guard unit.count <= 1, unit.first.map({ $0 == currencyValue.rawValue }) ?? true else { throw ParseError.ambiguousCurrency }
            if cents && !["USD", "EUR", "CAD", "AUD", "NZD", "SGD", "HKD"].contains(currencyValue.rawValue) { throw ParseError.ambiguousCurrency }
            let minorRanges = (Array(VoiceVocabulary.minorUnits.values).flatMap { $0 } + VoiceVocabulary.cents).flatMap { VoiceVocabulary.matches($0, in: amountCommand) }
            guard let lastAmount = amountSpans.last, minorRanges.allSatisfy({ $0.location >= NSMaxRange(lastAmount.range) }) else { throw ParseError.invalidAmount }
            guard amounts.count == 1 || amounts.count == 2,
                  let minor = amounts.last, minor >= 0, minor < 100, minor.rounded(scale: 0) == minor else { throw ParseError.invalidAmount }
            if amounts.count == 2 {
                let prefix = (amountCommand as NSString).substring(to: lastAmount.range.location)
                let majorUnit = try resolveCurrency(in: prefix, fallback: currency, localeID: localeID)
                guard majorUnit.explicit, majorUnit.currency == currencyValue, amounts[0] >= 0, amounts[0].rounded(scale: 0) == amounts[0] else { throw ParseError.invalidAmount }
                amounts = [amounts[0] + minor / 100]
            } else { amounts = [minor / 100] }
        }
        guard !VoiceVocabulary.contains(["minus", "минус", "mənfi"], in: amountCommand),
              amounts.count == 1, let amount = amounts.first, amount > 0,
              amount <= DecimalAmountValidator.maximumAmount, amount.rounded(scale: 2) == amount else { throw ParseError.invalidAmount }
        let noIncome = VoiceVocabulary.contains(["not income", "не доход", "gəlir deyil"], in: datedCommand)
        let noExpense = VoiceVocabulary.contains(["not an expense", "not expense", "не расход", "xərc deyil"], in: datedCommand)
        guard !(noIncome && noExpense) else { throw ParseError.ambiguousType }
        let income = (VoiceVocabulary.contains(VoiceVocabulary.income, in: datedCommand) && !noIncome) || noExpense
        let expense = (VoiceVocabulary.contains(VoiceVocabulary.expense, in: datedCommand) && !noExpense) || noIncome
        guard !(income && expense) else { throw ParseError.ambiguousType }
        let inferredIncome = named.count == 1 && named.first?.kind == .income
        let type: TransactionType = income || (inferredIncome && !expense) ? .income : .expense
        let compatible = named.filter { $0.kind == .both || (type == .income ? $0.kind == .income : $0.kind == .expense) }
        let categoryID = compatible.count == 1 ? compatible[0].id : "other"
        var warnings: [String] = []
        if compatible.isEmpty && !named.isEmpty {
            warnings.append(AppLocalization.string("The named category is not available for this entry type. Other is selected; choose a category before saving.", comment: "Voice category review"))
        } else if compatible.count > 1 {
            warnings.append(AppLocalization.string("More than one category was mentioned. Other is selected; choose a category before saving.", comment: "Voice category review"))
        }
        if ["savings", "loan"].contains(categoryID) {
            warnings.append(AppLocalization.string("This records a transaction only. Savings goals and loan balances are not updated.", comment: "Voice linked category warning"))
        }
        if VoiceVocabulary.contains(VoiceVocabulary.repeats, in: datedCommand) {
            warnings.append(AppLocalization.string("A repeating schedule was mentioned. Set Repeat in the review form before saving.", comment: "Voice recurrence warning"))
        }
        if VoiceVocabulary.contains(["attach a photo", "attach receipt", "прикрепи", "прикрепить"], in: datedCommand) {
            warnings.append(AppLocalization.string("Add any photos or files in the review form before saving.", comment: "Voice attachment warning"))
        }
        let accountRanges = ["на счет", "на счёт", "bank account"].flatMap { VoiceVocabulary.matches($0, in: datedCommand) }
        let billCommand = VoiceVocabulary.mask(datedCommand, ranges: accountRanges)
        let isBill = VoiceVocabulary.contains(VoiceVocabulary.bills, in: billCommand)
            && !VoiceVocabulary.contains(VoiceVocabulary.noBill, in: billCommand)
        return Result(amount: amount, currency: currencyValue, type: type, categoryID: categoryID,
                      isBill: isBill, note: note, reviewMessage: warnings.isEmpty ? nil : warnings.joined(separator: "\n\n"), date: date)
    }

    private static func moneySpacing(_ text: String) -> String {
        // Speech and typed commands may attach ISO codes directly to amounts.
        let codes = Locale.commonISOCurrencyCodes.sorted().joined(separator: "|")
        let before = "(?<=\\d)(?=(?:" + codes + ")(?![A-Za-z]))"
        let after = "(?<![A-Za-z])(" + codes + ")(?=\\d)"
        return text.replacingOccurrences(of: before, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: after, with: "$1 ", options: [.regularExpression, .caseInsensitive])
    }

    private static func relativeDate(in text: String, now: Date, calendar: Calendar) throws -> (Date, [NSRange]) {
        let aliases: [(Int, [String])] = [
            (-2, ["day before yesterday", "позавчера", "srağagün"]),
            (-1, ["yesterday", "вчера", "dün", "dünən"]), (0, ["today", "сегодня", "bu gün", "bugün"]),
            (1, ["tomorrow", "завтра", "sabah"])
        ]
        let all = aliases.flatMap { offset, phrases in phrases.flatMap { phrase in VoiceVocabulary.matches(phrase, in: text).map { (offset: offset, range: $0) } } }
        let specific = all.filter { short in !all.contains { long in long.range.length > short.range.length && NSIntersectionRange(long.range, short.range) == short.range } }
        let offsets = Set(specific.map { $0.offset })
        guard offsets.count <= 1 else { throw ParseError.ambiguousDate }
        guard !VoiceVocabulary.contains(["last week", "last month", "next week", "next month", "last year", "next year", "on Monday", "on Tuesday", "on Wednesday", "on Thursday", "on Friday", "on Saturday", "on Sunday", "на прошлой неделе", "в прошлом месяце", "в следующем месяце", "через неделю", "в понедельник", "во вторник", "в среду", "в четверг", "в пятницу", "в субботу", "в воскресенье", "keçən həftə", "gələn həftə", "gələn ay"], in: text) else { throw ParseError.unsupportedDate }
        return (calendar.date(byAdding: .day, value: offsets.first ?? 0, to: now) ?? now, specific.map { $0.range })
    }

    private static func resolveCurrency(in text: String, fallback: Currency, localeID: String?) throws -> (currency: Currency, explicit: Bool) {
        var mentions: [(code: String, range: NSRange)] = []
        let supported = Set(Locale.commonISOCurrencyCodes)
        let locales = [localeID ?? "en", "en", "ru", "az"].map(Locale.init(identifier:))
        for code in supported {
            let localizedNames = locales.compactMap { $0.localizedString(forCurrencyCode: code) }
            let englishName = Locale(identifier: "en").localizedString(forCurrencyCode: code)
            let plural = englishName.flatMap { name -> String? in
                let last = VoiceVocabulary.tokens(name).last ?? ""
                return ["dollar", "pound", "franc", "dirham", "rupee", "dinar", "peso", "ruble", "rouble", "shilling", "riyal"].contains(last) ? name + "s" : nil
            }
            let names = (VoiceVocabulary.units[code] ?? []) + localizedNames + (plural.map { [$0] } ?? [])
            for name in Set(names) where VoiceVocabulary.normalized(name) != code.lowercased() {
                let genericDollar = code == "USD" && ["dollar", "dollars", "доллар", "доллара", "долларов"].contains(VoiceVocabulary.normalized(name))
                let dollarCodes: Set<String> = ["USD", "CAD", "AUD", "NZD", "HKD", "SGD", "MXN", "TWD", "XCD"]
                let resolved = genericDollar && dollarCodes.contains(fallback.rawValue) ? fallback.rawValue : code
                mentions += VoiceVocabulary.matches(name, in: text).map { (resolved, $0) }
            }
            for range in VoiceVocabulary.matches(code, in: text) {
                let literal = (text as NSString).substring(with: range)
                // Common words are also ISO codes: “try”, “all”, “mad”, etc.
                let common = ["TRY", "ALL", "MAD", "TOP", "PEN", "GEL", "BAM", "SLL", "CUP", "MOP", "BOB", "SOS"]
                let prefix = (text as NSString).substring(to: range.location).trimmingCharacters(in: .whitespacesAndNewlines)
                let lastAmount = common.contains(code) ? try spokenAmounts(in: prefix, localeID: localeID).last : nil
                let followsAmount = lastAmount.map { NSMaxRange($0.range) == (prefix as NSString).length } ?? false
                if !common.contains(code) || literal == code || followsAmount { mentions.append((code, range)) }
            }
        }
        let specific = mentions.filter { short in !mentions.contains { long in long.code != short.code && long.range.length > short.range.length && NSIntersectionRange(long.range, short.range) == short.range } }
        var codes = Set(specific.map { $0.code })
        let symbols: [(String, String)] = [("CA$", "CAD"), ("C$", "CAD"), ("AU$", "AUD"), ("A$", "AUD"), ("NZ$", "NZD"), ("HK$", "HKD"), ("US$", "USD"), ("SG$", "SGD"), ("₼", "AZN"), ("€", "EUR"), ("₽", "RUB"), ("₺", "TRY"), ("₾", "GEL"), ("£", "GBP"), ("₹", "INR"), ("₩", "KRW"), ("₸", "KZT"), ("₴", "UAH")]
        var rest = text
        for (symbol, code) in symbols where rest.range(of: symbol, options: .caseInsensitive) != nil {
            codes.insert(code)
            rest = rest.replacingOccurrences(of: symbol, with: "", options: .caseInsensitive)
        }
        if rest.contains("$") {
            let dollarCodes: Set<String> = ["USD", "CAD", "AUD", "NZD", "HKD", "SGD", "MXN", "TWD", "XCD"]
            let explicitDollars = codes.intersection(dollarCodes)
            if explicitDollars.isEmpty { codes.insert(dollarCodes.contains(fallback.rawValue) ? fallback.rawValue : "USD") }
        }
        if rest.contains("¥") {
            if codes.intersection(["JPY", "CNY"]).isEmpty {
                guard ["JPY", "CNY"].contains(fallback.rawValue) else { throw ParseError.ambiguousCurrency }
                codes.insert(fallback.rawValue)
            }
        }
        let minorCodes = Set(VoiceVocabulary.minorUnits.filter { VoiceVocabulary.contains($0.value, in: text) }.map { $0.key })
        if codes.isEmpty { codes = minorCodes }
        guard codes.count <= 1 else { throw ParseError.ambiguousCurrency }
        return (codes.first.flatMap(Currency.init(rawValue:)) ?? fallback, !codes.isEmpty)
    }

    /// Numeric and spoken amounts share one scan, so mixed-language or
    /// mixed numeric/spoken commands cannot silently discard a second amount.
    private static func spokenAmounts(in text: String, localeID: String?) throws -> [(value: Decimal, range: NSRange)] {
        let source = text.lowercased()
        let range = NSRange(source.startIndex..., in: source)
        let numberPattern = #"(?<![\p{L}\d.,])([-−]?(?:\d{1,3}(?:[ \u00A0\u202F]\d{3})+|\d+)(?:[.,]\d+)*)(?:\s*(тысяч(?:а|и|у)?|тыс\.?|thousand|миллион(?:а|ов)?|million|milyon|min))?(?![\p{L}\d]|[.,]\d)"#
        guard source.range(of: #"\d[.,]{2,}\d"#, options: .regularExpression) == nil else { throw ParseError.invalidAmount }
        let numeric = try NSRegularExpression(pattern: numberPattern).matches(in: source, range: range)
        var amounts = try numeric.map { match -> (value: Decimal, range: NSRange) in
            guard let valueRange = Range(match.range(at: 1), in: source) else { throw ParseError.invalidAmount }
            var value = try numericAmount(String(source[valueRange]), localeID: localeID)
            if let scaleRange = Range(match.range(at: 2), in: source) {
                let scale = source[scaleRange]
                value *= ["million", "milyon"].contains(String(scale)) || scale.hasPrefix("миллион") ? 1_000_000 : 1_000
            }
            return (value, match.range)
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
                        amounts.append((number.decimalValue, span))
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
        return amounts.sorted { $0.range.location < $1.range.location }
    }

    private static func numericAmount(_ raw: String, localeID: String?) throws -> Decimal {
        let text = raw.filter { !$0.isWhitespace }.replacingOccurrences(of: "−", with: "-")
        let marks = text.filter { $0 == "." || $0 == "," }
        func grouped(_ value: String, separator: Character) -> String? {
            let signed = value.hasPrefix("-")
            let unsigned = signed ? String(value.dropFirst()) : value
            let groups = unsigned.split(separator: separator, omittingEmptySubsequences: false)
            guard let first = groups.first, (1...3).contains(first.count), first.allSatisfy({ $0.isNumber }),
                  groups.dropFirst().allSatisfy({ $0.count == 3 && $0.allSatisfy { $0.isNumber } }) else { return nil }
            return (signed ? "-" : "") + groups.joined()
        }
        let normalized: String
        if Set(marks).count == 2 {
            let mark = marks.last!
            let index = text.lastIndex(of: mark)!
            let fraction = String(text[text.index(after: index)...])
            let integer = String(text[..<index])
            let grouping: Character = mark == "." ? "," : "."
            guard (1...2).contains(fraction.count), fraction.allSatisfy({ $0.isNumber }), !integer.contains(mark),
                  let whole = grouped(integer, separator: grouping) else { throw ParseError.invalidAmount }
            normalized = whole + "." + fraction
        } else if let mark = marks.first {
            let parts = text.split(separator: mark, omittingEmptySubsequences: false)
            if marks.count > 1 {
                guard let whole = grouped(text, separator: mark) else { throw ParseError.invalidAmount }
                normalized = whole
            } else if let fraction = parts.last, (1...2).contains(fraction.count) {
                normalized = text.replacingOccurrences(of: String(mark), with: ".")
            } else {
                // A lone 3-digit suffix is grouping only when the chosen
                // speech locale says so. Never turn “5,000” into 5 silently.
                guard let localeID, Locale(identifier: localeID).groupingSeparator == String(mark),
                      let whole = grouped(text, separator: mark) else { throw ParseError.invalidAmount }
                normalized = whole
            }
        } else { normalized = text }
        guard let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else { throw ParseError.invalidAmount }
        return amount
    }

    static func recognitionHints(categories: [TransactionCategory], localeID: String) -> [String] {
        let language = Locale(identifier: localeID).language.languageCode?.identifier ?? "en"
        let core: [String]
        switch language {
        case "ru": core = ["доход", "расход", "входящие", "пять тысяч манат", "десять евро", "добавь в биллс", "вчера", "сегодня", "гяпик"]
        case "az": core = ["gəlir", "xərc", "beş manat", "qəpik", "qəbz", "dün", "bu gün"]
        default: core = ["income", "expense", "ten USD", "add to bill", "five dollars", "cents", "yesterday", "today"]
        }
        // Give every visible category a preferred-language term before adding
        // synonyms, so a long first category cannot crowd out the rest.
        let primary = categories.map { category in VoiceVocabulary.categories[category.id]?.preferred(language).first ?? category.name }
        let exactNames = categories.flatMap { [$0.name, $0.localizedName] }
        let units = ["AZN", "USD", "EUR", "RUB", "TRY", "GEL", "GBP", "AED"].flatMap { code in
            [code] + (Locale(identifier: localeID).localizedString(forCurrencyCode: code).map { [$0] } ?? [])
        }
        let aliases = categories.flatMap { VoiceVocabulary.categories[$0.id]?.preferred(language) ?? [] }
        var seen = Set<String>()
        return Array((core + primary + exactNames + units + aliases).filter { !$0.isEmpty && seen.insert(VoiceVocabulary.normalized($0)).inserted }.prefix(100))
    }

    enum ParseError: LocalizedError {
        case invalidAmount, ambiguousType, ambiguousCurrency, ambiguousDate, unsupportedDate, unsupportedAction
        var errorDescription: String? {
            switch self {
            case .invalidAmount: return AppLocalization.string("Say one positive amount with up to two decimal places, or type it below.", comment: "Voice entry feedback")
            case .ambiguousType: return AppLocalization.string("Say either income or expense for one entry.", comment: "Voice entry feedback")
            case .ambiguousDate: return AppLocalization.string("More than one date was mentioned. Use one date per entry.", comment: "Voice date error")
            case .unsupportedDate: return AppLocalization.string("Use today, yesterday or tomorrow, or set the date in the review form.", comment: "Voice date error")
            case .unsupportedAction: return AppLocalization.string("Voice currently supports adding income, expenses and Bills only.", comment: "Unsupported voice action")
            case .ambiguousCurrency: return AppLocalization.string("Use one currency per entry.", comment: "Voice entry feedback")
            }
        }
    }
}
