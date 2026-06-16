import AVFoundation
import Foundation
import Speech

final class StreamingSpeechRecognizer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.interviewtutor.speech.streaming")
    private nonisolated(unsafe) var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private nonisolated(unsafe) var recognitionTask: SFSpeechRecognitionTask?
    private nonisolated(unsafe) var recognizer: SFSpeechRecognizer?
    private nonisolated(unsafe) var latestTranscript = ""
    private nonisolated(unsafe) var onPartialHandler: (@Sendable (String) -> Void)?

    func start(
        locale: Locale = Locale(identifier: "ko-KR"),
        onPartial: @escaping @Sendable (String) -> Void
    ) async throws {
        try await QueueConfined.run(on: queue) {
            try self.startOnQueue(locale: locale, onPartial: onPartial)
        }
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        queue.async {
            guard let pcmBuffer = AudioSampleConverter.pcmBuffer(from: sampleBuffer),
                  let request = self.recognitionRequest else { return }
            request.append(pcmBuffer)
        }
    }

    func stop() async -> String {
        await QueueConfined.run(on: queue) {
            self.recognitionRequest?.endAudio()
            self.recognitionTask?.finish()
            self.recognitionRequest = nil
            self.recognitionTask = nil
            self.recognizer = nil
            let transcript = self.latestTranscript
            self.latestTranscript = ""
            self.onPartialHandler = nil
            return transcript
        }
    }

    private func startOnQueue(
        locale: Locale,
        onPartial: @escaping @Sendable (String) -> Void
    ) throws {
        guard let speechRecognizer = SFSpeechRecognizer(locale: locale),
              speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        recognizer = speechRecognizer
        recognitionRequest = request
        onPartialHandler = onPartial
        latestTranscript = ""

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                self.latestTranscript = text
                self.onPartialHandler?(text)
            }
            if error != nil {
                self.recognitionTask?.cancel()
            }
        }
    }
}
