//
//  CategoryVisuals.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import SwiftUI

/// How a category is drawn: an SF Symbol and a tint.
///
/// The previous build stored an emoji in `TransactionCategory.icon` and
/// rendered it as text. Emoji cannot be tinted, ignore font weight, change
/// shape between OS versions, sit on a different optical baseline from the SF
/// Symbols used everywhere else in the app, and are read out by VoiceOver under
/// their own Unicode name. Symbols fix all five.
///
/// Existing data still holds emoji, so `symbolName(for:)` maps the old glyphs
/// across. Nothing on disk has to change and no migration can fail.
enum CategoryVisuals {

    // MARK: - Symbols

    /// Emoji written by earlier versions, mapped to the symbol that replaced it.
    private static let symbolsByLegacyEmoji: [String: String] = [
        "\u{1F6D2}": "cart.fill",
        "\u{1F3E0}": "house.fill",
        "\u{1F381}": "gift.fill",
        "\u{1F4A1}": "lightbulb.fill",
        "\u{1F6CD}": "bag.fill",
        "\u{1F68C}": "bus.fill",
        "\u{1FA7A}": "heart.fill",
        "\u{1F3AC}": "film.fill",
        "\u{1F37D}": "fork.knife",
        "\u{2615}": "cup.and.saucer.fill",
        "\u{2708}": "airplane",
        "\u{1F9D2}": "figure.and.child.holdinghands",
        "\u{1F4DA}": "book.fill",
        "\u{1F4BC}": "briefcase.fill",
        "\u{1F4BB}": "laptopcomputer",
        "\u{1F3C6}": "trophy.fill",
        "\u{1F4B0}": "banknote.fill",
        "\u{1F4F1}": "creditcard.fill",
        "\u{1F3D8}": "building.columns.fill",
        "\u{26FD}": "fuelpump.fill",
        "\u{1F48A}": "pills.fill",
        "\u{1F43E}": "pawprint.fill",
        "\u{1F3E6}": "building.columns.fill",
        "\u{1F516}": "tag.fill"
    ]

    static let fallbackSymbol = "tag.fill"

    /// Symbols offered when naming a custom category.
    static let pickerSymbols: [String] = [
        "tag.fill", "cart.fill", "bag.fill", "house.fill", "building.2.fill",
        "fork.knife", "cup.and.saucer.fill", "birthday.cake.fill", "wineglass.fill",
        "bus.fill", "car.fill", "fuelpump.fill", "bicycle", "airplane", "tram.fill",
        "heart.fill", "pills.fill", "cross.case.fill", "figure.run", "dumbbell.fill",
        "book.fill", "graduationcap.fill", "pencil.and.ruler.fill",
        "film.fill", "gamecontroller.fill", "music.note", "ticket.fill",
        "gift.fill", "pawprint.fill", "leaf.fill", "drop.fill", "flame.fill",
        "lightbulb.fill", "wifi", "phone.fill", "creditcard.fill", "banknote.fill",
        "briefcase.fill", "laptopcomputer", "trophy.fill", "chart.line.uptrend.xyaxis",
        "building.columns.fill", "wrench.and.screwdriver.fill", "scissors",
        "tshirt.fill", "shoe.fill", "sparkles", "figure.and.child.holdinghands"
    ]

    /// Resolves the symbol for a category, accepting a stored symbol name, a
    /// legacy emoji, or neither.
    static func symbolName(for category: TransactionCategory) -> String {
        let stored = category.icon
        if let migrated = symbolsByLegacyEmoji[stored] {
            return migrated
        }
        if !stored.isEmpty, isKnownSymbol(stored) {
            return stored
        }
        return fallbackSymbol
    }

    /// `UIImage(systemName:)` is not cheap enough to call while laying out a
    /// scrolling list, so answers are remembered.
    private static var symbolValidity: [String: Bool] = [:]

    private static func isKnownSymbol(_ name: String) -> Bool {
        if let known = symbolValidity[name] { return known }
        let exists = UIImage(systemName: name) != nil
        symbolValidity[name] = exists
        return exists
    }

    // MARK: - Tints

    /// A curated set of hues, chosen to stay distinguishable from one another
    /// in a pie chart and legible on both the light and dark page.
    private static let tintsByID: [String: Color] = [
        "groceries": Color(hex: 0x4C9A5B),
        "home": Color(hex: 0xC2703D),
        "gift": Color(hex: 0xC8477E),
        "utility": Color(hex: 0xD4A017),
        "shopping": Color(hex: 0x8B5CC7),
        "transport": Color(hex: 0x3E7FBF),
        "health": Color(hex: 0xD6455E),
        "entertainment": Color(hex: 0x7A5AD6),
        "restaurant": Color(hex: 0xCF6A33),
        "cafe": Color(hex: 0x9A6B4A),
        "travel": Color(hex: 0x2E9BB0),
        "kids": Color(hex: 0xE08A3C),
        "education": Color(hex: 0x4668C4),
        "salary": Color(hex: 0x1E8A5F),
        "freelance": Color(hex: 0x2A9D8F),
        "bonus": Color(hex: 0xC99A22),
        "savings": Color(hex: 0x0E7C86),
        "subscription": Color(hex: 0x6B5BD2),
        "rent": Color(hex: 0xB55A4A),
        "fuel": Color(hex: 0x8A7A3C),
        "pharmacy": Color(hex: 0xBE4A7D),
        "pet": Color(hex: 0xA2793F),
        "loan": Color(hex: 0x7A4FA3),
        "other": Color(hex: 0x7A7A86)
    ]

    /// Fallback hues for custom categories, picked from the id so the same
    /// category always draws the same colour without storing one.
    private static let customPalette: [Color] = [
        Color(hex: 0x4C9A5B), Color(hex: 0x3E7FBF), Color(hex: 0x8B5CC7),
        Color(hex: 0xCF6A33), Color(hex: 0x2E9BB0), Color(hex: 0xC8477E),
        Color(hex: 0xD4A017), Color(hex: 0x7A4FA3), Color(hex: 0x2A9D8F),
        Color(hex: 0xD6455E)
    ]

    static func tint(for category: TransactionCategory) -> Color {
        if let known = tintsByID[category.id] {
            return known
        }
        // Stable, non-random: the same id always lands on the same hue.
        let hash = category.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFFFF }
        return customPalette[hash % customPalette.count]
    }

    static func tint(forID id: String, custom: [TransactionCategory]) -> Color {
        tint(for: DefaultCategories.category(for: id, custom: custom))
    }
}

extension Color {
    /// Hex literal convenience, e.g. `Color(hex: 0x4C9A5B)`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
