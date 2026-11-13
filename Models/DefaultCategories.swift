//
//  DefaultCategories.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import Foundation

enum DefaultCategories {
    /// `icon` holds an SF Symbol name. Earlier releases stored an emoji here;
    /// `CategoryVisuals.symbolName(for:)` maps those across, so old files keep
    /// working untouched.
    static let all: [TransactionCategory] = [
        .init(id: "groceries", name: "Groceries", icon: "cart.fill", kind: .expense),
        .init(id: "home", name: "Home", icon: "house.fill", kind: .expense),
        .init(id: "gift", name: "Gift", icon: "gift.fill", kind: .expense),
        .init(id: "utility", name: "Utility", icon: "lightbulb.fill", kind: .expense),
        .init(id: "shopping", name: "Shopping", icon: "bag.fill", kind: .expense),
        .init(id: "transport", name: "Transport", icon: "bus.fill", kind: .expense),
        .init(id: "health", name: "Health", icon: "heart.fill", kind: .expense),
        .init(id: "entertainment", name: "Entertainment", icon: "film.fill", kind: .expense),
        .init(id: "restaurant", name: "Restaurant", icon: "fork.knife", kind: .expense),
        .init(id: "cafe", name: "Cafe", icon: "cup.and.saucer.fill", kind: .expense),
        .init(id: "travel", name: "Travel", icon: "airplane", kind: .expense),
        .init(id: "kids", name: "Kids", icon: "figure.and.child.holdinghands", kind: .expense),
        .init(id: "education", name: "Education", icon: "book.fill", kind: .expense),
        .init(id: "salary", name: "Salary", icon: "briefcase.fill", kind: .income),
        .init(id: "freelance", name: "Freelance", icon: "laptopcomputer", kind: .income),
        .init(id: "bonus", name: "Bonus", icon: "trophy.fill", kind: .income),
        .init(id: "savings", name: "Savings", icon: "banknote.fill", kind: .both),
        .init(id: "subscription", name: "Subscription", icon: "creditcard.fill", kind: .expense),
        .init(id: "rent", name: "Rent", icon: "building.2.fill", kind: .expense),
        .init(id: "fuel", name: "Fuel", icon: "fuelpump.fill", kind: .expense),
        .init(id: "pharmacy", name: "Pharmacy", icon: "pills.fill", kind: .expense),
        .init(id: "pet", name: "Pet", icon: "pawprint.fill", kind: .expense),
        .init(id: "loan", name: "Loan", icon: "building.columns.fill", kind: .expense),
        .init(id: "other", name: "Other", icon: "tag.fill", kind: .both)
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
        icon: "tag.fill",
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
