import SwiftUI
import AVFoundation

struct VoiceEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var recorder = VoiceEntryRecorder()
    @AppStorage("voiceEntryLanguage") private var defaultLanguage = ""
    @State private var languages: [SpeechLanguage] = []
    @State private var language = ""
    @AppStorage("voiceShowsExamples") private var showsExamples = true
    @AppStorage("voiceStartsAutomatically") private var startsAutomatically = false
    @State private var attemptedAutomaticStart = false
    @State private var parseError: String?
    @State private var reviewRequested = false
    @State private var showsReplaceConfirmation = false
    @FocusState private var isEditing: Bool
    let currency: Currency
    let categories: [TransactionCategory]
    var onManualEntry: (() -> Void)? = nil
    let onReview: (VoiceEntryParser.Result) -> Void

    private var busy: Bool { recorder.isRecording || recorder.isPreparing || recorder.isFinalizing }
    private var reviewReady: Bool { reviewRequested && !busy }
    private var canRequestReview: Bool { !recorder.isPreparing && !reviewRequested && (recorder.isRecording || recorder.isFinalizing || hasText) }
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
                        if showsExamples {
                            Text(verbatim: example)
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                            Text("Say “income” for money in, or “bills” to bookmark it.")
                                .font(.footnote).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 12)

                    VStack(spacing: 14) {
                        Button {
                            attemptedAutomaticStart = true
                            isEditing = false
                            parseError = nil
                            if recorder.isRecording { recorder.finish() }
                            else if hasText { showsReplaceConfirmation = true }
                            else { Task { await startRecording() } }
                        } label: {
                            Image(systemName: (recorder.isPreparing || recorder.isFinalizing) ? "hourglass" : recorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(recorder.isRecording ? AppTheme.expenseAccent : AppTheme.savingsAccent)
                                .frame(width: 64, height: 64)
                                .liquidGlass(in: .circle, tint: (recorder.isRecording ? AppTheme.expenseAccent : AppTheme.savingsAccent).opacity(0.12), interactive: true)
                        }
                        .buttonStyle(.plain)
                        .disabled(recorder.isPreparing || recorder.isFinalizing || (!canRecord && !recorder.isRecording))
                        .accessibilityLabel(recorder.isRecording ? Text("Stop recording") : Text("Start recording"))
                        .sensoryFeedback(.selection, trigger: recorder.isRecording)
                        Text(recorder.isFinalizing ? "Finishing…" : recorder.isPreparing ? "Getting ready…" : recorder.isRecording ? "Listening. Tap to finish." : hasText ? "Tap to record again" : "Tap to speak")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(recorder.isRecording ? AppTheme.expenseAccent : .secondary)
                            .accessibilityAddTraits(.updatesFrequently)

                    }

                    if let error = recorder.errorMessage { message(error) }
                    if !languages.isEmpty && !canRecord {
                        message(AppLocalization.string("Offline recording isn’t available for this language. Change the language in Voice settings or type below.", comment: "Speech unavailable"))
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { reviewRequested = false; dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        VoiceSettingsView()
                    } label: { Image(systemName: "gearshape") }
                    .disabled(busy)
                    .accessibilityLabel(Text("Voice settings"))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isEditing = false }
                }
            }
            .confirmationDialog("Replace your words?", isPresented: $showsReplaceConfirmation, titleVisibility: .visible) {
                Button("Record again", role: .destructive) { Task { await startRecording() } }
                Button("Keep text", role: .cancel) {}
            } message: { Text("A new recording will replace the text below.") }
            .task {
                languages = SpeechLanguages.all()
                language = SpeechLanguages.resolvedID(defaultLanguage, in: languages)
                #if DEBUG
                if let text = QALaunch.value(for: "-qa-transcript") { recorder.transcript = text }
                #endif
                await startAutomaticallyIfNeeded()
            }
            .task(id: reviewReady) {
                // Key off the combined state, not a single flag transition:
                // a fast final result may arrive before SwiftUI renders Stop.
                guard reviewReady, !Task.isCancelled else { return }
                reviewRequested = false
                guard scenePhase == .active, recorder.errorMessage == nil else { return }
                reviewTranscript()
            }
            .onChange(of: recorder.transcript) { _, _ in parseError = nil }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { reviewRequested = false; attemptedAutomaticStart = true; recorder.stop() }
                else if phase == .active { Task { await startAutomaticallyIfNeeded() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
                if recorder.isRecording { recorder.finish() }
            }
            .onDisappear { reviewRequested = false; attemptedAutomaticStart = true; recorder.stop() }
        }
    }

    @MainActor
    private func startRecording() async {
        await recorder.start(localeID: language,
                             contextualStrings: VoiceEntryParser.recognitionHints(categories: categories, localeID: language))
    }

    @MainActor
    private func startAutomaticallyIfNeeded() async {
        // One attempt per screen presentation. Permission dialogs, stopping,
        // interruptions and returning from Settings must not restart the mic.
        guard startsAutomatically, !attemptedAutomaticStart, scenePhase == .active,
              !language.isEmpty, canRecord, !hasText, !busy, !Task.isCancelled else { return }
        attemptedAutomaticStart = true
        await startRecording()
    }

    private var reviewBar: some View {
        VStack(spacing: 10) {
            Button {
                isEditing = false
                parseError = nil
                if recorder.isRecording || recorder.isFinalizing {
                    reviewRequested = true
                    recorder.finish()
                } else {
                    reviewTranscript()
                }
            } label: {
                HStack {
                    if reviewRequested {
                        ProgressView().controlSize(.small)
                        Text("Finishing…")
                    } else {
                        Text("Review entry")
                        Image(systemName: "arrow.right")
                    }
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .glassProminentButtonStyle()
            .tint(AppTheme.savingsAccent)
            .disabled(!canRequestReview)
            if let onManualEntry {
                Button("Enter manually") {
                    reviewRequested = false
                    recorder.stop()
                    onManualEntry()
                    dismiss()
                }
                .font(.footnote.weight(.medium))
                .frame(minHeight: AppTheme.minimumTapTarget)
            }
            Text("Check the details next. Save only when you’re ready.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppTheme.pageHorizontalPadding)
        .padding(.top, 12).padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private func reviewTranscript() {
        do {
            let result = try VoiceEntryParser.parse(recorder.transcript, currency: currency, categories: categories, localeID: language)
            onReview(result)
            dismiss()
        } catch { parseError = error.localizedDescription }
    }

    private func message(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.footnote).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
