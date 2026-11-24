import AVFoundation
// Speech predates Sendable annotations; its audio-buffer API is called from the audio tap.
@preconcurrency import Speech
import Observation

@MainActor @Observable
final class VoiceEntryRecorder {
    var transcript = ""
    var isRecording = false
    var isPreparing = false
    var errorMessage: String?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var hasTap = false
    private var generation = UUID()
    private var timeout: Task<Void, Never>?

    func start(localeID: String) async {
        guard !isRecording, !isPreparing else { return }
        isPreparing = true
        errorMessage = nil
        let token = UUID()
        generation = token
        defer { if generation == token { isPreparing = false } }
        // These Objective-C callbacks can run on background queues. Without
        // @Sendable, Swift 6 infers this class's MainActor isolation and traps
        // at callback entry before a continuation or Task can hop actors.
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status)
            }
        }
        guard generation == token else { return }
        guard speech == .authorized else {
            errorMessage = AppLocalization.string("Allow Speech Recognition for Muna in Settings, or type your entry below.", comment: "Voice entry feedback")
            return
        }
        let microphone = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { @Sendable granted in
                continuation.resume(returning: granted)
            }
        }
        guard generation == token else { return }
        guard microphone else {
            errorMessage = AppLocalization.string("Allow Microphone access for Muna in Settings, or type your entry below.", comment: "Voice entry feedback")
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID)),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            errorMessage = AppLocalization.string("Offline speech recognition is unavailable for this language on this iPhone. Try another language or type below.", comment: "Voice entry feedback")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            self.request = request
            transcript = ""
            let node = engine.inputNode
            let format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw NSError(domain: "VoiceEntry", code: 1, userInfo: [NSLocalizedDescriptionKey: "No microphone is available."])
            }
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
                request.append(buffer)
            }
            hasTap = true
            task = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal == true
                let message = error?.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    if let text { self.transcript = text }
                    if final || message != nil {
                        self.stop()
                        if let message { self.errorMessage = message }
                    }
                }
            }
            engine.prepare()
            try engine.start()
            isRecording = true
            timeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(45))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            stop()
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        generation = UUID()
        timeout?.cancel()
        timeout = nil
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        isPreparing = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
