//
//  SettingsModels.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import Foundation

/// An ISO 4217 currency, e.g. "AZN". Encoded as the bare code, which is what
/// the old three-case enum wrote, so existing files decode unchanged.
struct Currency: RawRepresentable, Codable, Hashable, Identifiable, Sendable {
    let rawValue: String

    nonisolated init?(rawValue: String) {
        let code = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count == 3, code.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        self.rawValue = code
    }

    nonisolated private init(code: String) { rawValue = code }

    static let azn = Currency(code: "AZN")
    static let usd = Currency(code: "USD")
    static let eur = Currency(code: "EUR")

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let code = try decoder.singleValueContainer().decode(String.self)
        guard let value = Currency(rawValue: code) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Not a currency code: \(code)")
            )
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Every currency in current use, by name in the user's language.
    static let allCases: [Currency] = Locale.commonISOCurrencyCodes
        .compactMap(Currency.init(rawValue:))
        .filter { Locale.current.localizedString(forCurrencyCode: $0.rawValue) != nil }
        .sorted { $0.localizedName.localizedCaseInsensitiveCompare($1.localizedName) == .orderedAscending }

    /// Offered first in pickers, after the user's own. The neighbours and
    /// travel currencies someone budgeting in manat reaches for most.
    static let suggested: [Currency] = ["AZN", "USD", "EUR", "RUB", "TRY", "GEL", "GBP", "AED"]
        .compactMap(Currency.init(rawValue:))

    /// The short glyph, e.g. "₼" or "₺". The device locale's own symbol wins,
    /// because it keeps lookalikes apart ("CA$" next to "$"). When it only
    /// knows the code ("AZN" on an English phone), the symbol comes from a
    /// locale of the country that uses it.
    var symbol: String { CurrencyFormatting.symbol(for: self) }

    var localizedName: String {
        Locale.current.localizedString(forCurrencyCode: rawValue) ?? rawValue
    }

    static let nativeSymbols: [String: String] = {
        var symbols: [String: String] = ["AZN": "\u{20BC}"]
        for identifier in Locale.availableIdentifiers {
            let locale = Locale(identifier: identifier)
            guard let code = locale.currency?.identifier,
                  let symbol = locale.currencySymbol,
                  symbol != code else { continue }
            // Prefer the shortest, so "$" beats "US$".
            if let existing = symbols[code], existing.count <= symbol.count { continue }
            symbols[code] = symbol
        }
        return symbols
    }()
}

struct AppSettings: Codable, Hashable {
    var currency: Currency
    /// Day of month a budgeting period begins. Constrained to 1...28 so every
    /// month has the day and periods never overlap or leave gaps.
    var monthStartDay: Int
    /// When true the entry form leads with recently used categories. When
    /// false it follows the order set in Settings.
    var showsRecentCategoriesFirst: Bool
    /// Which home page to show. Classic is the default and stays available.
    var homeStyle: HomeStyle
    /// Masks every amount, for using the app where others can see the screen.
    var hidesAmounts: Bool

    static let `default` = AppSettings(
        currency: .azn,
        monthStartDay: 1,
        showsRecentCategoriesFirst: true
    )

    enum CodingKeys: String, CodingKey {
        case currency, monthStartDay, showsRecentCategoriesFirst, homeStyle, hidesAmounts
    }

    init(
        currency: Currency,
        monthStartDay: Int,
        showsRecentCategoriesFirst: Bool = true,
        homeStyle: HomeStyle = .classic,
        hidesAmounts: Bool = false
    ) {
        self.currency = currency
        self.monthStartDay = monthStartDay
        self.showsRecentCategoriesFirst = showsRecentCategoriesFirst
        self.homeStyle = homeStyle
        self.hidesAmounts = hidesAmounts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currency = try container.decodeIfPresent(Currency.self, forKey: .currency) ?? .azn
        monthStartDay = try container.decodeIfPresent(Int.self, forKey: .monthStartDay) ?? 1
        showsRecentCategoriesFirst = try container.decodeIfPresent(
            Bool.self,
            forKey: .showsRecentCategoriesFirst
        ) ?? true
        // An unknown value (a style a later version removed) falls back to
        // Classic instead of failing the whole settings decode.
        homeStyle = (try? container.decodeIfPresent(HomeStyle.self, forKey: .homeStyle)) ?? .classic
        hidesAmounts = try container.decodeIfPresent(Bool.self, forKey: .hidesAmounts) ?? false
    }

    mutating func normalize() {
        monthStartDay = DateRangeCalculator.clampMonthStartDay(monthStartDay)
    }
}

/// A note the user wrote about the app, kept on the device so it can be
/// re-read and shared later rather than lost when the screen closes.
struct FeedbackNote: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    let appVersion: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        appVersion: String = AppVersionProvider.versionText,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.appVersion = appVersion
        self.createdAt = createdAt
    }

    /// What gets shared: the note plus the context that makes it useful.
    var shareableText: String {
        "\(text)\n\n---\nmuna \(appVersion)\n\(DateFormatting.dayMonthYear(createdAt))"
    }
}

struct AppState: Codable, Hashable {
    var transactions: [Transaction]
    var recurringSeries: [RecurringSeries]
    var paymentReminders: [PaymentReminder]
    var customCategories: [TransactionCategory]
    /// The order the user arranged categories in. Ids missing from this list
    /// keep their built-in position, so it does not have to be exhaustive.
    var categoryOrder: [String]
    /// Categories kept out of the pickers without deleting them. Entries that
    /// already use one still resolve it.
    var hiddenCategoryIDs: Set<String>
    var savingsGoals: [SavingsGoal]
    var loans: [Loan]
    var feedbackNotes: [FeedbackNote]
    var settings: AppSettings

    static let `default` = AppState(
        transactions: [],
        recurringSeries: [],
        settings: .default
    )

    init(
        transactions: [Transaction],
        recurringSeries: [RecurringSeries],
        paymentReminders: [PaymentReminder] = [],
        customCategories: [TransactionCategory] = [],
        categoryOrder: [String] = [],
        hiddenCategoryIDs: Set<String> = [],
        savingsGoals: [SavingsGoal] = [],
        loans: [Loan] = [],
        feedbackNotes: [FeedbackNote] = [],
        settings: AppSettings
    ) {
        self.transactions = transactions
        self.recurringSeries = recurringSeries
        self.paymentReminders = paymentReminders
        self.customCategories = customCategories
        self.categoryOrder = categoryOrder
        self.hiddenCategoryIDs = hiddenCategoryIDs
        self.savingsGoals = savingsGoals
        self.loans = loans
        self.feedbackNotes = feedbackNotes
        self.settings = settings
    }

    var isEmpty: Bool {
        transactions.isEmpty && recurringSeries.isEmpty
    }

    /// Files from before entries had their own currency were all in the one
    /// Settings currency, so that is what their entries are pinned to. After
    /// this, changing the Settings currency no longer relabels old entries.
    mutating func pinUntaggedEntriesToMainCurrency() {
        let main = settings.currency
        for index in transactions.indices where transactions[index].currency == nil {
            transactions[index].currency = main
        }
        for index in recurringSeries.indices where recurringSeries[index].currency == nil {
            recurringSeries[index].currency = main
        }
    }

    var hasAnythingAtAll: Bool {
        !isEmpty || !savingsGoals.isEmpty || !loans.isEmpty
    }

    func series(id: UUID) -> RecurringSeries? {
        recurringSeries.first { $0.id == id }
    }

    func reminder(id: UUID) -> PaymentReminder? {
        paymentReminders.first { $0.id == id }
    }

    func savingsGoal(id: UUID) -> SavingsGoal? {
        savingsGoals.first { $0.id == id }
    }

    func loan(id: UUID) -> Loan? {
        loans.first { $0.id == id }
    }
}

struct TransactionFilter: Hashable {
    var categoryID: String?
    var type: TransactionType?
    /// When set, this replaces the selected period as the range being browsed,
    /// so a range outside the current month returns its real results instead of
    /// an unexplained empty list.
    var dateInterval: DateInterval?
    var searchText: String = ""
    /// Restricts to entries bookmarked as bills.
    var onlyFeatured: Bool = false

    var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Filters that narrow rows inside whichever range is being browsed.
    var hasRowFilters: Bool {
        categoryID != nil || type != nil || onlyFeatured || !trimmedSearchText.isEmpty
    }

    var isActive: Bool {
        hasRowFilters || dateInterval != nil
    }

    /// Filters the user set by hand, as opposed to the Activities segment,
    /// which also writes `type` and `onlyFeatured`.
    var hasUserChosenFilters: Bool {
        categoryID != nil || dateInterval != nil || !trimmedSearchText.isEmpty
    }

    static let empty = TransactionFilter()

    mutating func applyScope(_ scope: ActivityScope) {
        type = scope.transactionType
        onlyFeatured = scope.onlyFeatured
    }
}
