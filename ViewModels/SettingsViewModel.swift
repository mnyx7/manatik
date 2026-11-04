import Foundation
import UniformTypeIdentifiers

@MainActor
final class SettingsViewModel: ObservableObject {
    // Editing buffers. Nothing here is written until the user commits the
    // field, so typing "1000" no longer performs four full-state disk writes
    // and no longer momentarily sets the target to 1.
    @Published var monthStartDayInput: String
    @Published var goalTargetInput: String
    @Published var goalCurrentInput: String
    @Published var useAmountLeftForProgress: Bool

    /// Set when the user picks a different currency; the view confirms first,
    /// because switching relabels every existing amount without converting it.
    @Published var pendingCurrency: Currency?

    @Published var isShowingExporter = false
    @Published var isShowingImporter = false
    @Published var exportDocument: AppBackupDocument?

    /// Decoded but not yet applied, so the view can state what will be replaced.
    @Published var pendingImport: PendingImport?

    @Published var infoMessage: String?
    @Published var errorMessage: String?
    @Published var monthStartDayError: String?

    // Reminder editing
    @Published var editingReminder: PaymentReminder?
    @Published var isShowingReminderEditor = false

    let store: AppStore

    init(store: AppStore) {
        self.store = store
        let settings = store.state.settings
        monthStartDayInput = String(settings.monthStartDay)
        goalTargetInput = DecimalAmountValidator.editingText(for: settings.savingsGoal.targetAmount)
        goalCurrentInput = DecimalAmountValidator.editingText(for: settings.savingsGoal.currentSavedAmount)
        useAmountLeftForProgress = settings.savingsGoal.useAmountLeftForProgress
    }

    var appVersionText: String { AppVersionProvider.versionText }

    var currentCurrency: Currency { store.state.settings.currency }

    var reminders: [PaymentReminder] { store.state.paymentReminders }

    var entryCountDescription: String {
        String(
            format: NSLocalizedString("%1$d entries, %2$d repeating", comment: "Settings summary"),
            store.state.transactions.count,
            store.state.recurringSeries.count
        )
    }

    // MARK: - Currency

    func requestCurrencyChange(to currency: Currency) {
        guard currency != currentCurrency else { return }
        pendingCurrency = currency
    }

    func confirmCurrencyChange() {
        guard let pendingCurrency else { return }
        store.updateSettings(currency: pendingCurrency)
        self.pendingCurrency = nil
    }

    func cancelCurrencyChange() {
        pendingCurrency = nil
    }

    var currencyChangeWarning: String {
        String(
            format: NSLocalizedString(
                "Amounts are not converted. All %1$d existing entries will simply be shown in %2$@.",
                comment: "Currency warning"
            ),
            store.state.transactions.count,
            pendingCurrency?.rawValue ?? ""
        )
    }

    // MARK: - Period start day (typed in by hand)

    func commitMonthStartDay() {
        let digits = monthStartDayInput.filter(\.isWholeNumber)

        guard let value = Int(digits) else {
            monthStartDayError = NSLocalizedString("Enter a day number.", comment: "Validation")
            monthStartDayInput = String(store.state.settings.monthStartDay)
            return
        }

        if value < DateRangeCalculator.minimumMonthStartDay
            || value > DateRangeCalculator.maximumMonthStartDay {
            monthStartDayError = String(
                format: NSLocalizedString(
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

    // MARK: - Savings goal

    func handleGoalTargetChange(_ newValue: String) {
        goalTargetInput = DecimalAmountValidator.sanitize(newValue)
    }

    func handleGoalCurrentChange(_ newValue: String) {
        goalCurrentInput = DecimalAmountValidator.sanitize(newValue)
    }

    func commitSavingsGoal() {
        let target = DecimalAmountValidator.parsed(from: goalTargetInput)
            ?? store.state.settings.savingsGoal.targetAmount
        let current = DecimalAmountValidator.parsed(from: goalCurrentInput) ?? .zero

        store.updateSettings(
            savingsGoal: SavingsGoal(
                targetAmount: target,
                currentSavedAmount: current,
                useAmountLeftForProgress: useAmountLeftForProgress
            )
        )

        // Reflect whatever normalization the store applied.
        let saved = store.state.settings.savingsGoal
        goalTargetInput = DecimalAmountValidator.editingText(for: saved.targetAmount)
        goalCurrentInput = DecimalAmountValidator.editingText(for: saved.currentSavedAmount)
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

    func prepareExport() {
        do {
            exportDocument = AppBackupDocument(data: try store.exportStateData())
            isShowingExporter = true
        } catch {
            errorMessage = String(
                format: NSLocalizedString("Could not prepare the export: %@", comment: "Error"),
                error.localizedDescription
            )
        }
    }

    /// The exporter result used to be discarded, so a failed write was invisible.
    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            infoMessage = String(
                format: NSLocalizedString("Backup saved to %@", comment: "Confirmation"),
                url.lastPathComponent
            )
        case .failure(let error):
            errorMessage = String(
                format: NSLocalizedString("Export failed: %@", comment: "Error"),
                error.localizedDescription
            )
        }
    }

    /// Decodes the file and stores it as pending. Nothing is replaced until the
    /// user confirms, because an import wipes everything already on the device.
    func handleImportResult(_ result: Result<URL, Error>) {
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
                    format: NSLocalizedString("Import failed: %@", comment: "Error"),
                    error.localizedDescription
                )
            }

        case .failure(let error):
            errorMessage = String(
                format: NSLocalizedString("Import failed: %@", comment: "Error"),
                error.localizedDescription
            )
        }
    }

    var importWarning: String {
        guard let pending = pendingImport else { return "" }
        return String(
            format: NSLocalizedString(
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
        syncFromStore()

        if let snapshot {
            infoMessage = String(
                format: NSLocalizedString(
                    "Backup imported. Your previous data was saved as %@ in the app's Documents folder.",
                    comment: "Confirmation"
                ),
                snapshot.lastPathComponent
            )
        } else {
            infoMessage = NSLocalizedString("Backup imported.", comment: "Confirmation")
        }
    }

    func cancelImport() {
        pendingImport = nil
    }

    private func syncFromStore() {
        let settings = store.state.settings
        monthStartDayInput = String(settings.monthStartDay)
        goalTargetInput = DecimalAmountValidator.editingText(for: settings.savingsGoal.targetAmount)
        goalCurrentInput = DecimalAmountValidator.editingText(for: settings.savingsGoal.currentSavedAmount)
        useAmountLeftForProgress = settings.savingsGoal.useAmountLeftForProgress
    }
}
