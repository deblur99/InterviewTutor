import AVFoundation
import Foundation
import Speech

enum SpeechRecognitionError: Error, LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "음성 인식 권한이 필요합니다."
        case .recognizerUnavailable: "음성 인식기를 사용할 수 없습니다."
        case .recognitionFailed: "음성 인식에 실패했습니다."
        }
    }
}

nonisolated final class SpeechRecognizer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.interviewtutor.speech.recognition")

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribe(audioURL: URL, locale: Locale = Locale(identifier: "ko-KR")) async throws -> String {
        try await QueueConfined.run(on: queue) {
            try self.transcribeOnQueue(audioURL: audioURL, locale: locale)
        }
    }

    func transcribeSegment(
        from videoURL: URL,
        startTime: TimeInterval,
        endTime: TimeInterval,
        locale: Locale = Locale(identifier: "ko-KR")
    ) async throws -> String {
        let tempAudioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        try await exportAudioSegment(
            from: videoURL,
            startTime: startTime,
            endTime: endTime,
            outputURL: tempAudioURL
        )

        defer { try? FileManager.default.removeItem(at: tempAudioURL) }
        return try await transcribe(audioURL: tempAudioURL, locale: locale)
    }

    private func transcribeOnQueue(audioURL: URL, locale: Locale) throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }

        do {
            return try transcribeOnQueue(
                audioURL: audioURL,
                recognizer: recognizer,
                requiresOnDevice: recognizer.supportsOnDeviceRecognition
            )
        } catch {
            guard recognizer.supportsOnDeviceRecognition else { throw error }
            return try transcribeOnQueue(
                audioURL: audioURL,
                recognizer: recognizer,
                requiresOnDevice: false
            )
        }
    }

    private func transcribeOnQueue(
        audioURL: URL,
        recognizer: SFSpeechRecognizer,
        requiresOnDevice: Bool
    ) throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = requiresOnDevice
        request.shouldReportPartialResults = false

        let semaphore = DispatchSemaphore(value: 0)
        var resultText = ""
        var resultError: Error?

        let task = recognizer.recognitionTask(with: request) { result, error in
            if let result, result.isFinal {
                resultText = result.bestTranscription.formattedString
                semaphore.signal()
            } else if let error {
                resultError = error
                semaphore.signal()
            }
        }

        semaphore.wait()
        task.cancel()

        if let resultError { throw resultError }
        if resultText.isEmpty { throw SpeechRecognitionError.recognitionFailed }
        return resultText
    }

    private func exportAudioSegment(
        from videoURL: URL,
        startTime: TimeInterval,
        endTime: TimeInterval,
        outputURL: URL
    ) async throws {
        let asset = AVURLAsset(url: videoURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw SpeechRecognitionError.recognitionFailed
        }

        let duration = try await asset.load(.duration)
        let durationSeconds = max(0, CMTimeGetSeconds(duration))
        guard durationSeconds > 0 else {
            throw SpeechRecognitionError.recognitionFailed
        }

        let safeStart = min(max(0, startTime), max(0, durationSeconds - 0.1))
        let safeEnd = min(max(safeStart + 0.1, endTime), durationSeconds)
        guard safeEnd > safeStart else {
            throw SpeechRecognitionError.recognitionFailed
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw SpeechRecognitionError.recognitionFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: safeStart, preferredTimescale: 600),
            end: CMTime(seconds: safeEnd, preferredTimescale: 600)
        )

        try await exportSession.export(to: outputURL, as: .m4a)
    }
}
