import Foundation

enum DefaultCategories {
    static let all: [TransactionCategory] = [
        .init(id: "groceries", name: "Groceries", icon: "🛒", kind: .expense),
        .init(id: "home", name: "Home", icon: "🏠", kind: .expense),
        .init(id: "gift", name: "Gift", icon: "🎁", kind: .expense),
        .init(id: "utility", name: "Utility", icon: "💡", kind: .expense),
        .init(id: "shopping", name: "Shopping", icon: "🛍️", kind: .expense),
        .init(id: "transport", name: "Transport", icon: "🚌", kind: .expense),
        .init(id: "health", name: "Health", icon: "🩺", kind: .expense),
        .init(id: "entertainment", name: "Entertainment", icon: "🎬", kind: .expense),
        .init(id: "restaurant", name: "Restaurant", icon: "🍽️", kind: .expense),
        .init(id: "cafe", name: "Cafe", icon: "☕️", kind: .expense),
        .init(id: "travel", name: "Travel", icon: "✈️", kind: .expense),
        .init(id: "kids", name: "Kids", icon: "🧒", kind: .expense),
        .init(id: "education", name: "Education", icon: "📚", kind: .expense),
        .init(id: "salary", name: "Salary", icon: "💼", kind: .income),
        .init(id: "freelance", name: "Freelance", icon: "🧑‍💻", kind: .income),
        .init(id: "bonus", name: "Bonus", icon: "🏆", kind: .income),
        .init(id: "savings", name: "Savings", icon: "💰", kind: .both),
        .init(id: "subscription", name: "Subscription", icon: "📱", kind: .expense),
        .init(id: "rent", name: "Rent", icon: "🏘️", kind: .expense),
        .init(id: "fuel", name: "Fuel", icon: "⛽️", kind: .expense),
        .init(id: "pharmacy", name: "Pharmacy", icon: "💊", kind: .expense),
        .init(id: "pet", name: "Pet", icon: "🐾", kind: .expense),
        .init(id: "other", name: "Other", icon: "🔖", kind: .both)
    ]

    static let quickAddCategoryIDs: [String] = [
        "groceries", "cafe", "transport", "salary", "rent", "subscription"
    ]

    static func category(for id: String) -> TransactionCategory {
        all.first(where: { $0.id == id }) ?? TransactionCategory(id: "other", name: "Other", icon: "🔖", kind: .both)
    }

    static func categories(for type: TransactionType) -> [TransactionCategory] {
        all.filter {
            $0.kind == .both ||
            (type == .income && $0.kind == .income) ||
            (type == .expense && $0.kind == .expense)
        }
    }
}
