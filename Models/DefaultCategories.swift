import Foundation

enum DefaultCategories {
    static let all: [TransactionCategory] = [
        .init(id: "groceries", name: "Groceries", icon: "\u{1F6D2}", kind: .expense),
        .init(id: "home", name: "Home", icon: "\u{1F3E0}", kind: .expense),
        .init(id: "gift", name: "Gift", icon: "\u{1F381}", kind: .expense),
        .init(id: "utility", name: "Utility", icon: "\u{1F4A1}", kind: .expense),
        .init(id: "shopping", name: "Shopping", icon: "\u{1F6CD}", kind: .expense),
        .init(id: "transport", name: "Transport", icon: "\u{1F68C}", kind: .expense),
        .init(id: "health", name: "Health", icon: "\u{1FA7A}", kind: .expense),
        .init(id: "entertainment", name: "Entertainment", icon: "\u{1F3AC}", kind: .expense),
        .init(id: "restaurant", name: "Restaurant", icon: "\u{1F37D}", kind: .expense),
        .init(id: "cafe", name: "Cafe", icon: "\u{2615}", kind: .expense),
        .init(id: "travel", name: "Travel", icon: "\u{2708}", kind: .expense),
        .init(id: "kids", name: "Kids", icon: "\u{1F9D2}", kind: .expense),
        .init(id: "education", name: "Education", icon: "\u{1F4DA}", kind: .expense),
        .init(id: "salary", name: "Salary", icon: "\u{1F4BC}", kind: .income),
        .init(id: "freelance", name: "Freelance", icon: "\u{1F4BB}", kind: .income),
        .init(id: "bonus", name: "Bonus", icon: "\u{1F3C6}", kind: .income),
        .init(id: "savings", name: "Savings", icon: "\u{1F4B0}", kind: .both),
        .init(id: "subscription", name: "Subscription", icon: "\u{1F4F1}", kind: .expense),
        .init(id: "rent", name: "Rent", icon: "\u{1F3D8}", kind: .expense),
        .init(id: "fuel", name: "Fuel", icon: "\u{26FD}", kind: .expense),
        .init(id: "pharmacy", name: "Pharmacy", icon: "\u{1F48A}", kind: .expense),
        .init(id: "pet", name: "Pet", icon: "\u{1F43E}", kind: .expense),
        .init(id: "loan", name: "Loan", icon: "\u{1F3E6}", kind: .expense),
        .init(id: "other", name: "Other", icon: "\u{1F516}", kind: .both)
    ]

    /// Category used for money moved into a savings goal.
    static let savingsCategoryID = "savings"
    /// Category used for loan instalments.
    static let loanCategoryID = "loan"

    static let quickAddCategoryIDs: [String] = [
        "groceries", "cafe", "transport", "salary", "rent", "subscription"
    ]

    private static let fallback = TransactionCategory(
        id: "other",
        name: "Other",
        icon: "\u{1F516}",
        kind: .both
    )

    private static let byID: [String: TransactionCategory] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    static func category(for id: String) -> TransactionCategory {
        byID[id] ?? fallback
    }

    /// Looks a category up across the built-in list and the user's own.
    static func category(for id: String, custom: [TransactionCategory]) -> TransactionCategory {
        byID[id] ?? custom.first { $0.id == id } ?? fallback
    }

    static func categories(for type: TransactionType) -> [TransactionCategory] {
        filtered(all, for: type)
    }

    /// Built-in plus user-made, keeping user-made at the end so the list the
    /// person added to stays stable.
    static func merged(with custom: [TransactionCategory]) -> [TransactionCategory] {
        let builtInIDs = Set(all.map(\.id))
        return all + custom.filter { !builtInIDs.contains($0.id) }
    }

    static func filtered(
        _ categories: [TransactionCategory],
        for type: TransactionType
    ) -> [TransactionCategory] {
        categories.filter {
            $0.kind == .both ||
            (type == .income && $0.kind == .income) ||
            (type == .expense && $0.kind == .expense)
        }
    }

    /// Turns a display name into a stable, collision-free id.
    static func makeCustomID(from name: String, existing: [String]) -> String {
        let slug = name
            .lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { partial, character in
                if character == "-", partial.hasSuffix("-") { return }
                partial.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        let base = slug.isEmpty ? "category" : "custom-\(slug)"
        guard existing.contains(base) else { return base }

        var index = 2
        while existing.contains("\(base)-\(index)") {
            index += 1
        }
        return "\(base)-\(index)"
    }

    /// True when the localized or source name of `id` matches a search term.
    static func name(forID id: String, matches term: String) -> Bool {
        guard !term.isEmpty else { return true }
        let category = category(for: id)
        return category.localizedName.localizedCaseInsensitiveContains(term)
            || category.name.localizedCaseInsensitiveContains(term)
    }
}
