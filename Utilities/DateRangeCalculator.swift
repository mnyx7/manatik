import Foundation

enum DateRangeCalculator {
    /// Periods start on days 1...28 only. Every month has those days, so
    /// consecutive periods always meet exactly: no overlap, no gap, and no
    /// per-month clamping that would make period length jump around.
    static let minimumMonthStartDay = 1
    static let maximumMonthStartDay = 28

    static func clampMonthStartDay(_ value: Int) -> Int {
        min(max(value, minimumMonthStartDay), maximumMonthStartDay)
    }

    static func period(
        for anchorDate: Date,
        monthStartDay: Int,
        calendar: Calendar = .current
    ) -> DateInterval {
        let startDay = clampMonthStartDay(monthStartDay)
        let anchor = calendar.startOfDay(for: anchorDate)
        let components = calendar.dateComponents([.year, .month], from: anchor)

        guard
            let year = components.year,
            let month = components.month,
            let candidate = calendar.date(
                from: DateComponents(year: year, month: month, day: startDay)
            )
        else {
            let end = calendar.date(byAdding: .day, value: 1, to: anchor) ?? anchor
            return DateInterval(start: anchor, end: end)
        }

        let start: Date
        if anchor < candidate {
            start = calendar.date(byAdding: .month, value: -1, to: candidate) ?? candidate
        } else {
            start = candidate
        }

        let end = calendar.date(byAdding: .month, value: 1, to: start)
            ?? calendar.date(byAdding: .day, value: 30, to: start)
            ?? start

        return DateInterval(start: start, end: end)
    }

    static func monthAnchor(
        year: Int,
        month: Int,
        monthStartDay: Int,
        calendar: Calendar = .current
    ) -> Date {
        let day = clampMonthStartDay(monthStartDay)
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
            ?? Date()
    }

    /// Total days in the period.
    static func dayCount(for interval: DateInterval, calendar: Calendar = .current) -> Int {
        let days = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
        return max(days, 1)
    }

    /// Days of the period that have actually happened, today included.
    ///
    /// This is what a daily average must divide by. Dividing by the full period
    /// length understates spending by up to ~30x on the first days of a month.
    static func elapsedDayCount(
        for interval: DateInterval,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let today = calendar.startOfDay(for: now)

        if today >= interval.end {
            return dayCount(for: interval)
        }
        if today < interval.start {
            return 0
        }

        let days = calendar.dateComponents([.day], from: interval.start, to: today).day ?? 0
        return max(days + 1, 1)
    }

    static func isCurrentPeriod(
        _ interval: DateInterval,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        let today = calendar.startOfDay(for: now)
        return today >= interval.start && today < interval.end
    }

    /// Inclusive last day of the period, for display.
    static func displayEnd(for interval: DateInterval, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
    }

    static func periodDisplayText(
        for interval: DateInterval,
        calendar: Calendar = .current
    ) -> String {
        let end = displayEnd(for: interval, calendar: calendar)
        let startText = DateFormatting.dayAndMonth(interval.start, calendar: calendar)
        let endText = DateFormatting.dayAndMonth(end, calendar: calendar)
        return "\(startText) - \(endText)"
    }
}
