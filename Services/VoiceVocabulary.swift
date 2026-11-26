import Foundation

/// Shared by recognition hints and parsing; vocabulary must not drift between them.
enum VoiceVocabulary {
    struct CategoryTerms {
        let en: [String]
        let ru: [String]
        let az: [String]
        init(_ en: [String], _ ru: [String], _ az: [String]) { self.en = en; self.ru = ru; self.az = az }
        var all: [String] { en + ru + az }
        func preferred(_ language: String) -> [String] { language == "ru" ? ru : language == "az" ? az : en }
    }
    static let categories: [String: CategoryTerms] = [
        "groceries": .init(["groceries", "grocery", "supermarket"], ["продукты", "продуктов", "продуктам", "супермаркет"], ["ərzaq", "ərzağa", "market"]),
        "home": .init(["home", "household"], ["дом", "дома", "дому", "быт"], ["ev", "evə", "məişət"]),
        "gift": .init(["gift", "gifts", "present"], ["подарок", "подарки", "подарков"], ["hədiyyə", "hədiyyələr"]),
        "utility": .init(["utilities", "utility", "electricity", "water bill", "internet"], ["коммунальные", "коммуналка", "коммуналку", "электричество", "интернет"], ["kommunal", "elektrik", "internet", "su pulu"]),
        "shopping": .init(["shopping", "clothes", "clothing"], ["покупки", "покупок", "шоппинг", "одежда", "одежду"], ["alış-veriş", "alışveriş", "geyim"]),
        "transport": .init(["transport", "transportation", "transit", "taxi", "bus", "metro"], ["транспорт", "транспорта", "транспорте", "такси", "автобус", "метро"], ["nəqliyyat", "taksi", "avtobus", "metro"]),
        "health": .init(["health", "healthcare", "doctor", "medical"], ["здоровье", "здоровья", "врач", "врача", "медицина"], ["sağlamlıq", "həkim", "tibb"]),
        "entertainment": .init(["entertainment", "cinema", "movie", "concert"], ["развлечения", "развлечений", "кино", "концерт"], ["əyləncə", "kino", "konsert"]),
        "restaurant": .init(["restaurant", "dining", "dinner"], ["ресторан", "ресторане", "ресторана", "ужин"], ["restoran", "restoranda", "şam yeməyi"]),
        "cafe": .init(["cafe", "coffee", "coffee shop"], ["кафе", "кофе", "кофейня"], ["kafe", "kafedə", "kafeda", "qəhvə"]),
        "travel": .init(["travel", "trip", "holiday", "hotel", "flight"], ["путешествия", "путешествие", "поездка", "поездку", "отель", "перелет"], ["səyahət", "səfər", "otel", "uçuş"]),
        "kids": .init(["kids", "children", "childcare"], ["дети", "детей", "ребенок", "ребенка"], ["uşaq", "uşaqlar", "uşaqlara"]),
        "education": .init(["education", "tuition", "school", "course"], ["образование", "учеба", "учебу", "школа", "курсы"], ["təhsil", "məktəb", "kurs"]),
        "salary": .init(["salary", "wages", "paycheck"], ["зарплата", "зарплату", "зарплаты", "заработная плата"], ["maaş", "əmək haqqı"]),
        "freelance": .init(["freelance", "freelancing", "freelancer"], ["фриланс", "фриланса", "подработка", "подработку"], ["frilans", "freelance", "sərbəst iş"]),
        "bonus": .init(["bonus", "bonuses"], ["бонус", "бонусы", "премия", "премию"], ["bonus", "mükafat"]),
        "savings": .init(["savings", "saving"], ["накопления", "сбережения"], ["yığım", "əmanət"]),
        "subscription": .init(["subscription", "subscriptions", "membership"], ["подписка", "подписки", "подписку", "абонемент"], ["abunə", "abunəlik"]),
        "rent": .init(["rent", "rental"], ["аренда", "аренду", "аренды"], ["kirayə", "kirayəyə"]),
        "fuel": .init(["fuel", "petrol", "gasoline", "gas station"], ["топливо", "бензин", "заправка", "заправку"], ["yanacaq", "benzin"]),
        "pharmacy": .init(["pharmacy", "medicine", "medication", "drugstore"], ["аптека", "аптеку", "лекарства", "лекарств"], ["aptek", "aptekdə", "dərman"]),
        "pet": .init(["pet", "pets", "vet", "pet food"], ["питомец", "питомцы", "питомцев", "ветеринар", "корм"], ["ev heyvanı", "heyvan", "baytar"]),
        "loan": .init(["loan", "loan payment", "instalment", "installment"], ["кредит", "кредита", "платеж по кредиту"], ["kredit", "kredit ödənişi"]),
        "other": .init(["other", "miscellaneous"], ["другое", "прочее"], ["digər", "başqa"])
    ]
    static let income = ["income", "incomes", "incoming", "received", "earned", "доход", "доходы", "дохода", "входящие", "входящий", "входящую", "поступление", "поступления", "зачисление", "получил", "получила", "заработал", "заработала", "инком", "инкам", "gəlir", "qazanc", "qazandım"]
    static let expense = ["expense", "expenses", "spent", "spending", "outgoing", "paid", "расход", "расходы", "расхода", "исходящие", "трата", "трату", "потратила", "потратил", "заплатил", "заплатила", "оплатил", "оплатила", "xərc", "xərclədim", "ödədim"]
    static let bills = ["bill", "bills", "receipt", "invoice", "билл", "биллс", "счет", "счета", "чек", "чеки", "qəbz", "faktura"]
    static let noBill = ["not a bill", "not bill", "not an invoice", "not a check", "do not mark as bill", "don't mark as bill", "without receipt", "not a receipt", "do not add to bills", "don't add to bills", "without a bill", "не добавляй в счета", "не добавляй в биллс", "без счета", "без чека", "не помечай как счет", "не помечай как чек", "не в счета", "не счет", "не чек", "qəbz deyil", "bills deyil"]
    static let unsupported = ["create a loan", "add a loan", "add loan", "take a loan", "borrow", "create a savings goal", "add a savings goal", "new savings goal", "remind me", "set a reminder", "delete", "remove entry", "edit", "update", "change amount", "show my balance", "show balance", "what is my balance", "transfer", "convert currency", "создай кредит", "добавь кредит", "взять кредит", "новый кредит", "создай цель", "добавь цель", "новая цель", "напомни", "удали", "измени", "исправь", "покажи", "переведи", "конвертируй", "kredit yarat", "yığım məqsədi yarat", "xatırlat", "qeydi sil", "köçür"]
    static let repeats = ["daily", "weekly", "monthly", "yearly", "every day", "every week", "every month", "every year", "repeat", "ежедневно", "еженедельно", "ежемесячно", "ежегодно", "каждый день", "каждую неделю", "каждый месяц", "каждый год", "повторять", "hər gün", "hər həftə", "hər ay", "hər il"]
    static let units: [String: [String]] = [
        "AZN": ["manat", "manats", "манат", "маната", "манатов"],
        "USD": ["dollar", "dollars", "US dollar", "US dollars", "доллар", "доллара", "долларов"],
        "EUR": ["euro", "euros", "евро", "avro"],
        "RUB": ["ruble", "rubles", "rouble", "roubles", "рубль", "рубля", "рублей", "rubl"],
        "TRY": ["Turkish lira", "lira", "liras", "лира", "лиры", "лир", "турецких лир", "lirə"],
        "GEL": ["lari", "лари"],
        "GBP": ["pound", "pounds", "sterling", "фунт", "фунта", "фунтов", "funt"],
        "AED": ["dirham", "dirhams", "дирхам", "дирхама", "дирхамов", "dirhəm"],
        "CAD": ["Canadian dollar", "Canadian dollars", "канадских долларов"],
        "AUD": ["Australian dollar", "Australian dollars", "австралийских долларов"],
        "NZD": ["New Zealand dollar", "New Zealand dollars"],
        "JPY": ["yen", "иена", "иены", "иен"],
        "CNY": ["yuan", "юань", "юаня", "юаней"],
        "CHF": ["Swiss franc", "Swiss francs", "швейцарских франков"],
        "KZT": ["tenge", "тенге"], "UAH": ["hryvnia", "гривна", "гривен"]
    ]
    static let minorUnits: [String: [String]] = [
        "AZN": ["qəpik", "qəpiyə", "гяпик", "гяпиков", "гепик", "гепиков"],
        "RUB": ["kopeck", "kopecks", "копейка", "копейки", "копеек"],
        "GBP": ["pence", "penny", "pennies", "пенс", "пенсов"],
        "TRY": ["kuruş", "kurus", "куруш", "курушей"]
    ]
    static let cents = ["cent", "cents", "цент", "цента", "центов", "sent"]

    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "ə", with: "e").replacingOccurrences(of: "ı", with: "i")
    }
    static func tokens(_ text: String) -> [String] {
        spans(text).map { normalized(($0.text)) }
    }
    private static let tokenPattern = try! NSRegularExpression(pattern: #"[\p{L}\p{N}\p{M}]+"#)
    static func spans(_ text: String) -> [(text: String, range: NSRange)] {
        return tokenPattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
            ((text as NSString).substring(with: $0.range), $0.range)
        }
    }
    static func matches(_ phrase: String, in text: String) -> [NSRange] {
        let source = spans(text)
        let target = tokens(phrase)
        guard !target.isEmpty, target.count <= source.count else { return [] }
        return (0...(source.count - target.count)).compactMap { start in
            guard source[start..<(start + target.count)].map({ normalized($0.text) }) == target else { return nil }
            return NSUnionRange(source[start].range, source[start + target.count - 1].range)
        }
    }
    static func contains(_ phrases: [String], in text: String) -> Bool {
        phrases.contains { !matches($0, in: text).isEmpty }
    }
    static func mask(_ text: String, ranges: [NSRange]) -> String {
        let result = NSMutableString(string: text)
        for range in ranges.sorted(by: { $0.location > $1.location }) {
            result.replaceCharacters(in: range, with: String(repeating: " ", count: range.length))
        }
        return result as String
    }
    struct CategoryMatch { let category: TransactionCategory; let range: NSRange }
    static func categoryMatches(_ text: String, categories visible: [TransactionCategory]) -> [CategoryMatch] {
        let all = visible.flatMap { category in
            ([category.name, category.localizedName] + (categories[category.id]?.all ?? [])).flatMap { alias in
                matches(alias, in: text).map { CategoryMatch(category: category, range: $0) }
            }
        }
        // A specific phrase such as “pet food” wins over an overlapping,
        // generic category named “food”; separate mentions remain ambiguous.
        return all.filter { short in !all.contains { long in
            long.category.id != short.category.id && long.range.length > short.range.length
                && NSIntersectionRange(long.range, short.range) == short.range
        } }
    }
}
