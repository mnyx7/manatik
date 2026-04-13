import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            settingsForm
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        viewModel.persistSettings()
                        dismiss()
                    }
                }
            }
            .onChange(of: viewModel.selectedCurrency) {
                viewModel.persistSettings()
            }
            .onChange(of: viewModel.useAmountLeftForProgress) {
                viewModel.persistSettings()
            }
            .fileExporter(
                isPresented: $viewModel.isShowingExporter,
                document: viewModel.exportDocument,
                contentType: .json,
                defaultFilename: "manatik-backup"
            ) { _ in }
            .fileImporter(
                isPresented: $viewModel.isShowingImporter,
                allowedContentTypes: [.json]
            ) { result in
                viewModel.handleImportResult(result)
            }
            .alert("Error", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.importErrorMessage ?? "")
            }
            .alert("Done", isPresented: doneAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.toastMessage ?? "")
            }
        }
    }

    private var settingsForm: some View {
        Form {
            Section("General") {
                Picker("Currency", selection: $viewModel.selectedCurrency) {
                    ForEach(Currency.allCases) { currency in
                        Text(currency.rawValue).tag(currency)
                    }
                }

                Stepper(value: $viewModel.monthStartDay, in: 1...31) {
                    Text("Month starts on day \(viewModel.monthStartDay)")
                }
                .onChange(of: viewModel.monthStartDay) {
                    viewModel.persistSettings()
                }
            }

            Section("Savings Goal") {
                TextField("Target amount", text: goalTargetBinding)
                    .keyboardType(.decimalPad)
                    .onChange(of: viewModel.goalTargetInput) {
                        viewModel.persistSettings()
                    }

                TextField("Current saved amount", text: goalCurrentBinding)
                    .keyboardType(.decimalPad)
                    .onChange(of: viewModel.goalCurrentInput) {
                        viewModel.persistSettings()
                    }

                Toggle("Use amount left for progress", isOn: $viewModel.useAmountLeftForProgress)
            }

            Section("Backup") {
                Button("Export Data") {
                    viewModel.persistSettings()
                    viewModel.prepareExport()
                }

                Button("Import Backup") {
                    viewModel.isShowingImporter = true
                }
            }

            Section("About") {
                Text("manatik is a local-first personal budget tracker for quick daily financial control.")
                    .font(.footnote)
            }

            Section {
                Text(viewModel.appVersionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var goalTargetBinding: Binding<String> {
        Binding(
            get: { viewModel.goalTargetInput },
            set: { viewModel.updateGoalTargetInput($0) }
        )
    }

    private var goalCurrentBinding: Binding<String> {
        Binding(
            get: { viewModel.goalCurrentInput },
            set: { viewModel.updateGoalCurrentInput($0) }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.importErrorMessage != nil },
            set: { shown in
                if !shown {
                    viewModel.importErrorMessage = nil
                }
            }
        )
    }

    private var doneAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.toastMessage != nil },
            set: { shown in
                if !shown {
                    viewModel.toastMessage = nil
                }
            }
        )
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(store: AppStore()))
}
