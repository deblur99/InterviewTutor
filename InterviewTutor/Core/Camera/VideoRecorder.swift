import AVFoundation
import Foundation

nonisolated final class VideoRecorder: @unchecked Sendable {
    private let outputURL: URL
    private nonisolated(unsafe) var assetWriter: AVAssetWriter?
    private nonisolated(unsafe) var videoInput: AVAssetWriterInput?
    private nonisolated(unsafe) var audioInput: AVAssetWriterInput?
    private nonisolated(unsafe) var sessionStartTime: CMTime?
    private nonisolated(unsafe) var isRecording = false

    private nonisolated(unsafe) var openSegments: [UUID: TimeInterval] = [:]
    private nonisolated(unsafe) var completedSegments: [RecordingSegment] = []

    var currentTime: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        return CMTimeGetSeconds(CMTimeSubtract(CMClockGetTime(CMClockGetHostTimeClock()), start))
    }

    var segments: [RecordingSegment] { completedSegments }

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    func prepare(with session: AVCaptureSession) throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280,
            AVVideoHeightKey: 720,
        ]
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput.expectsMediaDataInRealTime = true

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44_100,
        ]
        let audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioWriterInput.expectsMediaDataInRealTime = true

        guard writer.canAdd(videoWriterInput) else { throw CameraError.writerFailed }
        writer.add(videoWriterInput)
        videoInput = videoWriterInput

        if writer.canAdd(audioWriterInput) {
            writer.add(audioWriterInput)
            audioInput = audioWriterInput
        }

        assetWriter = writer
    }

    func start(at time: CMTime) {
        guard let writer = assetWriter, writer.status == .unknown else { return }
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        sessionStartTime = time
        isRecording = true
    }

    func append(sampleBuffer: CMSampleBuffer, from output: AVCaptureOutput) {
        guard isRecording,
              let writer = assetWriter,
              writer.status == .writing,
              CMSampleBufferDataIsReady(sampleBuffer) else { return }

        if output is AVCaptureVideoDataOutput, let input = videoInput, input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        } else if output is AVCaptureAudioDataOutput, let input = audioInput, input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
    }

    func markSegmentStart(questionID: UUID) {
        openSegments[questionID] = currentTime
    }

    func markSegmentEnd(questionID: UUID) -> RecordingSegment? {
        guard let start = openSegments.removeValue(forKey: questionID) else { return nil }
        let segment = RecordingSegment(questionID: questionID, startTime: start, endTime: currentTime)
        completedSegments.append(segment)
        return segment
    }

    func stop() -> URL? {
        guard isRecording, let writer = assetWriter else { return nil }
        isRecording = false

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        return writer.status == .completed ? outputURL : nil
    }
}
