// Test-only stand-ins for hardware APIs. The runner compiles the production
// recorder against these so finalization and callback races need no microphone.
import Foundation

@MainActor final class AVAudioEngine {
    let inputNode = AudioNode()
    func prepare() {}
    func start() throws {}
    func stop() {}
}
@MainActor final class AudioNode {
    struct Format { var sampleRate = 44100.0; var channelCount = 1 }
    func outputFormat(forBus: Int) -> Format { Format() }
    func installTap(onBus: Int, bufferSize: Int, format: Format, block: @escaping @Sendable (Int, Int) -> Void) {}
    func removeTap(onBus: Int) {}
}
@MainActor final class AVAudioSession {
    enum Category { case record }
    enum Mode { case measurement }
    struct Options: OptionSet { let rawValue: Int; static let duckOthers = Self(rawValue: 1); static let notifyOthersOnDeactivation = Self(rawValue: 2) }
    private static let shared = AVAudioSession()
    static func sharedInstance() -> AVAudioSession { shared }
    func setCategory(_ category: Category, mode: Mode, options: Options) throws {}
    func setActive(_ active: Bool, options: Options = []) throws {}
}
enum AVAudioApplication {
    static func requestRecordPermission(_ callback: @escaping @Sendable (Bool) -> Void) {
        Task.detached { callback(true) }
    }
}
final class SFSpeechAudioBufferRecognitionRequest: @unchecked Sendable {
    enum Hint { case unspecified, dictation }
    var requiresOnDeviceRecognition = false
    var shouldReportPartialResults = false
    var taskHint = Hint.unspecified
    var contextualStrings: [String] = []
    var endCount = 0
    func append(_ buffer: Int) {}
    func endAudio() { endCount += 1 }
}
struct SpeechResult: Sendable {
    struct Transcription: Sendable { let formattedString: String }
    let bestTranscription: Transcription
    let isFinal: Bool
    init(_ text: String, final: Bool) { bestTranscription = Transcription(formattedString: text); isFinal = final }
}
@MainActor final class SFSpeechRecognitionTask {
    let handler: @Sendable (SpeechResult?, (any Error)?) -> Void
    private(set) var cancelled = false
    init(handler: @escaping @Sendable (SpeechResult?, (any Error)?) -> Void) { self.handler = handler }
    func cancel() { cancelled = true }
    func emit(_ text: String, final: Bool) async {
        let handler = handler
        await Task.detached { handler(SpeechResult(text, final: final), nil) }.value
    }
}
@MainActor final class SFSpeechRecognizer {
    enum Authorization: Sendable { case authorized, denied }
    static var authorization = Authorization.authorized
    static var lastTask: SFSpeechRecognitionTask?
    static var lastRequest: SFSpeechAudioBufferRecognitionRequest?
    var isAvailable = true
    var supportsOnDeviceRecognition = true
    init?(locale: Locale) {}
    static func requestAuthorization(_ callback: @escaping @Sendable (Authorization) -> Void) {
        let status = authorization
        Task.detached { callback(status) }
    }
    func recognitionTask(with request: SFSpeechAudioBufferRecognitionRequest,
                         resultHandler: @escaping @Sendable (SpeechResult?, (any Error)?) -> Void) -> SFSpeechRecognitionTask {
        let task = SFSpeechRecognitionTask(handler: resultHandler)
        Self.lastTask = task
        Self.lastRequest = request
        return task
    }
}
