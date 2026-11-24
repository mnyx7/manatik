import SwiftUI
import AVFoundation

struct VoiceEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var recorder = VoiceEntryRecorder()
    @AppStorage("voiceEntryLanguage") private var defaultLanguage = ""
    @State private var languages: [SpeechLanguage] = []
    @State private var language = ""
    @State private var showsLanguages = false
    @State private var parseError: String?
    @State private var showsReplaceConfirmation = false
    @FocusState private var isEditing: Bool
    let currency: Currency
    let categories: [TransactionCategory]
    let onReview: (VoiceEntryParser.Result) -> Void

    private var busy: Bool { recorder.isRecording || recorder.isPreparing }
    private var hasText: Bool { !recorder.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var selectedLanguage: SpeechLanguage? { languages.first { $0.id == language } }
    private var canRecord: Bool { selectedLanguage?.supportsOffline == true }
    private var example: String {
        switch Locale(identifier: language).language.languageCode?.identifier {
        case "ru": return "«Пять манат в кафе»"
        case "az": return "“Kafedə beş manat”"
        default: return "“Five manat at a cafe”"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Text("Just say the entry")
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                        Text("An amount, what it was for, and a currency if you need one.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text(verbatim: example)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                        Text("Say “income” for money in, or “bills” to bookmark it.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    VStack(spacing: 14) {
                        Button {
                            isEditing = false
                            parseError = nil
                            if recorder.isRecording { recorder.stop() }
                            else if hasText { showsReplaceConfirmation = true }
                            else { Task { await recorder.start(localeID: language) } }
                        } label: {
                            Image(systemName: recorder.isPreparing ? "hourglass" : recorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(recorder.isRecording ? AppTheme.expenseAccent : AppTheme.savingsAccent)
                                .frame(width: 88, height: 88)
                                .liquidGlass(in: .circle, tint: (recorder.isRecording ? AppTheme.expenseAccent : AppTheme.savingsAccent).opacity(0.12), interactive: true)
                        }
                        .buttonStyle(.plain)
                        .disabled(recorder.isPreparing || (!canRecord && !recorder.isRecording))
                        .accessibilityLabel(recorder.isRecording ? Text("Stop recording") : Text("Start recording"))
                        .sensoryFeedback(.selection, trigger: recorder.isRecording)
                        Text(recorder.isPreparing ? "Getting ready…" : recorder.isRecording ? "Listening. Tap to finish." : hasText ? "Tap to record again" : "Tap to speak")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(recorder.isRecording ? AppTheme.expenseAccent : .secondary)
                            .accessibilityAddTraits(.updatesFrequently)
                        Button { showsLanguages = true } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "globe")
                                Text(verbatim: SpeechLanguages.name(for: language))
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                            }
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .frame(minHeight: AppTheme.minimumTapTarget)
                        }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .disabled(busy)
                        .accessibilityLabel(Text("Voice language"))
                        .accessibilityValue(SpeechLanguages.name(for: language))
                    }

                    if let error = recorder.errorMessage { message(error) }
                    if !languages.isEmpty && !canRecord {
                        message(AppLocalization.string("Offline recording isn’t available for this language. Choose another language or type below.", comment: "Speech unavailable"))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your words").font(.subheadline.weight(.semibold))
                            Spacer()
                            if hasText && !busy {
                                Button("Clear") { recorder.transcript = ""; parseError = nil }
                                    .font(.footnote)
                            }
                        }
                        ZStack(alignment: .topLeading) {
                            if !hasText {
                                Text("Your words will appear here. You can also type.")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8).padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $recorder.transcript)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 110, maxHeight: 180)
                                .focused($isEditing)
                                .disabled(busy)
                                .accessibilityLabel(Text("Your words"))
                        }
                        if hasText && !busy {
                            Label("You can edit this before continuing.", systemImage: "pencil")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .glassCard()
                    if let parseError { message(parseError) }
                }
                .padding(.horizontal, AppTheme.pageHorizontalPadding)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackgroundView())
            .safeAreaInset(edge: .bottom) { reviewBar }
            .navigationTitle("Voice entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isEditing = false }
                }
            }
            .confirmationDialog("Replace your words?", isPresented: $showsReplaceConfirmation, titleVisibility: .visible) {
                Button("Record again", role: .destructive) { Task { await recorder.start(localeID: language) } }
                Button("Keep text", role: .cancel) {}
            } message: { Text("A new recording will replace the text below.") }
            .sheet(isPresented: $showsLanguages) { SpeechLanguagePicker(selection: $language) }
            .task {
                languages = SpeechLanguages.all()
                language = SpeechLanguages.resolvedID(defaultLanguage, in: languages)
                #if DEBUG
                if let text = QALaunch.value(for: "-qa-transcript") { recorder.transcript = text }
                #endif
            }
            .onChange(of: recorder.transcript) { _, _ in parseError = nil }
            .onChange(of: scenePhase) { _, phase in if phase == .background { recorder.stop() } }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
                if recorder.isRecording { recorder.stop() }
            }
            .onDisappear { recorder.stop() }
        }
    }

    private var reviewBar: some View {
        VStack(spacing: 10) {
            Button {
                isEditing = false
                do {
                    let result = try VoiceEntryParser.parse(recorder.transcript, currency: currency, categories: categories, localeID: language)
                    onReview(result)
                    dismiss()
                } catch { parseError = error.localizedDescription }
            } label: {
                HStack {
                    Text("Review entry")
                    Image(systemName: "arrow.right")
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .glassProminentButtonStyle()
            .tint(AppTheme.savingsAccent)
            .disabled(busy || !hasText)
            Text("Check the details next. Save only when you’re ready.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppTheme.pageHorizontalPadding)
        .padding(.top, 12).padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private func message(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.footnote).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
