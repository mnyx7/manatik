import SwiftUI

/// Every currency, searchable by code or name. The few a person actually
/// uses sit on top so the long list is only needed once in a while.
struct CurrencyPickerView: View {
    let title: LocalizedStringKey
    let selection: Currency
    /// Shown first: the main currency and ones the user picked before.
    let pinned: [Currency]
    let onPick: (Currency) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var top: [Currency] {
        var seen = Set<Currency>()
        return (pinned + Currency.suggested).filter { seen.insert($0).inserted }
    }

    private var matches: [Currency] {
        guard !trimmedQuery.isEmpty else { return Currency.allCases }
        return Currency.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.localizedName.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.symbol == trimmedQuery
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty {
                    Section {
                        ForEach(top, content: row)
                    }
                    Section("All currencies") {
                        ForEach(matches, content: row)
                    }
                } else if matches.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                } else {
                    ForEach(matches, content: row)
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Code or name")
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(_ currency: Currency) -> some View {
        Button {
            onPick(currency)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(currency.symbol)
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 40, alignment: .leading)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(currency.localizedName)
                        .foregroundStyle(.primary)
                    Text(currency.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if currency == selection {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .frame(minHeight: AppTheme.minimumTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(currency == selection ? [.isSelected] : [])
    }
}
