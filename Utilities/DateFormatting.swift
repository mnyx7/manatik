import Foundation

/// Cached date formatters.
///
/// `DateFormatter` initialization is expensive and the transaction list renders
/// one date per row, so every formatter here is built once per locale and reused.
enum DateFormatting {
    private static let lock = NSLock()
    private static var formatters: [String: DateFormatter] = [:]

    private static func formatter(
        _ key: String,
        calendar: Calendar,
        configure: (DateFormatter) -> Void
    ) -> DateFormatter {
        let cacheKey = "\(key)|\(Locale.current.identifier)|\(calendar.identifier)"

        lock.lock()
        defer { lock.unlock() }

        if let cached = formatters[cacheKey] {
            return cached
        }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.calendar = calendar
        configure(formatter)
        formatters[cacheKey] = formatter
        return formatter
    }

    static func shortDate(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("mediumDate", calendar: calendar) {
            $0.dateStyle = .medium
            $0.timeStyle = .none
        }
        .string(from: date)
    }

    static func dayAndMonth(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("dayMonth", calendar: calendar) {
            $0.setLocalizedDateFormatFromTemplate("d MMMM")
        }
        .string(from: date)
    }

    static func dayMonthYear(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("dayMonthYear", calendar: calendar) {
            $0.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        }
        .string(from: date)
    }

    static func daySectionTitle(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return NSLocalizedString("Today", comment: "Day section header")
        }
        if calendar.isDateInYesterday(date) {
            return NSLocalizedString("Yesterday", comment: "Day section header")
        }
        if calendar.isDateInTomorrow(date) {
            return NSLocalizedString("Tomorrow", comment: "Day section header")
        }
        return dayAndMonth(date, calendar: calendar)
    }

    /// Localized standalone month name for 1...12.
    static func monthName(_ month: Int, calendar: Calendar = .current) -> String {
        let symbols = formatter("monthSymbols", calendar: calendar) {
            $0.dateFormat = "LLLL"
        }
        .standaloneMonthSymbols ?? []

        let index = max(0, min(month - 1, symbols.count - 1))
        guard symbols.indices.contains(index) else { return "\(month)" }
        return symbols[index]
    }

    /// Short month name for chart axes.
    static func shortMonthName(_ month: Int, calendar: Calendar = .current) -> String {
        let symbols = formatter("shortMonthSymbols", calendar: calendar) {
            $0.dateFormat = "LLL"
        }
        .shortStandaloneMonthSymbols ?? []

        let index = max(0, min(month - 1, symbols.count - 1))
        guard symbols.indices.contains(index) else { return "\(month)" }
        return symbols[index]
    }

    static func invalidateCache() {
        lock.lock()
        formatters.removeAll()
        lock.unlock()
    }
}
