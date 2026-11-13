//
//  CategoryEditorView.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

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

    init(
        suggestedKind: CategoryKind,
        editing: TransactionCategory? = nil,
        onSave: @escaping (String, String, CategoryKind) -> Void
    ) {
        self.existing = editing
        self.onSave = onSave
        _name = State(initialValue: editing?.name ?? "")
        _icon = State(
            initialValue: editing.map { CategoryVisuals.symbolName(for: $0) }
                ?? CategoryVisuals.fallbackSymbol
        )
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
                        ForEach(CategoryVisuals.pickerSymbols, id: \.self) { candidate in
                            let isSelected = icon == candidate

                            Button {
                                icon = candidate
                            } label: {
                                Image(systemName: candidate)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white : Color.accentColor)
                                    .frame(width: 42, height: 42)
                                    .background(
                                        isSelected
                                            ? AnyShapeStyle(Color.accentColor)
                                            : AnyShapeStyle(Color.accentColor.opacity(0.12)),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(candidate))
                            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                        }
                    }
                    .padding(.vertical, 4)
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

    /// The picker only ever offers real symbol names, so this just guards
    /// against an empty value.
    private var normalizedIcon: String {
        let trimmed = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? CategoryVisuals.fallbackSymbol : trimmed
    }
}

#Preview {
    CategoryEditorView(suggestedKind: .expense) { _, _, _ in }
}
