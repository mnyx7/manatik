import SwiftUI

struct TransactionFormView: View {
    private enum Field: Hashable {
        case amount
        case note
    }

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TransactionFormViewModel
    @FocusState private var focusedField: Field?

    @State private var isShowingScopeChoice = false
    @State private var isShowingDeleteChoice = false
    @State private var isSearchingCategories = false

    init(store: AppStore, mode: TransactionFormViewModel.Mode) {
        _viewModel = State(wrappedValue: TransactionFormViewModel(store: store, mode: mode))
    }

    private var currency: Currency { viewModel.currency }
    private var accent: Color { AppTheme.accent(for: viewModel.type) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let context = viewModel.linkedContextDescription {
                        Label(context, systemImage: "link")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    amountCard
                    categoryCard

                    if viewModel.canEditRecurrence {
                        repeatCard
                    }

                    if let error = viewModel.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.expenseAccent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if viewModel.isAdding {
                        saveButtons
                    }

                    if viewModel.editingOccurrence != nil {
                        Button(role: .destructive) {
                            isShowingDeleteChoice = true
                        } label: {
                            Label("Delete entry", systemImage: "trash")
                                .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
                        }
                        .buttonStyle(.glass)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .background(AppBackgroundView())
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .defaultFocus($focusedField, .amount)
            .task {
                // defaultFocus alone does not raise the keyboard in a sheet.
                // A new entry starts with the amount, so open it straight away;
                // the short wait lets the sheet finish presenting first.
                guard viewModel.isAdding else { return }
                try? await Task.sleep(for: .milliseconds(350))
                focusedField = .amount
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                // The bill marker is a small icon beside Save, not a row of
                // its own.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isFeatured.toggle()
                    } label: {
                        Image(systemName: viewModel.isFeatured ? "bookmark.fill" : "bookmark")
                    }
                    .foregroundStyle(viewModel.isFeatured ? AppTheme.expenseAccent : .secondary)
                    .accessibilityLabel(Text("Save as a bill"))
                    .accessibilityAddTraits(viewModel.isFeatured ? [.isSelected] : [])
                }

                ToolbarItem(placement: .topBarTrailing) {
                    // Grey until the entry is complete, then a filled button
                    // in the entry's colour, so it is obvious it can be saved.
                    Button(viewModel.saveButtonTitle) { attemptSave(thenDismiss: true) }
                        .fontWeight(.semibold)
                        .buttonStyle(.glassProminent)
                        .tint(viewModel.isFormValid ? accent : Color.secondary.opacity(0.35))
                        .disabled(!viewModel.isFormValid)
                        .animation(.smooth(duration: 0.2), value: viewModel.isFormValid)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onChange(of: viewModel.type) { _, _ in
                viewModel.handleTypeChange()
            }
            .sheet(isPresented: $viewModel.isShowingCurrencyPicker) {
                CurrencyPickerView(
                    title: "Currency",
                    selection: viewModel.currency,
                    pinned: viewModel.store.pinnedCurrencies
                ) { viewModel.currency = $0 }
            }
            .sheet(isPresented: $viewModel.isShowingCategoryEditor) {
                CategoryEditorView(suggestedKind: viewModel.type == .income ? .income : .expense) {
                    name, icon, kind in
                    viewModel.createCategory(name: name, icon: icon, kind: kind)
                }
            }
            .confirmationDialog(
                "This is a repeating entry",
                isPresented: $isShowingScopeChoice,
                titleVisibility: .visible
            ) {
                Button("Change only this one") { commit(scope: .thisOccurrenceOnly) }
                Button("Change this and all future") { commit(scope: .thisAndFutureOccurrences) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Earlier entries keep the amounts they were recorded with.")
            }
            .confirmationDialog(
                deleteTitle,
                isPresented: $isShowingDeleteChoice,
                titleVisibility: .visible
            ) {
                deleteActions
            }
            .overlay(alignment: .bottom) {
                if let confirmation = viewModel.savedConfirmation {
                    SavedToastView(message: confirmation)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(1.6))
                            viewModel.savedConfirmation = nil
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.savedConfirmation)
        }
    }

    // MARK: - Amount

    private var amountCard: some View {
        VStack(spacing: 10) {
            Picker(selection: $viewModel.type) {
                ForEach(TransactionType.allCases) { type in
                    Text(type.localizedTitle).tag(type)
                }
            } label: {
                Text("Type")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(viewModel.isLinkedEntry)

            // A small pill rather than a full labelled row: the date matters,
            // but not as much as the amount under it.
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                DatePicker(
                    "Date",
                    selection: $viewModel.date,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .datePickerStyle(.compact)

                if !Calendar.current.isDateInToday(viewModel.date) {
                    Button("Today") {
                        viewModel.date = Date()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }
            }
            .frame(maxWidth: .infinity)

            // The amount is the reason the screen exists, so it gets the size.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // The symbol is the currency switch: one tap, no extra row.
                Button {
                    viewModel.isShowingCurrencyPicker = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(currency.symbol)
                            .font(.title.weight(.medium))
                        if viewModel.canChangeCurrency {
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .foregroundStyle(viewModel.isInOtherCurrency ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(minWidth: AppTheme.minimumTapTarget, minHeight: AppTheme.minimumTapTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canChangeCurrency)
                .accessibilityLabel(Text("Currency"))
                .accessibilityValue(Text(currency.localizedName))

                TextField(
                    "0",
                    text: Binding(
                        get: { viewModel.amountInput },
                        set: { viewModel.handleAmountChange($0) }
                    )
                )
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.leading)
                .fixedSize()
                .focused($focusedField, equals: .amount)
                .accessibilityLabel(Text("Amount"))
            }
            // .fixedSize keeps the field only as wide as "0", so the whole row
            // takes the tap and hands it to the field.
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(.rect)
            .onTapGesture { focusedField = .amount }

            if viewModel.isInOtherCurrency {
                Text("Kept in \(currency.rawValue). Totals add up \(viewModel.store.mainCurrency.rawValue) entries only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            Divider()

            // Note and paperclip share one caption-sized line; what is attached
            // gets its own row, big enough to see and to reopen.
            HStack(spacing: 6) {
                TextField("Add note or attachment", text: $viewModel.note, axis: .vertical)
                    .font(.footnote)
                    .lineLimit(1...2)
                    .focused($focusedField, equals: .note)
                    .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget, alignment: .leading)
                    .contentShape(.rect)
                    .onTapGesture { focusedField = .note }

                AttachmentButton(attachments: $viewModel.attachments)
            }

            if !viewModel.attachments.isEmpty {
                AttachmentGalleryView(attachments: $viewModel.attachments)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy, value: viewModel.attachments.count)
        .animation(.snappy, value: viewModel.currency)
        .glassCard(tint: accent, tintOpacity: 0.09, padding: 16)
    }

    // MARK: - Category

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Category")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !viewModel.isLinkedEntry {
                    Button {
                        withAnimation(.smooth(duration: 0.22)) { isSearchingCategories.toggle() }
                    } label: {
                        Image(systemName: isSearchingCategories ? "xmark" : "magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: AppTheme.minimumTapTarget, height: 32)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text(isSearchingCategories ? "Close search" : "Search categories"))
                }
            }

            CategoryChipsView(
                recent: viewModel.recentCategories,
                all: viewModel.availableCategories,
                selectedID: $viewModel.selectedCategoryID,
                onAddNew: viewModel.isLinkedEntry
                    ? nil
                    : { viewModel.isShowingCategoryEditor = true },
                isSearching: $isSearchingCategories
            )
            .disabled(viewModel.isLinkedEntry)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Repeat

    private var repeatCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Repeat", systemImage: "repeat")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Picker(selection: $viewModel.recurrenceRule) {
                    ForEach(RecurrenceRule.allCases) { rule in
                        Text(rule.localizedTitle).tag(rule)
                    }
                } label: {
                    Text("Repeat")
                }
                .labelsHidden()
            }
            .frame(minHeight: AppTheme.minimumTapTarget)

            if viewModel.recurrenceRule.repeats {
                Divider()

                Toggle("Has an end date", isOn: $viewModel.hasEndDate)
                    .font(.subheadline)

                if viewModel.hasEndDate {
                    DatePicker(
                        "Ends",
                        selection: $viewModel.endDate,
                        in: viewModel.date...,
                        displayedComponents: [.date]
                    )
                    .font(.subheadline)
                }

                Text("Dates up to today are recorded as real entries. Later dates show as forecasts.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Save

    private var saveButtons: some View {
        Button {
            attemptSave(thenDismiss: false)
        } label: {
            Label("Save and add another", systemImage: "plus.circle")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapTarget)
        }
        .buttonStyle(.glassProminent)
        .tint(viewModel.isFormValid ? accent : Color.secondary.opacity(0.35))
        .disabled(!viewModel.isFormValid)
        .animation(.smooth(duration: 0.2), value: viewModel.isFormValid)
        .padding(.top, 2)
    }

    // MARK: - Delete

    private var deleteTitle: LocalizedStringKey {
        guard let occurrence = viewModel.editingOccurrence, occurrence.isRecurring else {
            return "Delete this entry?"
        }
        return "This is a repeating entry"
    }

    @ViewBuilder
    private var deleteActions: some View {
        if let occurrence = viewModel.editingOccurrence {
            if occurrence.isRecurring {
                Button("Delete only this one", role: .destructive) {
                    viewModel.store.deleteOccurrence(occurrence, scope: .thisOccurrenceOnly)
                    dismiss()
                }
                Button("Delete this and all future", role: .destructive) {
                    viewModel.store.deleteOccurrence(occurrence, scope: .thisAndFutureOccurrences)
                    dismiss()
                }
                Button("Delete the whole series, including history", role: .destructive) {
                    viewModel.store.deleteOccurrence(occurrence, scope: .entireSeriesIncludingHistory)
                    dismiss()
                }
            } else {
                Button("Delete", role: .destructive) {
                    viewModel.store.deleteOccurrence(occurrence, scope: .thisOccurrenceOnly)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Actions

    private func attemptSave(thenDismiss: Bool) {
        focusedField = nil

        guard viewModel.draft() != nil else {
            viewModel.save()
            return
        }

        if viewModel.requiresScopeChoice {
            isShowingScopeChoice = true
            return
        }

        if thenDismiss {
            commit(scope: .thisOccurrenceOnly)
        } else if viewModel.saveAndStartAnother() {
            focusedField = .amount
        }
    }

    private func commit(scope: RecurrenceEditScope) {
        if viewModel.save(scope: scope) {
            dismiss()
        }
    }
}

/// Brief inline confirmation, so "Save and add another" visibly did something.
struct SavedToastView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.incomeAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .glassEffect(.regular.tint(AppTheme.incomeAccent.opacity(0.18)), in: .capsule)
            .accessibilityAddTraits(.isStaticText)
    }
}
