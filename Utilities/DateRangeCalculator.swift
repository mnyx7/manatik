import Foundation

enum DateRangeCalculator {
    static func period(for anchorDate: Date, monthStartDay: Int, calendar: Calendar = .current) -> DateInterval {
        let startDay = min(max(monthStartDay, 1), 31)
        let normalizedAnchor = calendar.startOfDay(for: anchorDate)

        let anchorComponents = calendar.dateComponents([.year, .month], from: normalizedAnchor)
        guard let monthStartCandidate = date(year: anchorComponents.year!, month: anchorComponents.month!, day: startDay, calendar: calendar) else {
            return DateInterval(start: normalizedAnchor, end: calendar.date(byAdding: .day, value: 1, to: normalizedAnchor) ?? normalizedAnchor)
        }

        let periodStart: Date
        if normalizedAnchor < monthStartCandidate {
            let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: monthStartCandidate) ?? normalizedAnchor
            let previousComponents = calendar.dateComponents([.year, .month], from: previousMonthDate)
            periodStart = date(year: previousComponents.year!, month: previousComponents.month!, day: startDay, calendar: calendar) ?? monthStartCandidate
        } else {
            periodStart = monthStartCandidate
        }

        let nextMonth = calendar.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart
        let nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
        let periodEnd = date(year: nextComponents.year!, month: nextComponents.month!, day: startDay, calendar: calendar) ?? nextMonth

        return DateInterval(start: periodStart, end: periodEnd)
    }

    static func periodDisplayText(for interval: DateInterval, calendar: Calendar = .current) -> String {
        let displayEnd = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "d MMMM"
        return "\(formatter.string(from: interval.start)) - \(formatter.string(from: displayEnd))"
    }

    static func dayCount(for interval: DateInterval, calendar: Calendar = .current) -> Int {
        let days = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
        return max(days, 1)
    }

    static func monthAnchor(year: Int, month: Int, monthStartDay: Int, calendar: Calendar = .current) -> Date {
        date(year: year, month: month, day: monthStartDay, calendar: calendar) ?? Date()
    }

    private static func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        let monthRange = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date())
        let normalizedDay = min(day, monthRange?.upperBound.advanced(by: -1) ?? day)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = normalizedDay
        return calendar.date(from: components)
    }
}
