//
//  GlassCompat.swift
//  muna
//
//  Created by Minaya Yagubova on 13.11.26.
//

import SwiftUI

// Liquid Glass exists only on iOS 26. These wrappers use it there and fall
// back to the standard blurred material on iOS 17 and 18, so every call site
// stays one line and the older look is defined in one place.

extension View {
    /// A Liquid Glass surface on iOS 26; a material with the same tint on
    /// older systems.
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26, *), !GlassCompat.forceFallback {
            self.glassEffect(Self.glass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.background {
                ZStack {
                    shape.fill(.regularMaterial)
                    if let tint { shape.fill(tint) }
                }
                .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
            }
            .overlay(shape.stroke(Color.primary.opacity(0.07), lineWidth: 0.5))
        }
    }

    /// Lets glass shapes morph into each other on iOS 26. Nothing to do on
    /// older systems.
    @ViewBuilder
    func liquidGlassID(_ id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26, *), !GlassCompat.forceFallback {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(iOS 26, *), !GlassCompat.forceFallback {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func glassProminentButtonStyle() -> some View {
        if #available(iOS 26, *), !GlassCompat.forceFallback {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @available(iOS 26, *)
    private static func glass(tint: Color?, interactive: Bool) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

/// `GlassEffectContainer` on iOS 26, so neighbouring glass blends; a plain
/// pass-through on older systems.
struct LiquidGlassContainer<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26, *), !GlassCompat.forceFallback {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

enum GlassCompat {
    /// DEBUG launch option `-qa-no-glass` shows the iOS 17/18 look on an
    /// iOS 26 simulator, since no older runtime is installed here.
    #if DEBUG
    static let forceFallback = ProcessInfo.processInfo.arguments.contains("-qa-no-glass")
    #else
    static let forceFallback = false
    #endif
}
