import Foundation

enum Currency: String, Codable, CaseIterable, Identifiable {
    case azn = "AZN"
    case usd = "USD"
    case eur = "EUR"

    var id: String { rawValue }

    /// Fallback glyph only. Normal formatting goes through `CurrencyFormatting`,
    /// which renders the symbol using the device locale.
    var symbol: String {
        switch self {
        case .azn: return "\u{20BC}"
        case .usd: return "$"
        case .eur: return "\u{20AC}"
        }
    }

    var localizedName: String {
        switch self {
        case .azn: return NSLocalizedString("Azerbaijani manat", comment: "Currency name")
        case .usd: return NSLocalizedString("US dollar", comment: "Currency name")
        case .eur: return NSLocalizedString("Euro", comment: "Currency name")
        }
    }
}

struct AppSettings: Codable, Hashable {
    var currency: Currency
    /// Day of month a budgeting period begins. Constrained to 1...28 so every
    /// month has the day and periods never overlap or leave gaps.
    var monthStartDay: Int

    static let `default` = AppSettings(currency: .azn, monthStartDay: 1)

    enum CodingKeys: String, CodingKey {
        case currency, monthStartDay
    }

    init(currency: Currency, monthStartDay: Int) {
        self.currency = currency
        self.monthStartDay = monthStartDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currency = try container.decodeIfPresent(Currency.self, forKey: .currency) ?? .azn
        monthStartDay = try container.decodeIfPresent(Int.self, forKey: .monthStartDay) ?? 1
    }

    mutating func normalize() {
        monthStartDay = DateRangeCalculator.clampMonthStartDay(monthStartDay)
    }
}

struct AppState: Codable, Hashable {
    var transactions: [Transaction]
    var recurringSeries: [RecurringSeries]
    var paymentReminders: [PaymentReminder]
    var customCategories: [TransactionCategory]
    var savingsGoals: [SavingsGoal]
    var loans: [Loan]
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
        savingsGoals: [SavingsGoal] = [],
        loans: [Loan] = [],
        settings: AppSettings
    ) {
        self.transactions = transactions
        self.recurringSeries = recurringSeries
        self.paymentReminders = paymentReminders
        self.customCategories = customCategories
        self.savingsGoals = savingsGoals
        self.loans = loans
        self.settings = settings
    }

    var isEmpty: Bool {
        transactions.isEmpty && recurringSeries.isEmpty
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
