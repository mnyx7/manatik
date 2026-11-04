import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedCurrency: Currency
    @Published var monthStartDay: Int
    @Published var goalTargetInput: String
    @Published var goalCurrentInput: String
    @Published var useAmountLeftForProgress: Bool

    @Published var isShowingExporter = false
    @Published var isShowingImporter = false
    @Published var exportDocument: AppBackupDocument?
    @Published var toastMessage: String?
    @Published var importErrorMessage: String?

    let store: AppStore

    init(store: AppStore) {
        self.store = store
        let settings = store.state.settings
        selectedCurrency = settings.currency
        monthStartDay = settings.monthStartDay
        goalTargetInput = String(format: "%.2f", settings.savingsGoal.targetAmount)
        goalCurrentInput = String(format: "%.2f", settings.savingsGoal.currentSavedAmount)
        useAmountLeftForProgress = settings.savingsGoal.useAmountLeftForProgress
    }

    var appVersionText: String {
        AppVersionProvider.versionText
    }

    var supportedBackupType: UTType {
        .json
    }

    func updateGoalTargetInput(_ newValue: String) {
        guard DecimalAmountValidator.isValidAmountInput(newValue) else { return }
        goalTargetInput = DecimalAmountValidator.sanitize(newValue)
    }

    func updateGoalCurrentInput(_ newValue: String) {
        guard DecimalAmountValidator.isValidAmountInput(newValue) else { return }
        goalCurrentInput = DecimalAmountValidator.sanitize(newValue)
    }

    func persistSettings() {
        let target = DecimalAmountValidator.parsedAmount(from: goalTargetInput) ?? 1
        let current = DecimalAmountValidator.parsedAmount(from: goalCurrentInput) ?? 0
        let savingsGoal = SavingsGoal(
            targetAmount: target,
            currentSavedAmount: current,
            useAmountLeftForProgress: useAmountLeftForProgress
        )

        store.updateSettings(
            currency: selectedCurrency,
            monthStartDay: monthStartDay,
            savingsGoal: savingsGoal
        )
    }

    func prepareExport() {
        do {
            let data = try store.exportStateData()
            exportDocument = AppBackupDocument(data: data)
            isShowingExporter = true
        } catch {
            importErrorMessage = "Failed to prepare export: \(error.localizedDescription)"
        }
    }

    func handleImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let data = try Data(contentsOf: url)
                try store.importStateData(data)
                syncFromStore()
                toastMessage = "Backup imported successfully"
            } catch {
                importErrorMessage = "Import failed: \(error.localizedDescription)"
            }

        case .failure(let error):
            importErrorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func syncFromStore() {
        let settings = store.state.settings
        selectedCurrency = settings.currency
        monthStartDay = settings.monthStartDay
        goalTargetInput = String(format: "%.2f", settings.savingsGoal.targetAmount)
        goalCurrentInput = String(format: "%.2f", settings.savingsGoal.currentSavedAmount)
        useAmountLeftForProgress = settings.savingsGoal.useAmountLeftForProgress
    }
}
