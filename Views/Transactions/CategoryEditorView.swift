import SwiftUI

/// Creates a user-made category, or edits one that already exists.
struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    /// Non-nil when editing. Only user-made categories can be edited: built-in
    /// names are localization keys, so renaming one would break translations.
    private let existing: TransactionCategory?
    private let onSave: (String, String, CategoryKind) -> Void

    @State private var name: String
    @State private var icon: String
    @State private var kind: CategoryKind
    @FocusState private var isNameFocused: Bool

    /// A small, hand-picked set beats asking people to find the emoji keyboard.
    private let suggestions = [
        "\u{1F516}", "\u{1F6D2}", "\u{1F3E0}", "\u{1F697}", "\u{1F4BB}", "\u{1F3AF}",
        "\u{1F4DA}", "\u{1F3A8}", "\u{1F3C3}", "\u{1F487}", "\u{1F9F4}", "\u{1F6E0}",
        "\u{1F381}", "\u{2708}", "\u{1F3E5}", "\u{1F43E}", "\u{1F4F6}", "\u{1F4B3}",
        "\u{1F354}", "\u{1F6BF}", "\u{1F455}", "\u{26BD}", "\u{1F3AC}", "\u{1F4B0}"
    ]

    init(
        suggestedKind: CategoryKind,
        editing: TransactionCategory? = nil,
        onSave: @escaping (String, String, CategoryKind) -> Void
    ) {
        self.existing = editing
        self.onSave = onSave
        _name = State(initialValue: editing?.name ?? "")
        _icon = State(initialValue: editing?.icon ?? "\u{1F516}")
        _kind = State(initialValue: editing?.kind ?? suggestedKind)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("For example: Gym", text: $name)
                        .focused($isNameFocused)
                }

                Section("Icon") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 6),
                        spacing: 10
                    ) {
                        ForEach(suggestions, id: \.self) { candidate in
                            Button {
                                icon = candidate
                            } label: {
                                Text(candidate)
                                    .font(.title3)
                                    .frame(width: 42, height: 42)
                                    .background(
                                        icon == candidate
                                            ? AppTheme.savingsSurface
                                            : AppTheme.cardBackground,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(
                                                icon == candidate ? AppTheme.savingsAccent : .clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Icon \(candidate)"))
                            .accessibilityAddTraits(icon == candidate ? [.isSelected] : [])
                        }
                    }
                    .padding(.vertical, 4)

                    TextField("Or paste any emoji", text: $icon)
                        .multilineTextAlignment(.center)
                        .font(.title3)
                }

                Section {
                    Picker(selection: $kind) {
                        Text("Expense").tag(CategoryKind.expense)
                        Text("Income").tag(CategoryKind.income)
                        Text("Both").tag(CategoryKind.both)
                    } label: {
                        Text("Used for")
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Choosing Both makes the category available for income and expenses.")
                }
            }
            .navigationTitle(existing == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(existing == nil ? "Add" : "Save") {
                        onSave(trimmedName, normalizedIcon, kind)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .task {
                if existing == nil { isNameFocused = true }
            }
        }
    }

    /// Keeps a single glyph, so a pasted sentence cannot become the icon.
    private var normalizedIcon: String {
        let trimmed = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "\u{1F516}" }
        return String(first)
    }
}

#Preview {
    CategoryEditorView(suggestedKind: .expense) { _, _, _ in }
}
