import Foundation

enum Currency: String, Codable, CaseIterable, Identifiable {
    case azn = "AZN"
    case usd = "USD"
    case eur = "EUR"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .azn: return "₼"
        case .usd: return "$"
        case .eur: return "€"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .azn: return "az_AZ"
        case .usd: return "en_US"
        case .eur: return "de_DE"
        }
    }
}

struct SavingsGoal: Codable, Hashable {
    var targetAmount: Double
    var currentSavedAmount: Double
    var useAmountLeftForProgress: Bool

    static let `default` = SavingsGoal(targetAmount: 1_000, currentSavedAmount: 0, useAmountLeftForProgress: true)
}

struct AppSettings: Codable, Hashable {
    var currency: Currency
    var monthStartDay: Int
    var savingsGoal: SavingsGoal

    static let `default` = AppSettings(currency: .usd, monthStartDay: 1, savingsGoal: .default)
}

struct AppState: Codable {
    var transactions: [Transaction]
    var settings: AppSettings
    var selectedPeriodAnchorDate: Date

    static let `default` = AppState(
        transactions: [],
        settings: .default,
        selectedPeriodAnchorDate: Date()
    )
}

struct TransactionFilter {
    var categoryID: String?
    var type: TransactionType?
    var dateInterval: DateInterval?
    var searchText: String = ""

    var isActive: Bool {
        categoryID != nil || type != nil || dateInterval != nil || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let empty = TransactionFilter()
}
