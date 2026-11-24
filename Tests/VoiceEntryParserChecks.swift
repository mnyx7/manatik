let categories: [TransactionCategory] = [
 .init(id: "cafe", name: "Cafe", icon: "", kind: .expense),
 .init(id: "transport", name: "Transport", icon: "", kind: .expense),
 .init(id: "shopping", name: "Shopping", icon: "", kind: .expense),
 .init(id: "salary", name: "Salary", icon: "", kind: .income),
 .init(id: "custom", name: "My hobby", icon: "", kind: .expense, isCustom: true)
]
func check(_ text: String, _ amount: Decimal, _ code: String, _ category: String, _ income: Bool = false, _ bill: Bool = false) throws {
 let r = try VoiceEntryParser.parse(text, currency: .azn, categories: categories)
 precondition(r.amount == amount && r.currency.rawValue == code && r.categoryID == category && (r.type == .income) == income && r.isBill == bill, "Failed: \(text) => \(r)")
 print("PASS: \(text)")
}
try check("пять манат в кафе добавь в биллс", 5, "AZN", "cafe", false, true)
try check("income salary 100 USD", 100, "USD", "salary", true)
try check("five manat cafe bills", 5, "AZN", "cafe", false, true)
try check("12,50 euro cafe", Decimal(string: "12.50")!, "EUR", "cafe")
try check("20 my hobby", 20, "AZN", "custom")
try check("25 unknown", 25, "AZN", "other")
for text in ["0 cafe", "-5 cafe", "10 cafe 20 taxi", "100 USD EUR", "income expense 5", "cafe", "1.234 cafe"] {
 do { _ = try VoiceEntryParser.parse(text, currency: .azn, categories: categories); fatalError("Should reject: \(text)") }
 catch { print("PASS rejection: \(text)") }
}
try check("twenty five manat cafe", 25, "AZN", "cafe")
try check("двадцать пять манат кафе", 25, "AZN", "cafe")

try check("5 $ cafe", 5, "USD", "cafe")
for text in ["minus five cafe", "five cafe ten taxi", "минус пять кафе"] {
 do { _ = try VoiceEntryParser.parse(text, currency: .azn, categories: categories); fatalError("Should reject: \(text)") }
 catch { print("PASS rejection: \(text)") }
}

for (text, locale, amount) in [("vingt-cinq EUR cafe", "fr-FR", Decimal(25)), ("veinticinco EUR cafe", "es-ES", Decimal(25))] {
 let result = try VoiceEntryParser.parse(text, currency: .azn, categories: categories, localeID: locale)
 precondition(result.amount == amount && result.currency == .eur, "Selected locale number parsing failed")
 print("PASS selected speech locale: \(locale)")
}

let azeri = try VoiceEntryParser.parse("gəlir maaş 100 USD", currency: .azn, categories: categories, localeID: "az-AZ")
precondition(azeri.type == .income && azeri.categoryID == "salary")
print("PASS Azerbaijani income")
let cafe = try VoiceEntryParser.parse("Kafedə beş manat", currency: .azn, categories: categories, localeID: "az-AZ")
precondition(cafe.amount == 5 && cafe.categoryID == "cafe")
print("PASS Azerbaijani example")
let catalog = [SpeechLanguage(id: "en-US", supportsOffline: true), SpeechLanguage(id: "ru-RU", supportsOffline: false)]
precondition(SpeechLanguages.resolvedID("en_US", in: catalog) == "en-US")
precondition(SpeechLanguages.defaultID(in: catalog) == "en-US")
precondition(SpeechLanguages.resolvedID("missing", in: catalog) == "en-US")
print("PASS voice language defaults and legacy identifiers")

try check("Ten USD expense for transportation. Add to bill.", 10, "USD", "transport", false, true)
try check("пять manat xərc kafeda", 5, "AZN", "cafe")
try check("десять евро кафе", 10, "EUR", "cafe")
try check("five dollar for shopping", 5, "USD", "shopping")
try check("Добавь доход пять тысяч манат", 5000, "AZN", "other", true)
try check("Добавь 5 тысяч манат во входящие", 5000, "AZN", "other", true)
try check("доход 5 000 манат", 5000, "AZN", "other", true)
try check("доход 5\u{202f}000 манат", 5000, "AZN", "other", true)
try check("one hundred and five USD for shopping", 105, "USD", "shopping")
let transportIncome = try VoiceEntryParser.parse("Добавь пять тысяч манат во входящие категория транспорт", currency: .azn, categories: categories, localeID: "ru-RU")
precondition(transportIncome.amount == 5000 && transportIncome.type == .income && transportIncome.categoryID == "other" && transportIncome.reviewMessage != nil)
print("PASS explicit income preserved and incompatible category flagged")
let compatibleTransport: [TransactionCategory] = [.init(id: "custom-transport", name: "Транспорт", icon: "", kind: .both)]
let both = try VoiceEntryParser.parse("пять тысяч манат во входящие категория транспорт", currency: .azn, categories: compatibleTransport, localeID: "ru-RU")
precondition(both.categoryID == "custom-transport" && both.type == .income && both.reviewMessage == nil)
print("PASS income-compatible custom category")
for text in ["5 manat and ten manat", "пять manat and ten manat", "десять евро кафе five dollar for shopping", "пять thousand manat", ".5 cafe", "−5 cafe"] {
 do { _ = try VoiceEntryParser.parse(text, currency: .azn, categories: categories); fatalError("Should reject: \(text)") }
 catch { print("PASS rejection: \(text)") }
}
let hints = VoiceEntryParser.recognitionHints(categories: categories + [.init(id: "custom-brand", name: "My special shop", icon: "", kind: .expense)], localeID: "ru-RU")
precondition(hints.contains("пять тысяч манат") && hints.contains("My special shop") && hints.count <= 100)
print("PASS financial and custom-category speech hints")

try check("five USD on shopping", 5, "USD", "shopping")
let azTen = try VoiceEntryParser.parse("on manat kafedə", currency: .azn, categories: categories, localeID: "az-AZ")
precondition(azTen.amount == 10 && azTen.categoryID == "cafe")
print("PASS Azerbaijani ten and English preposition stay distinct")
