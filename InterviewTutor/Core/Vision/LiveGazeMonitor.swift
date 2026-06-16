import CoreMedia
import CoreVideo
import Foundation

struct LiveGazeSnapshot: Sendable, Equatable {
    var isGazing: Bool?
    var sampledAt: Date
}

enum LiveGazeMonitor {
    static let defaultSampleInterval: TimeInterval = 0.35

    static func sampleIfNeeded(
        pixelBuffer: CVPixelBuffer,
        lastSampleTime: Date?,
        sampleInterval: TimeInterval = defaultSampleInterval,
        now: Date = .now
    ) -> (snapshot: LiveGazeSnapshot?, nextSampleTime: Date) {
        if let lastSampleTime, now.timeIntervalSince(lastSampleTime) < sampleInterval {
            return (nil, lastSampleTime)
        }

        let isGazing = FaceGazeEstimator.isGazingTowardCamera(in: pixelBuffer)
        return (LiveGazeSnapshot(isGazing: isGazing, sampledAt: now), now)
    }

    static func pixelBuffer(from sampleBuffer: CMSampleBuffer) -> CVPixelBuffer? {
        CMSampleBufferGetImageBuffer(sampleBuffer)
    }
}
