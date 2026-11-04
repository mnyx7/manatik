import SwiftUI

struct DateFilterSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var filter: TransactionFilter
    @State private var startDate: Date
    @State private var endDate: Date

    init(filter: Binding<TransactionFilter>) {
        _filter = filter
        let interval = filter.wrappedValue.dateInterval
        _startDate = State(initialValue: interval?.start ?? Date())
        _endDate = State(initialValue: interval?.end ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, displayedComponents: .date)

                Button("Apply") {
                    let normalizedEnd = Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
                    filter.dateInterval = DateInterval(start: min(startDate, endDate), end: max(normalizedEnd, startDate))
                    dismiss()
                }

                if filter.dateInterval != nil {
                    Button("Clear Date Filter", role: .destructive) {
                        filter.dateInterval = nil
                        dismiss()
                    }
                }
            }
            .navigationTitle("Date Filter")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
