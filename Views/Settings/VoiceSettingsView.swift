import SwiftUI

struct VoiceSettingsView: View {
    @AppStorage("voiceEntryLanguage") private var voiceLanguage = ""
    @AppStorage("voiceShowsExamples") private var showsExamples = true
    @AppStorage("voiceOpensOnPlus") private var opensOnPlus = false
    @AppStorage("voiceStartsAutomatically") private var startsAutomatically = false
    @State private var showsLanguages = false

    var body: some View {
        Form {
            Section {
                Button { showsLanguages = true } label: {
                    HStack(spacing: 12) {
                        Label("Voice language", systemImage: "globe")
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Text(voiceLanguage.isEmpty ? AppLocalization.string("Automatic", comment: "Default speech language") : SpeechLanguages.name(for: voiceLanguage))
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .frame(minHeight: AppTheme.minimumTapTarget)
                }
            } footer: {
                Text("This language is used each time you record. Automatic follows an available offline language from your iPhone preferences.")
            }

            Section {
                Toggle("Show example phrases", isOn: $showsExamples)
            } header: { Text("On the voice screen") }
            footer: { Text("Keep a sample sentence visible, or hide it for a simpler screen.") }

            Section {
                Toggle("Open voice with +", isOn: $opensOnPlus)
            } header: { Text("When adding an entry") }
            footer: { Text("The + button opens voice entry first. Turn this off to start with the amount. Category shortcuts still open their usual form.") }

            Section {
                Toggle("Start listening automatically", isOn: $startsAutomatically)
            } footer: {
                Text("Begin recording when you open the voice screen. Microphone and speech permissions are still required. Turn this off to start recording with a tap.")
            }

            Section {
                Label("You always review before saving.", systemImage: "checkmark.shield")
                    .font(.subheadline).foregroundStyle(.secondary)
            } footer: {
                Text("Speech recognition stays on your iPhone. No entries are saved while recording.")
            }
        }
        .navigationTitle("Voice settings")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, AppTheme.tabBarClearance, for: .scrollContent)
        .sheet(isPresented: $showsLanguages) {
            SpeechLanguagePicker(selection: $voiceLanguage, allowsAutomatic: true)
        }
    }
}
