import SwiftUI
import AVFoundation

struct VoiceEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var recorder = VoiceEntryRecorder()
    @AppStorage("voiceEntryLanguage") private var language = Locale.current.language.languageCode?.identifier == "ru" ? "ru-RU" : Locale.current.language.languageCode?.identifier == "az" ? "az-AZ" : "en-US"
    @State private var parseError: String?
    let currency: Currency
    let categories: [TransactionCategory]
    let onReview: (VoiceEntryParser.Result) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Say one entry, then review its amount, currency and category before saving.")
                    Text("“Five manat at a cafe, add to bills” or “Income salary 100 USD”.")
                        .foregroundStyle(.secondary)
                }
                Section("Speech language") {
                    Picker("Language", selection: $language) {
                        Text("English").tag("en-US")
                        Text("Русский").tag("ru-RU")
                        Text("Azərbaycanca").tag("az-AZ")
                    }
                    .disabled(recorder.isRecording || recorder.isPreparing)
                    Text("Uses on-device recognition when available. Audio is not sent to a server. Language support depends on your iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button {
                        if recorder.isRecording { recorder.stop() }
                        else { Task { await recorder.start(localeID: language) } }
                    } label: {
                        Label(recorder.isPreparing ? "Preparing…" : recorder.isRecording ? "Stop recording" : "Start recording",
                              systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.fill")
                    }
                    .disabled(recorder.isPreparing)
                    if recorder.isRecording { Text("Listening… Tap Stop when finished.").foregroundStyle(.secondary) }
                    if let error = recorder.errorMessage { Text(error).foregroundStyle(.red) }
                }
                Section("Your words") {
                    TextEditor(text: $recorder.transcript)
                        .frame(minHeight: 110)
                        .disabled(recorder.isRecording || recorder.isPreparing)
                    Text("You can correct the text or type a command here. Unmatched categories use Other. Date defaults to today; change it in the review form.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let parseError { Section { Text(parseError).foregroundStyle(.red) } }
                Section {
                    Button("Review entry") {
                        do {
                            let result = try VoiceEntryParser.parse(recorder.transcript, currency: currency, categories: categories)
                            onReview(result)
                            dismiss()
                        } catch { parseError = error.localizedDescription }
                    }
                    .disabled(recorder.isRecording || recorder.isPreparing || recorder.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("Nothing is saved until you tap Save on the next screen.")
                }
            }
            .navigationTitle("Voice entry")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onChange(of: scenePhase) { _, phase in if phase == .background { recorder.stop() } }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
                if recorder.isRecording { recorder.stop() }
            }
            .onDisappear { recorder.stop() }
        }
    }
}
