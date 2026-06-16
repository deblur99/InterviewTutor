import CoreVideo
import Foundation

final class SegmentVisionAnalyzer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.interviewtutor.vision.analysis")

    func analyzeSegment(
        videoURL: URL,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) async -> PostureMetrics {
        await withCheckedContinuation { continuation in
            queue.async {
                let metrics = Self.analyzeOnQueue(
                    videoURL: videoURL,
                    startTime: startTime,
                    endTime: endTime
                )
                continuation.resume(returning: metrics)
            }
        }
    }

    private static func analyzeOnQueue(
        videoURL: URL,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) -> PostureMetrics {
        guard endTime - startTime > 0.5 else { return .empty }

        let frames: [CVPixelBuffer]
        do {
            frames = try SegmentFrameSampler.sampleFrames(
                from: videoURL,
                startTime: startTime,
                endTime: endTime
            )
        } catch {
            return .empty
        }

        guard !frames.isEmpty else { return .empty }

        var faceDetectedCount = 0
        var gazeCount = 0
        var postureScores: [Double] = []

        for frame in frames {
            if let gazing = FaceGazeEstimator.isGazingTowardCamera(in: frame) {
                faceDetectedCount += 1
                if gazing { gazeCount += 1 }
            }

            if let stability = UpperBodyPostureEstimator.postureStability(in: frame) {
                postureScores.append(stability)
            }
        }

        let totalFrames = frames.count
        let faceRatio = Double(faceDetectedCount) / Double(totalFrames)
        let gazeRatio = faceDetectedCount > 0
            ? Double(gazeCount) / Double(faceDetectedCount)
            : 0
        let postureStability = postureScores.isEmpty
            ? 0
            : postureScores.reduce(0, +) / Double(postureScores.count)

        return PostureMetrics(
            faceDetectedRatio: faceRatio,
            gazeTowardCameraRatio: gazeRatio,
            postureStabilityScore: postureStability
        )
    }
}
