//
//  RecurringTransactionService.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import Foundation

protocol RecurringTransactionServicing {
    /// Dates a series fires on within `[from, to)`, honouring pause, end date
    /// and skipped days.
    func occurrenceDates(for series: RecurringSeries, from: Date, to: Date) -> [Date]

    /// Dates that should become stored `Transaction` rows because they are at or
    /// before `boundary` and have not been materialized yet.
    func pendingMaterializationDates(for series: RecurringSeries, through boundary: Date) -> [Date]

    /// Forecast rows for a period: series dates strictly after `boundary`.
    func projections(
        for series: [RecurringSeries],
        in period: DateInterval,
        after boundary: Date
    ) -> [TransactionOccurrence]
}

struct RecurringTransactionService: RecurringTransactionServicing {
    /// Upper bound on dates produced for one series in one window. A window is
    /// at most a month or a year of a single rule, so this is never reached in
    /// normal use -- it exists so a corrupt start date cannot spin forever.
    private static let iterationLimit = 2_000

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func occurrenceDates(for series: RecurringSeries, from: Date, to: Date) -> [Date] {
        guard
            series.rule.repeats,
            !series.isPaused,
            let component = series.rule.calendarComponent,
            from < to
        else {
            return []
        }

        let start = calendar.startOfDay(for: series.startDate)
        let hardEnd = series.endDate.map { calendar.startOfDay(for: $0) }

        if let hardEnd, hardEnd < calendar.startOfDay(for: from) {
            return []
        }

        // Jump straight to the neighbourhood of `from` instead of stepping one
        // interval at a time from the start date, then step back a little to
        // absorb any rounding in the estimate.
        var index = max(0, estimatedIndex(component: component, from: start, to: from) - 2)
        var results: [Date] = []
        var iterations = 0

        while iterations < Self.iterationLimit {
            iterations += 1

            // Always add to the original start date so monthly series do not
            // drift: the 31st becomes the 28th in February and the 31st again
            // in March, rather than permanently collapsing to the 28th.
            guard let candidate = calendar.date(byAdding: component, value: index, to: start) else {
                break
            }
            index += 1

            let day = calendar.startOfDay(for: candidate)

            if let hardEnd, day > hardEnd { break }
            if candidate >= to { break }
            if candidate < from { continue }
            if series.skippedDays.contains(day) { continue }

            results.append(candidate)
        }

        return results
    }

    func pendingMaterializationDates(for series: RecurringSeries, through boundary: Date) -> [Date] {
        let boundaryDay = calendar.startOfDay(for: boundary)

        let from: Date
        if let through = series.materializedThrough {
            guard let next = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: through)
            ) else {
                return []
            }
            from = next
        } else {
            from = calendar.startOfDay(for: series.startDate)
        }

        // Materialize through the boundary day inclusive.
        guard let to = calendar.date(byAdding: .day, value: 1, to: boundaryDay), from < to else {
            return []
        }

        return occurrenceDates(for: series, from: from, to: to)
    }

    func projections(
        for series: [RecurringSeries],
        in period: DateInterval,
        after boundary: Date
    ) -> [TransactionOccurrence] {
        let boundaryDay = calendar.startOfDay(for: boundary)
        guard let firstProjectedDay = calendar.date(byAdding: .day, value: 1, to: boundaryDay) else {
            return []
        }

        let from = max(period.start, firstProjectedDay)
        guard from < period.end else { return [] }

        return series.flatMap { item in
            occurrenceDates(for: item, from: from, to: period.end).map { date in
                TransactionOccurrence(
                    id: "series-\(item.id.uuidString)-\(Self.dayKey(date, calendar: calendar))",
                    transactionID: nil,
                    seriesID: item.id,
                    amount: item.amount,
                    note: item.note,
                    categoryID: item.categoryID,
                    type: item.type,
                    date: date,
                    isProjected: true,
                    currency: item.currency
                )
            }
        }
    }

    private func estimatedIndex(component: Calendar.Component, from: Date, to: Date) -> Int {
        guard from < to else { return 0 }
        let components = calendar.dateComponents([component], from: from, to: to)

        switch component {
        case .day: return components.day ?? 0
        case .weekOfYear: return components.weekOfYear ?? 0
        case .month: return components.month ?? 0
        case .year: return components.year ?? 0
        default: return 0
        }
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
