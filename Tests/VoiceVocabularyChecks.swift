// Domain coverage is driven by the actual built-in category list.
precondition(Set(VoiceVocabulary.categories.keys) == Set(DefaultCategories.all.map { $0.id }))
for category in DefaultCategories.all {
    for language in ["en", "ru", "az"] {
        let alias = VoiceVocabulary.categories[category.id]!.preferred(language)[0]
        let result = try VoiceEntryParser.parse("10 AZN " + alias, currency: .azn, categories: DefaultCategories.all, localeID: language)
        precondition(result.categoryID == category.id, "Category coverage failed: \(language) \(alias) => \(result.categoryID)")
        precondition((result.type == .income) == (category.kind == .income), "Income inference failed")
    }
}
print("PASS all built-in categories in English, Russian and Azerbaijani")

func domainCheck(_ text: String, amount: String, code: String, category: String, income: Bool = false, bill: Bool = false, fallback: Currency = .azn) throws {
    let result = try VoiceEntryParser.parse(text, currency: fallback, categories: DefaultCategories.all)
    precondition(result.amount == Decimal(string: amount)! && result.currency.rawValue == code && result.categoryID == category && (result.type == .income) == income && result.isBill == bill, "Failed: \(text) => \(result)")
    print("PASS domain: \(text)")
}
try domainCheck("freelance 150 USD", amount: "150", code: "USD", category: "freelance", income: true)
try domainCheck("премия 100 манат", amount: "100", code: "AZN", category: "bonus", income: true)
try domainCheck("paid 50 USD salary", amount: "50", code: "USD", category: "other")
try domainCheck("10 рублей аптека", amount: "10", code: "RUB", category: "pharmacy")
try domainCheck("20 lira fuel", amount: "20", code: "TRY", category: "fuel")
try domainCheck("30 lari restaurant", amount: "30", code: "GEL", category: "restaurant")
try domainCheck("40 pounds education", amount: "40", code: "GBP", category: "education")
try domainCheck("50 dirham pet", amount: "50", code: "AED", category: "pet")
try domainCheck("10 Canadian dollars groceries", amount: "10", code: "CAD", category: "groceries")
try domainCheck("CA$10 groceries", amount: "10", code: "CAD", category: "groceries")
try domainCheck("10 Australian dollars groceries", amount: "10", code: "AUD", category: "groceries")
try domainCheck("€10 cafe", amount: "10", code: "EUR", category: "cafe")
try domainCheck("10USD cafe", amount: "10", code: "USD", category: "cafe")
try domainCheck("USD10 cafe", amount: "10", code: "USD", category: "cafe")
try domainCheck("try 10 USD for all shopping", amount: "10", code: "USD", category: "shopping")
try domainCheck("10 TRY shopping", amount: "10", code: "TRY", category: "shopping")
try domainCheck("5 dollars groceries", amount: "5", code: "CAD", category: "groceries", fallback: Currency(rawValue: "CAD")!)
try domainCheck("$5 groceries", amount: "5", code: "CAD", category: "groceries", fallback: Currency(rawValue: "CAD")!)
try domainCheck("5 US dollars groceries", amount: "5", code: "USD", category: "groceries", fallback: Currency(rawValue: "CAD")!)
try domainCheck("five dollars fifty cents cafe", amount: "5.50", code: "USD", category: "cafe")
try domainCheck("five USD 50 cents cafe", amount: "5.50", code: "USD", category: "cafe")
try domainCheck("5 manat 50 qəpik kafe", amount: "5.50", code: "AZN", category: "cafe")
try domainCheck("пять манат пятьдесят гяпиков кафе", amount: "5.50", code: "AZN", category: "cafe")
try domainCheck("50 qəpik kafe", amount: "0.50", code: "AZN", category: "cafe")
try domainCheck("50 pence cafe", amount: "0.50", code: "GBP", category: "cafe")
try domainCheck("5 GBP 50 pence cafe", amount: "5.50", code: "GBP", category: "cafe")
try domainCheck("10 cafe not a bill", amount: "10", code: "AZN", category: "cafe")
try domainCheck("10 кафе не добавляй в счета", amount: "10", code: "AZN", category: "cafe")
try domainCheck("10 cafe qəbz deyil", amount: "10", code: "AZN", category: "cafe")
try domainCheck("income 100 на счет", amount: "100", code: "AZN", category: "other", income: true)
try domainCheck("10 utilities invoice", amount: "10", code: "AZN", category: "utility", bill: true)

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(secondsFromGMT: 0)!
let reference = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
for (phrase, offset) in [("yesterday", -1), ("day before yesterday", -2), ("tomorrow", 1), ("вчера", -1), ("позавчера", -2), ("dün", -1), ("dünən", -1), ("bu gün", 0), ("sabah", 1)] {
    let result = try VoiceEntryParser.parse("10 cafe " + phrase, currency: .azn, categories: DefaultCategories.all, now: reference, calendar: cal)
    precondition(cal.isDate(result.date, inSameDayAs: cal.date(byAdding: .day, value: offset, to: reference)!))
}
print("PASS relative dates including year boundaries")
let note = try VoiceEntryParser.parse("10 USD cafe note invoice 123 received 500 EUR yesterday", currency: .azn, categories: DefaultCategories.all, now: reference, calendar: cal)
precondition(note.amount == 10 && note.currency == .usd && note.type == .expense && note.note == "invoice 123 received 500 EUR yesterday" && note.date == reference)
print("PASS note contents do not change amount, currency, date or type")
let customs: [TransactionCategory] = [
    .init(id: "refund", name: "Refund", icon: "", kind: .income, isCustom: true),
    .init(id: "seven", name: "7 Eleven", icon: "", kind: .expense, isCustom: true),
    .init(id: "five", name: "Five Guys", icon: "", kind: .expense, isCustom: true),
    .init(id: "tomorrow", name: "Tomorrow", icon: "", kind: .expense, isCustom: true),
    .init(id: "home-insurance", name: "Home insurance", icon: "", kind: .expense, isCustom: true)
]
for (phrase, id) in [("10 refund", "refund"), ("10 at 7 Eleven", "seven"), ("10 at Five Guys", "five"), ("10 at Tomorrow", "tomorrow"), ("10 home insurance", "home-insurance")] {
    let result = try VoiceEntryParser.parse(phrase, currency: .azn, categories: DefaultCategories.all + customs, now: reference, calendar: cal)
    precondition(result.categoryID == id && result.amount == 10 && result.date == reference)
}
print("PASS custom category names, numbers, income and overlapping names")
for phrase in ["10 loan payment", "10 savings", "10 rent every month", "10 cafe attach a photo"] {
    let result = try VoiceEntryParser.parse(phrase, currency: .azn, categories: DefaultCategories.all)
    precondition(result.reviewMessage != nil)
}
print("PASS linked balances, repeat and attachment requests are flagged for review")
for phrase in ["create a loan 500", "добавь кредит 500", "create a savings goal 500", "remind me 10 cafe", "delete 10 cafe", "transfer 100 USD", "10 cafe yesterday tomorrow", "10 cafe last week", "50 cents 5 dollars cafe", "5 50 dollars cents cafe", "5 manat 50 cents cafe", "5 USD 150 cents cafe", "¥10 cafe"] {
    do { _ = try VoiceEntryParser.parse(phrase, currency: .azn, categories: DefaultCategories.all); fatalError("Should reject: \(phrase)") }
    catch { print("PASS domain rejection: \(phrase)") }
}
let excluded = DefaultCategories.all.filter { $0.id != "pharmacy" }
let hidden = try VoiceEntryParser.parse("10 pharmacy", currency: .azn, categories: excluded)
precondition(hidden.categoryID == "other")
for language in ["en-US", "ru-RU", "az-AZ"] {
    let hints = VoiceEntryParser.recognitionHints(categories: DefaultCategories.all + customs, localeID: language)
    precondition(hints.count <= 100 && hints.contains("7 Eleven"))
    for category in DefaultCategories.all {
        let code = Locale(identifier: language).language.languageCode!.identifier
        precondition(hints.contains(VoiceVocabulary.categories[category.id]!.preferred(code)[0]))
    }
}
print("PASS hidden categories excluded and all built-in categories represented in speech hints")

try domainCheck("10 Singapore dollars groceries", amount: "10", code: "SGD", category: "groceries")
try domainCheck("10 Hong Kong dollars groceries", amount: "10", code: "HKD", category: "groceries")
try domainCheck("ten try shopping", amount: "10", code: "TRY", category: "shopping")
try domainCheck("10 coffee in a cup", amount: "10", code: "AZN", category: "cafe")
try domainCheck("10 cafe not income", amount: "10", code: "AZN", category: "cafe")
try domainCheck("100 salary not an expense", amount: "100", code: "AZN", category: "salary", income: true)
try domainCheck("100 зарплата не расход", amount: "100", code: "AZN", category: "salary", income: true)
for phrase in ["10 cafe next month", "10 cafe on Monday", "10 cafe not income not expense"] {
    do { _ = try VoiceEntryParser.parse(phrase, currency: .azn, categories: DefaultCategories.all); fatalError("Should reject: \(phrase)") }
    catch { print("PASS domain rejection: \(phrase)") }
}

for (phrase, language, expected) in [("1,250.50 USD cafe", "en-US", "1250.50"), ("1.250,50 EUR cafe", "ru-RU", "1250.50"), ("5,000 USD cafe", "en-US", "5000"), ("5.000 AZN cafe", "az-AZ", "5000"), ("1,000,000 USD cafe", "en-US", "1000000")] {
    let result = try VoiceEntryParser.parse(phrase, currency: .azn, categories: DefaultCategories.all, localeID: language)
    precondition(result.amount == Decimal(string: expected)!, "Money format: \(phrase)")
}
print("PASS locale-aware grouping and mixed-separator decimals")
for phrase in ["1.000 USD cafe", "1..5 USD cafe", "1.2345 USD cafe", "10 USD and 1.2345 USD cafe", "1,25,000 USD cafe"] {
    do { _ = try VoiceEntryParser.parse(phrase, currency: .azn, categories: DefaultCategories.all, localeID: "en-US"); fatalError("Should reject: \(phrase)") }
    catch { print("PASS precision rejection: \(phrase)") }
}
let punctuated = try VoiceEntryParser.parse("10 cafe note: #invoice123!", currency: .azn, categories: DefaultCategories.all)
precondition(punctuated.note == "#invoice123!")
try domainCheck("10 cafe без чека", amount: "10", code: "AZN", category: "cafe")
print("PASS note punctuation is preserved")

for phrase in ["update 10 cafe", "edit 100 salary", "измени 10 кафе", "покажи баланс 100", "show balance 100"] {
    do { _ = try VoiceEntryParser.parse(phrase, currency: .azn, categories: DefaultCategories.all); fatalError("Should reject: \(phrase)") }
    catch { print("PASS unsupported operation: \(phrase)") }
}
