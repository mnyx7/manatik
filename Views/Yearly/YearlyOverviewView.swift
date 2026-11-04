import SwiftUI

struct YearlyOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: YearlyOverviewViewModel

    private let grid = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: grid, spacing: 12) {
                ForEach(viewModel.months) { item in
                    monthCard(item)
                }
            }
            .padding()
        }
        .background(AppTheme.pageBackground)
        .navigationTitle(Text(verbatim: "\(viewModel.year)"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.previousYear()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!viewModel.canGoToPreviousYear)
                .accessibilityLabel(Text("Previous year"))

                Button {
                    viewModel.nextYear()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!viewModel.canGoToNextYear)
                .accessibilityLabel(Text("Next year"))
            }
        }
    }

    @ViewBuilder
    private func monthCard(_ item: MonthOverviewItem) -> some View {
        let isSelected = item.interval.start == viewModel.selectedInterval.start
        let incomeText = CurrencyFormatting.format(amount: item.income, currency: viewModel.currency)
        let expenseText = CurrencyFormatting.format(amount: item.expense, currency: viewModel.currency)

        Button {
            viewModel.select(month: item)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(DateFormatting.monthName(item.month))
                        .font(.headline)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                    }
                }

                if item.hasActivity {
                    figureRow(label: "Income", value: incomeText, accent: AppTheme.incomeAccent)
                    figureRow(label: "Expense", value: expenseText, accent: AppTheme.expenseAccent)
                } else {
                    Text("No entries")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? AppTheme.savingsSurface : AppTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(DateFormatting.monthName(item.month)))
        .accessibilityValue(
            item.hasActivity
                ? String(
                    format: NSLocalizedString("income %1$@, expense %2$@", comment: "Accessibility"),
                    incomeText,
                    expenseText
                )
                : NSLocalizedString("No entries", comment: "Accessibility")
        )
        .accessibilityHint(Text("Shows this month on the main page"))
    }

    @ViewBuilder
    private func figureRow(label: LocalizedStringKey, value: String, accent: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        YearlyOverviewView(
            viewModel: YearlyOverviewViewModel(store: MockData.previewStore(), year: 2026)
        )
    }
}
