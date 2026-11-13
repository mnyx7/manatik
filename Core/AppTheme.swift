//
//  AppTheme.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import SwiftUI

/// The app's design system.
///
/// Two ideas hold it together:
///
/// 1. **Depth comes from glass, not from tinted boxes.** Content floats in
///    Liquid Glass over a warm, slightly luminous page. The old build painted
///    every card a different pastel, which flattened the hierarchy because a
///    heading, a total and a hint all carried the same visual weight.
/// 2. **Colour means something.** Warm terracotta is money out, green is money
///    in, teal is money saved, violet is debt. A colour is never decorative, so
///    a glance at a screen reads as a direction of travel.
enum AppTheme {

    // MARK: - Palette

    static let pageBackground = Color("AppBackground")
    static let cardBackground = Color("CardSurface")

    static let incomeAccent = Color("IncomeAccent")
    static let expenseAccent = Color("ExpenseAccent")
    static let savingsAccent = Color("SavingsAccent")
    static let loanAccent = Color("LoanAccent")

    /// Low-opacity washes, for the rare surface that must read as tinted even
    /// behind glass (progress tracks, chart bands).
    static let incomeSurface = Color("IncomeSurface")
    static let expenseSurface = Color("ExpenseSurface")
    static let savingsSurface = Color("SavingsSurface")

    // MARK: - Metrics

    /// Apple's minimum comfortable hit target.
    static let minimumTapTarget: CGFloat = 44

    /// iOS 26 geometry is rounder than iOS 17's. These match the concentricity
    /// of the system's own glass containers.
    static let cardCornerRadius: CGFloat = 26
    static let innerCornerRadius: CGFloat = 18
    static let chipCornerRadius: CGFloat = 14

    static let cardPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 22
    static let pageHorizontalPadding: CGFloat = 20

    /// Height the floating tab bar needs to clear at the bottom of a scroll view.
    static let tabBarClearance: CGFloat = 96

    // MARK: - Shapes

    static var innerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
    }

    static var chipShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: chipCornerRadius, style: .continuous)
    }

    // MARK: - Semantic lookups

    static func accent(for type: TransactionType) -> Color {
        type == .income ? incomeAccent : expenseAccent
    }

    static func surface(for type: TransactionType) -> Color {
        type == .income ? incomeSurface : expenseSurface
    }

    /// Colour for a net figure: negative reads as overspend.
    static func netAccent(for amount: Decimal) -> Color {
        amount < 0 ? expenseAccent : savingsAccent
    }
}

// MARK: - Page background

/// The warm, softly lit page every screen sits on.
///
/// Liquid Glass refracts what is behind it, so a flat fill makes glass look
/// like plain grey plastic. These very wide, very low-contrast washes give it
/// something to pick up without becoming a decorative gradient.
struct AppBackgroundView: View {
    var body: some View {
        AppTheme.pageBackground
            .overlay(alignment: .top) {
                EllipticalGradient(
                    colors: [AppTheme.expenseAccent.opacity(0.14), .clear],
                    center: .topTrailing,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.75
                )
                .frame(height: 520)
                .blur(radius: 40)
            }
            .overlay(alignment: .bottomLeading) {
                EllipticalGradient(
                    colors: [AppTheme.savingsAccent.opacity(0.12), .clear],
                    center: .bottomLeading,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.7
                )
                .frame(height: 440)
                .blur(radius: 40)
            }
            .ignoresSafeArea()
    }
}

// MARK: - Glass surfaces

extension View {
    /// The standard content card: Liquid Glass with concentric corners.
    func glassCard(
        cornerRadius: CGFloat = AppTheme.cardCornerRadius,
        padding: CGFloat = AppTheme.cardPadding
    ) -> some View {
        self
            .padding(padding)
            .liquidGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// A card that carries a meaning colour, e.g. the savings hero or a loan
    /// card. The tint rides inside the glass rather than replacing it, so the
    /// surface still refracts the page.
    func glassCard(
        tint: Color,
        tintOpacity: Double = 0.16,
        cornerRadius: CGFloat = AppTheme.cardCornerRadius,
        padding: CGFloat = AppTheme.cardPadding
    ) -> some View {
        self
            .padding(padding)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: tint.opacity(tintOpacity)
            )
    }

    /// A card the user taps. `interactive()` gives the glass the system's own
    /// press response, which a plain button style cannot fake.
    func interactiveGlassCard(
        tint: Color? = nil,
        cornerRadius: CGFloat = AppTheme.cardCornerRadius,
        padding: CGFloat = AppTheme.cardPadding
    ) -> some View {
        self
            .padding(padding)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: tint?.opacity(0.18),
                interactive: true
            )
    }
}

// MARK: - Typography

extension Font {
    /// Big money figures. Rounded digits feel friendlier and, more usefully,
    /// are monospaced-width so a changing total does not jitter.
    static func moneyHero() -> Font {
        .system(size: 44, weight: .bold, design: .rounded)
    }

    static func moneyMedium() -> Font {
        .system(size: 19, weight: .semibold, design: .rounded)
    }

    /// Section headings: small, confident, not shouty.
    static func sectionTitle() -> Font {
        .system(.headline, design: .default, weight: .semibold)
    }
}

extension View {
    /// Money text that never reflows as digits change.
    func moneyDigits() -> some View {
        monospacedDigit()
            .contentTransition(.numericText())
    }
}
