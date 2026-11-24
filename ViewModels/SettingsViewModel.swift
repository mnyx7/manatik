//
//  SettingsViewModel.swift
//  muna
//
//  Created by Minaya Yagubova on 04.11.26.
//

import Foundation
import UniformTypeIdentifiers
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    /// Typed by hand and committed when the field loses focus, so a full state
    /// write no longer happens on every keystroke.
    var monthStartDayInput: String

    var isShowingExporter = false
    var isShowingImporter = false
    var exportDocument: AppBackupDocument?

    /// The one file importer serves both kinds; SwiftUI drops a second one.
    enum ImportKind { case backup, csv }
    var importKind: ImportKind = .backup

    /// Read from another app's CSV but not yet added.
    var pendingCSV: CSVImportPreview?

    /// Decoded but not yet applied, so the view can state what will be replaced.
    var pendingImport: PendingImport?

    var infoMessage: String?
    var errorMessage: String?
    var monthStartDayError: String?

    // Reminder editing
    var editingReminder: PaymentReminder?
    var isShowingReminderEditor = false
    var isShowingCategoryEditor = false
    /// Non-nil when the category editor was opened to change an existing one.
    var editingCategory: TransactionCategory?

    let store: AppStore

    init(store: AppStore) {
        self.store = store
        monthStartDayInput = String(store.state.settings.monthStartDay)
    }

    var appVersionText: String { AppVersionProvider.versionText }

    var currentCurrency: Currency { store.state.settings.currency }

    var reminders: [PaymentReminder] { store.state.paymentReminders }

    var customCategories: [TransactionCategory] { store.state.customCategories }

    var entryCountDescription: String {
        String(
            format: AppLocalization.string("%1$d entries, %2$d repeating", comment: "Settings summary"),
            store.state.transactions.count,
            store.state.recurringSeries.count
        )
    }

    var attachmentCount: Int {
        store.state.transactions.reduce(0) { $0 + $1.attachments.count }
    }

    // MARK: - Currency

    var homeStyle: HomeStyle {
        get { store.state.settings.homeStyle }
        set { store.updateSettings(homeStyle: newValue) }
    }

    // MARK: - Currency

    /// Applied straight away, with no confirmation step. Existing entries keep
    /// their own currency; only new entries and the totals follow it.
    var currency: Currency {
        get { store.state.settings.currency }
        set { store.updateSettings(currency: newValue) }
    }

    // MARK: - Period start day

    func commitMonthStartDay() {
        let digits = monthStartDayInput.filter(\.isWholeNumber)

        guard let value = Int(digits) else {
            monthStartDayError = AppLocalization.string("Enter a day number.", comment: "Validation")
            monthStartDayInput = String(store.state.settings.monthStartDay)
            return
        }

        if value < DateRangeCalculator.minimumMonthStartDay
            || value > DateRangeCalculator.maximumMonthStartDay {
            monthStartDayError = String(
                format: AppLocalization.string(
                    "Pick a day between %1$d and %2$d. Later days do not exist in every month.",
                    comment: "Validation"
                ),
                DateRangeCalculator.minimumMonthStartDay,
                DateRangeCalculator.maximumMonthStartDay
            )
        } else {
            monthStartDayError = nil
        }

        let clamped = DateRangeCalculator.clampMonthStartDay(value)
        monthStartDayInput = String(clamped)
        store.updateSettings(monthStartDay: clamped)
    }

    // MARK: - Categories

    // MARK: - Categories

    /// Every category, hidden ones included, in the user's order.
    var allCategories: [TransactionCategory] { store.allCategoriesInOrder }

    var showsRecentsFirst: Bool {
        get { store.state.settings.showsRecentCategoriesFirst }
        set { store.updateSettings(showsRecentCategoriesFirst: newValue) }
    }

    func usageCount(for category: TransactionCategory) -> Int {
        store.transactionCount(usingCategory: category.id)
    }

    func isHidden(_ category: TransactionCategory) -> Bool {
        store.isCategoryHidden(category.id)
    }

    func canHide(_ category: TransactionCategory) -> Bool {
        store.canHideCategory(category.id)
    }

    func setHidden(_ category: TransactionCategory, hidden: Bool) {
        store.setCategoryHidden(category.id, hidden: hidden)
    }

    func moveCategories(from source: IndexSet, to destination: Int) {
        store.moveCategories(from: source, to: destination)
    }

    /// Which list My Categories is showing.
    var managedType: TransactionType = .expense

    var managedCategories: [TransactionCategory] {
        store.categoriesForManaging(managedType)
    }

    func moveManagedCategories(from source: IndexSet, to destination: Int) {
        store.moveCategories(for: managedType, from: source, to: destination)
    }

    func resetCategoryOrder() {
        store.resetCategoryOrder()
    }

    func createCategory(name: String, icon: String, kind: CategoryKind) {
        store.addCustomCategory(name: name, icon: icon, kind: kind)
    }

    func saveCategoryEdit(id: String, name: String, icon: String, kind: CategoryKind) {
        store.updateCustomCategory(id: id, name: name, icon: icon, kind: kind)
    }

    func deleteCustomCategory(_ category: TransactionCategory) {
        store.deleteCustomCategory(id: category.id)
    }

    // MARK: - Reminders

    func addReminder() {
        editingReminder = nil
        isShowingReminderEditor = true
    }

    func editReminder(_ reminder: PaymentReminder) {
        editingReminder = reminder
        isShowingReminderEditor = true
    }

    func saveReminder(_ reminder: PaymentReminder) {
        if store.state.reminder(id: reminder.id) == nil {
            store.addReminder(reminder)
        } else {
            store.updateReminder(reminder)
        }
    }

    func deleteReminder(_ reminder: PaymentReminder) {
        store.deleteReminder(id: reminder.id)
    }

    func toggleReminder(_ reminder: PaymentReminder, isEnabled: Bool) {
        store.setReminderEnabled(id: reminder.id, isEnabled: isEnabled)
    }

    // MARK: - Backup

    func beginBackupImport() {
        importKind = .backup
        isShowingImporter = true
    }

    func beginCSVImport() {
        importKind = .csv
        isShowingImporter = true
    }

    private func handleCSVResult(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            pendingCSV = try CSVImporter.preview(data: try Data(contentsOf: url))
        } catch {
            errorMessage = String(
                format: AppLocalization.string("Import failed: %@", comment: "Error"),
                error.localizedDescription
            )
        }
    }

    /// The question shown before adding: how many, which dates, what is new.
    var csvSummary: String {
        guard let preview = pendingCSV else { return "" }
        var parts: [String] = []
        if let first = preview.firstDate, let last = preview.lastDate {
            parts.append(String(
                format: AppLocalization.string("%1$d entries from %2$@ to %3$@.", comment: "CSV import summary"),
                preview.rows.count,
                DateFormatting.dayMonthYear(first),
                DateFormatting.dayMonthYear(last)
            ))
        }
        let known = Set(store.allCategoriesInOrder.flatMap { [$0.localizedName.lowercased(), $0.name.lowercased()] })
        let newTags = preview.tags.filter { !known.contains($0.lowercased()) }.sorted()
        if !newTags.isEmpty {
            parts.append(String(
                format: AppLocalization.string("New categories: %@.", comment: "CSV import summary"),
                newTags.prefix(6).joined(separator: ", ") + (newTags.count > 6 ? "…" : "")
            ))
        }
        let others = preview.currencies.subtracting([currentCurrency.rawValue])
        if !others.isEmpty {
            parts.append(String(
                format: AppLocalization.string("Entries in %@ keep that currency and are not converted.", comment: "CSV import summary"),
                others.sorted().joined(separator: ", ")
            ))
        }
        if !preview.skippedLines.isEmpty {
            parts.append(String(
                format: AppLocalization.string("%d rows could not be read and will be skipped.", comment: "CSV import summary"),
                preview.skippedLines.count
            ))
        }
        parts.append(AppLocalization.string("Your current entries stay as they are.", comment: "CSV import summary"))
        return parts.joined(separator: "\n\n")
    }

    func confirmCSVImport() {
        guard let preview = pendingCSV else { return }
        let added = store.addImported(preview.rows)
        pendingCSV = nil
        infoMessage = String(
            format: AppLocalization.string("Added %d entries.", comment: "Confirmation"),
            added
        )
    }

    func prepareExport() {
        do {
            exportDocument = AppBackupDocument(data: try store.exportStateData())
            isShowingExporter = true
        } catch {
            errorMessage = String(
                format: AppLocalization.string("Could not prepare the export: %@", comment: "Error"),
                error.localizedDescription
            )
        }
    }

    /// The exporter result used to be discarded, so a failed write was invisible.
    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            infoMessage = String(
                format: AppLocalization.string("Backup saved to %@", comment: "Confirmation"),
                url.lastPathComponent
            )
        case .failure(let error):
            errorMessage = String(
                format: AppLocalization.string("Export failed: %@", comment: "Error"),
                error.localizedDescription
            )
        }
    }

    /// Decodes the file and stores it as pending. Nothing is replaced until the
    /// user confirms, because an import wipes everything already on the device.
    func handleImportResult(_ result: Result<URL, Error>) {
        if importKind == .csv {
            handleCSVResult(result)
            return
        }
        switch result {
        case .success(let url):
            do {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess { url.stopAccessingSecurityScopedResource() }
                }
                let data = try Data(contentsOf: url)
                pendingImport = try store.prepareImport(from: data)
            } catch {
                errorMessage = String(
                    format: AppLocalization.string("Import failed: %@", comment: "Error"),
                    error.localizedDescription
                )
            }

        case .failure(let error):
            errorMessage = String(
                format: AppLocalization.string("Import failed: %@", comment: "Error"),
                error.localizedDescription
            )
        }
    }

    var importWarning: String {
        guard let pending = pendingImport else { return "" }
        return String(
            format: AppLocalization.string(
                "This replaces everything on this device: %1$d entries and %2$d repeating entries will be removed and replaced with %3$d entries and %4$d repeating entries.",
                comment: "Import warning"
            ),
            pending.currentTransactionCount,
            pending.currentSeriesCount,
            pending.incomingTransactionCount,
            pending.incomingSeriesCount
        )
    }

    func confirmImport() {
        guard let pending = pendingImport else { return }
        let snapshot = store.applyImport(pending)
        pendingImport = nil
        monthStartDayInput = String(store.state.settings.monthStartDay)

        if let snapshot {
            infoMessage = String(
                format: AppLocalization.string(
                    "Backup imported. Your previous data was saved as %@ in the app's Documents folder.",
                    comment: "Confirmation"
                ),
                snapshot.lastPathComponent
            )
        } else {
            infoMessage = AppLocalization.string("Backup imported.", comment: "Confirmation")
        }
    }

    func cancelImport() {
        pendingImport = nil
    }
}
