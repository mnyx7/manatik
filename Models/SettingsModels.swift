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

struct SavingsGoal: Codable, Hashable {
    var targetAmount: Decimal
    var currentSavedAmount: Decimal
    /// When true the goal tracks what is left over this period. When false it
    /// tracks `currentSavedAmount`, a figure the user maintains by hand.
    var useAmountLeftForProgress: Bool

    static let `default` = SavingsGoal(
        targetAmount: 1_000,
        currentSavedAmount: 0,
        useAmountLeftForProgress: true
    )

    /// Lowest target that still makes a percentage meaningful.
    static let minimumTarget = Decimal(1)
}

struct AppSettings: Codable, Hashable {
    var currency: Currency
    /// Day of month a budgeting period begins. Constrained to 1...28 so every
    /// month has the day and periods never overlap or leave gaps.
    var monthStartDay: Int
    var savingsGoal: SavingsGoal

    static let `default` = AppSettings(
        currency: .azn,
        monthStartDay: 1,
        savingsGoal: .default
    )

    mutating func normalize() {
        monthStartDay = DateRangeCalculator.clampMonthStartDay(monthStartDay)
        if savingsGoal.targetAmount < SavingsGoal.minimumTarget {
            savingsGoal.targetAmount = SavingsGoal.minimumTarget
        }
        if savingsGoal.currentSavedAmount < 0 {
            savingsGoal.currentSavedAmount = 0
        }
    }
}

struct AppState: Codable, Hashable {
    var transactions: [Transaction]
    var recurringSeries: [RecurringSeries]
    var paymentReminders: [PaymentReminder]
    var settings: AppSettings

    static let `default` = AppState(
        transactions: [],
        recurringSeries: [],
        paymentReminders: [],
        settings: .default
    )

    init(
        transactions: [Transaction],
        recurringSeries: [RecurringSeries],
        paymentReminders: [PaymentReminder] = [],
        settings: AppSettings
    ) {
        self.transactions = transactions
        self.recurringSeries = recurringSeries
        self.paymentReminders = paymentReminders
        self.settings = settings
    }

    var isEmpty: Bool {
        transactions.isEmpty && recurringSeries.isEmpty
    }

    func series(id: UUID) -> RecurringSeries? {
        recurringSeries.first { $0.id == id }
    }

    func reminder(id: UUID) -> PaymentReminder? {
        paymentReminders.first { $0.id == id }
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

    var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Filters that narrow rows inside whichever range is being browsed.
    var hasRowFilters: Bool {
        categoryID != nil || type != nil || !trimmedSearchText.isEmpty
    }

    var isActive: Bool {
        hasRowFilters || dateInterval != nil
    }

    static let empty = TransactionFilter()
}
