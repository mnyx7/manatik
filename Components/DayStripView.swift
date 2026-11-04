import SwiftUI

/// A plain horizontal calendar for the period being browsed.
///
/// Tap a day to narrow the list to it, tap it again to go back to the whole
/// period. A dot marks days that actually have entries, so there is no need to
/// go hunting through empty ones.
struct DayStripView: View {
    let interval: DateInterval
    let daysWithActivity: Set<Date>
    @Binding var selectedDay: Date?

    private let calendar = Calendar.current

    private var days: [Date] {
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: interval.start)
        var guardCount = 0
        while cursor < interval.end, guardCount < 40 {
            guardCount += 1
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { day in
                        dayButton(day)
                            .id(day)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
            .onAppear {
                // Land on today, or the selection, rather than the 1st.
                let target = selectedDay ?? calendar.startOfDay(for: Date())
                if days.contains(target) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func dayButton(_ day: Date) -> some View {
        let isSelected = selectedDay == day
        let isToday = calendar.isDateInToday(day)
        let hasActivity = daysWithActivity.contains(day)

        Button {
            selectedDay = isSelected ? nil : day
        } label: {
            VStack(spacing: 2) {
                Text(weekdayInitial(day))
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white : .secondary)

                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(isToday ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white : .primary)

                Circle()
                    .fill(hasActivity ? (isSelected ? Color.white : Color.accentColor) : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 40, height: 52)
            .background(
                isSelected ? Color.accentColor : AppTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isToday && !isSelected ? Color.accentColor : .clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(DateFormatting.dayAndMonth(day)))
        .accessibilityValue(
            hasActivity
                ? NSLocalizedString("has entries", comment: "Accessibility")
                : NSLocalizedString("no entries", comment: "Accessibility")
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func weekdayInitial(_ day: Date) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        let index = calendar.component(.weekday, from: day) - 1
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }
}
