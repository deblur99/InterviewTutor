import Foundation

struct PostureMetrics: Sendable, Equatable {
    var faceDetectedRatio: Double
    var gazeTowardCameraRatio: Double
    var postureStabilityScore: Double

    static let empty = PostureMetrics(
        faceDetectedRatio: 0,
        gazeTowardCameraRatio: 0,
        postureStabilityScore: 0
    )
}
