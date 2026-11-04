import SwiftUI

struct DateFilterSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var filter: TransactionFilter
    @State private var startDate: Date
    @State private var endDate: Date

    init(filter: Binding<TransactionFilter>) {
        _filter = filter
        let interval = filter.wrappedValue.dateInterval
        let fallbackStart = interval?.start ?? Date()
        _startDate = State(initialValue: fallbackStart)
        _endDate = State(
            initialValue: interval.map {
                Calendar.current.date(byAdding: .day, value: -1, to: $0.end) ?? $0.end
            } ?? Date()
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                } footer: {
                    // Makes the override explicit. A range outside the selected
                    // month used to return nothing, with no hint why.
                    Text("A date range replaces the period shown on the main page, so you can search across months.")
                }

                Section {
                    Button {
                        apply()
                    } label: {
                        Text("Apply range")
                            .frame(minHeight: AppTheme.minimumTapTarget)
                    }

                    if filter.dateInterval != nil {
                        Button(role: .destructive) {
                            filter.dateInterval = nil
                            dismiss()
                        } label: {
                            Text("Clear date range")
                                .frame(minHeight: AppTheme.minimumTapTarget)
                        }
                    }
                }
            }
            .navigationTitle("Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func apply() {
        let calendar = Calendar.current
        let lower = min(startDate, endDate)
        let upper = max(startDate, endDate)

        // End is exclusive internally, so the chosen last day is included.
        let exclusiveEnd = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: upper)
        ) ?? upper

        filter.dateInterval = DateInterval(
            start: calendar.startOfDay(for: lower),
            end: exclusiveEnd
        )
        dismiss()
    }
}
