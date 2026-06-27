import Foundation
import Speech
import AVFoundation

/// Lightweight on-device speech-to-text used by the assistant composer.
/// Publishes a live `transcript` while recording.
@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording = false
    @Published var levels: [Float] = Array(repeating: 0, count: 24)

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func start() {
        guard !isRecording else { return }
        guard let recognizer, recognizer.isAvailable else { return }
        transcript = ""
        isRecording = true

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let result else { return }
            Task { @MainActor [weak self] in
                self?.transcript = result.bestTranscription.formattedString
            }
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            let channel = buffer.floatChannelData?[0]
            let n = Int(buffer.frameLength)
            let rms: Float = channel.map { ptr in
                var sum: Float = 0
                for i in 0..<n { sum += ptr[i] * ptr[i] }
                return sqrt(sum / Float(max(n, 1)))
            } ?? 0
            let normalized = min(1.0, rms * 10)
            Task { @MainActor [weak self] in
                guard let self else { return }
                var l = self.levels
                l.removeFirst()
                l.append(normalized)
                self.levels = l
            }
        }

        engine.prepare()
        try? engine.start()
    }

    /// Stops capture and returns the final transcript.
    @discardableResult
    func stop() -> String {
        guard isRecording else { return transcript }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        levels = Array(repeating: 0, count: 24)
        return transcript
    }
}
