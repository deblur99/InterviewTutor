import Foundation

enum PostureScorer {
    static func score(metrics: PostureMetrics) -> Int {
        let weighted = metrics.gazeTowardCameraRatio * 50
            + metrics.postureStabilityScore * 30
            + metrics.faceDetectedRatio * 20
        return Int(min(100, max(0, weighted.rounded())))
    }
}
