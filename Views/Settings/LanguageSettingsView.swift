import SwiftUI

struct LanguageSettingsSection: View {
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("voiceEntryLanguage") private var voiceLanguage = ""
    @State private var showsSpeechLanguages = false

    var body: some View {
        Section {
            Picker(selection: $appLanguage) {
                Text("Follow iPhone").tag("system")
                Text(verbatim: "English").tag("en")
                Text(verbatim: "Русский").tag("ru")
                Text(verbatim: "Azərbaycanca").tag("az")
            } label: { Label("App language", systemImage: "globe") }
            Button { showsSpeechLanguages = true } label: {
                HStack {
                    Label("Voice language", systemImage: "mic")
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 12)
                    Text(voiceLanguage.isEmpty ? AppLocalization.string("Automatic", comment: "Default speech language") : SpeechLanguages.name(for: voiceLanguage))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .multilineTextAlignment(.trailing)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .frame(minHeight: AppTheme.minimumTapTarget)
            }
            .sheet(isPresented: $showsSpeechLanguages) {
                SpeechLanguagePicker(selection: $voiceLanguage, allowsAutomatic: true)
            }
        } header: { Text("Language & voice") }
        footer: { Text("Choose Muna’s language and the language you usually speak. You can change the voice language before recording.") }
    }
}

/// Includes every locale reported by Apple; unavailable offline locales remain
/// visible with an explanation instead of promising unsupported recognition.
struct SpeechLanguagePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String
    var allowsAutomatic = false
    @State private var languages: [SpeechLanguage] = []
    @State private var query = ""

    private var filtered: [SpeechLanguage] {
        languages.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
            || $0.nativeName.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if allowsAutomatic && query.isEmpty {
                    Section {
                        Button {
                            selection = ""
                            dismiss()
                        } label: {
                            HStack {
                                Text("Automatic").foregroundStyle(.primary)
                                Spacer()
                                if selection.isEmpty { Image(systemName: "checkmark").foregroundStyle(AppTheme.savingsAccent) }
                            }.frame(minHeight: AppTheme.minimumTapTarget)
                        }
                    } footer: { Text("Uses an available offline language matching your iPhone preferences.") }
                }
                if !languages.isEmpty && filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
                Section {
                    ForEach(filtered.filter(\.supportsOffline)) { row($0) }
                } header: { Text("Available on this iPhone") }
                Section {
                    ForEach(filtered.filter { !$0.supportsOffline }) { row($0) }
                } header: { Text("Other Apple Speech languages") }
                footer: { Text("These languages are reported by Apple but are not available for offline recording on this iPhone. Muna keeps your audio on your device.") }
            }
            .searchable(text: $query, prompt: "Find a language")
            .navigationTitle("Voice language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task { languages = SpeechLanguages.all() }
        }
    }

    private func row(_ language: SpeechLanguage) -> some View {
        Button {
            selection = language.id
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(language.name).foregroundStyle(.primary)
                    if language.nativeName != language.name {
                        Text(language.nativeName).font(.caption).foregroundStyle(.secondary)
                    }
                    if !language.supportsOffline { Text("Unavailable offline").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 8)
                if !selection.isEmpty && SpeechLanguages.resolvedID(selection, in: languages) == language.id {
                    Image(systemName: "checkmark").foregroundStyle(AppTheme.savingsAccent)
                }
            }
            .frame(minHeight: AppTheme.minimumTapTarget)
            .contentShape(.rect)
        }
        .disabled(!language.supportsOffline)
        .accessibilityValue(language.supportsOffline ? Text("Available offline") : Text("Unavailable offline"))
    }
}
