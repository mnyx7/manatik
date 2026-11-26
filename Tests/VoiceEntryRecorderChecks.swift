import Foundation

@main struct RecorderChecks {
    @MainActor static func eventually(timeout: Duration = .seconds(2), _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        preconditionFailure("Recorder state did not settle")
    }

    @MainActor static func main() async throws {
        let recorder = VoiceEntryRecorder()
        await recorder.start(localeID: "en-US", contextualStrings: ["five thousand manat"])
        precondition(recorder.isRecording && !recorder.isPreparing)
        let first = SFSpeechRecognizer.lastTask!
        let request = SFSpeechRecognizer.lastRequest!
        precondition(request.requiresOnDeviceRecognition && request.taskHint == .dictation && request.contextualStrings == ["five thousand manat"])
        await first.emit("five manat", final: false)
        try await eventually { recorder.transcript == "five manat" }
        recorder.finish()
        recorder.finish()
        precondition(!recorder.isRecording && recorder.isFinalizing && !first.cancelled && request.endCount == 1)
        print("PASS Stop ends capture but preserves recognition for final result")
        await first.emit("five thousand manat", final: true)
        try await eventually { !recorder.isFinalizing }
        precondition(recorder.transcript == "five thousand manat" && first.cancelled)
        print("PASS late final transcript replaces partial transcript")

        await recorder.start(localeID: "en-US")
        let cancelled = SFSpeechRecognizer.lastTask!
        recorder.stop()
        await recorder.start(localeID: "en-US")
        let current = SFSpeechRecognizer.lastTask!
        await cancelled.emit("stale result", final: true)
        await current.emit("ten USD", final: false)
        try await eventually { recorder.transcript == "ten USD" }
        precondition(recorder.isRecording && !current.cancelled)
        print("PASS cancelled callbacks cannot overwrite the next recording")
        recorder.finish()
        precondition(recorder.isFinalizing)
        recorder.stop()
        await current.emit("late cancelled final", final: true)
        try await Task.sleep(for: .milliseconds(10))
        precondition(!recorder.isRecording && !recorder.isFinalizing && recorder.transcript == "ten USD")
        print("PASS leaving the screen cancels finalization and ignores later results")

        await recorder.start(localeID: "en-US")
        let timedOut = SFSpeechRecognizer.lastTask!
        await timedOut.emit("review this partial", final: false)
        try await eventually { recorder.transcript == "review this partial" }
        recorder.finish()
        try await eventually(timeout: .seconds(7)) { !recorder.isFinalizing }
        precondition(!recorder.isFinalizing && timedOut.cancelled && recorder.transcript == "review this partial" && recorder.errorMessage != nil)
        print("PASS missing final result times out with editable text and a warning")

        SFSpeechRecognizer.authorization = .denied
        await recorder.start(localeID: "en-US")
        precondition(!recorder.isRecording && !recorder.isPreparing && !recorder.isFinalizing && recorder.errorMessage != nil)
        print("PASS permission denial leaves the recorder usable")
    }
}
