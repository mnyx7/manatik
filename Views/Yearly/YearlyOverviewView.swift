import SwiftUI

struct YearlyOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: YearlyOverviewViewModel

    private let grid = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: grid, spacing: 12) {
                    ForEach(viewModel.months) { item in
                        monthCard(item)
                    }
                }
                .padding()
            }
            .background(AppTheme.groupedBackground)
            .navigationTitle("Year Overview")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.previousYear()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("\(viewModel.year)")
                        .font(.headline)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            viewModel.nextYear()
                        } label: {
                            Image(systemName: "chevron.right")
                        }

                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func monthCard(_ item: MonthOverviewItem) -> some View {
        let isSelected = item.interval.start == viewModel.selectedInterval.start

        return Button {
            viewModel.select(month: item)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(monthTitle(item.month))
                    .font(.headline)

                HStack {
                    Text("Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(CurrencyFormatting.format(amount: item.income, currency: viewModel.store.state.settings.currency))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }

                HStack {
                    Text("Expense")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(CurrencyFormatting.format(amount: item.expense, currency: viewModel.store.state.settings.currency))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? AppTheme.savingsColor.opacity(0.45) : AppTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func monthTitle(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[max(0, min(month - 1, 11))]
    }
}

#Preview {
    YearlyOverviewView(viewModel: YearlyOverviewViewModel(store: AppStore(), year: 2026))
}
