//
//  PeriodPickerSheet.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import SwiftUI

struct PeriodPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    private let monthStartDay: Int
    private let onSelect: (Date) -> Void

    init(selectedDate: Date, monthStartDay: Int, onSelect: @escaping (Date) -> Void) {
        _date = State(initialValue: selectedDate)
        self.monthStartDay = monthStartDay
        self.onSelect = onSelect
    }

    /// Which budgeting period the chosen day falls in. The old sheet showed a
    /// day picker under a button labelled "Use This Month", which never said
    /// which period you were about to get.
    private var resolvedPeriod: DateInterval {
        DateRangeCalculator.period(for: date, monthStartDay: monthStartDay)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                DatePicker(
                    "Pick a day",
                    selection: $date,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                VStack(spacing: 4) {
                    Text("Period containing this day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(DateRangeCalculator.periodDisplayText(for: resolvedPeriod))
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    AppTheme.cardBackground,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

                Button {
                    onSelect(date)
                    dismiss()
                } label: {
                    Text("Show this period")
                        .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onSelect(Date())
                    dismiss()
                } label: {
                    Text("Jump to today")
                        .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Select Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
