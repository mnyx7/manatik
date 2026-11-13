//
//  QuickAddWidget.swift
//  MunaWidget
//
//  Created by Minaya Yagubova on 13.11.26.
//

import SwiftUI
import WidgetKit

/// Home Screen and Lock Screen widget: one tap opens New Entry.
///
/// It shows no figures, so it needs no access to the app's data and never
/// has to refresh: the timeline is a single entry that never changes.
@main
struct MunaWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickAddWidget()
    }
}

struct QuickAddWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickAdd", provider: QuickAddProvider()) { _ in
            QuickAddWidgetView()
        }
        .configurationDisplayName("Quick add")
        .description("Add an expense or income in one tap.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct QuickAddEntry: TimelineEntry {
    let date: Date
}

struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry {
        QuickAddEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        completion(Timeline(entries: [QuickAddEntry(date: .now)], policy: .never))
    }
}

/// The app opens New Entry when it receives this link.
private let addURL = URL(string: "muna://add")!

struct QuickAddWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .widgetAccentable()
            }
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(addURL)
            .accessibilityLabel(Text("Add income or expense"))
        default:
            small
        }
    }

    /// The logo's language: mint circle, terracotta badge with a dark ink
    /// outline offset like a print, and the two sparkles.
    private var small: some View {
        ZStack {
            Circle()
                .fill(Palette.mint)
                .frame(width: 124, height: 124)

            Circle()
                .fill(Palette.ink)
                .frame(width: 84, height: 84)
                .offset(x: 3, y: 3)

            Circle()
                .fill(Palette.terracotta)
                .frame(width: 84, height: 84)

            Image(systemName: "plus")
                .font(.system(size: 38, weight: .heavy))
                .foregroundStyle(.white)
                .widgetAccentable()

            sparkle(Palette.butter, size: 22)
                .offset(x: 50, y: -46)
            sparkle(.white, size: 14)
                .offset(x: -52, y: 38)
        }
        .containerBackground(for: .widget) { Palette.cream }
        .widgetURL(addURL)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Add income or expense"))
    }

    private func sparkle(_ color: Color, size: CGFloat) -> some View {
        ZStack {
            Image(systemName: "sparkle")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(Palette.ink)
                .offset(x: 1.5, y: 1.5)
            Image(systemName: "sparkle")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(color)
        }
    }
}

/// The app's colours, repeated here because the widget is a separate
/// bundle without the app's asset catalog.
private enum Palette {
    static let cream = Color(light: (0.984, 0.969, 0.949), dark: (0.071, 0.063, 0.059))
    static let mint = Color(light: (0.867, 0.914, 0.827), dark: (0.20, 0.25, 0.20))
    static let terracotta = Color(light: (0.784, 0.333, 0.184), dark: (0.85, 0.42, 0.27))
    static let ink = Color(red: 0.231, green: 0.184, blue: 0.173)
    static let butter = Color(red: 0.969, green: 0.788, blue: 0.353)
}

private extension Color {
    init(light: (Double, Double, Double), dark: (Double, Double, Double)) {
        self.init(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

#Preview(as: .systemSmall) {
    QuickAddWidget()
} timeline: {
    QuickAddEntry(date: .now)
}
