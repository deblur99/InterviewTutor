import CoreGraphics
import Foundation
import Vision

enum FaceGazeEstimator {
    static func isGazingTowardCamera(in pixelBuffer: CVPixelBuffer) -> Bool? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let face = request.results?.first,
              let landmarks = face.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye,
              let nose = landmarks.nose else {
            return nil
        }

        let leftCenter = centroid(of: leftEye, in: face.boundingBox)
        let rightCenter = centroid(of: rightEye, in: face.boundingBox)
        let noseCenter = centroid(of: nose, in: face.boundingBox)

        let eyeMidX = (leftCenter.x + rightCenter.x) / 2
        let eyeMidY = (leftCenter.y + rightCenter.y) / 2
        let eyeSpan = abs(rightCenter.x - leftCenter.x)
        guard eyeSpan > 0.02 else { return nil }

        let horizontalOffset = abs(noseCenter.x - eyeMidX) / eyeSpan
        let verticalOffset = abs(noseCenter.y - eyeMidY) / eyeSpan
        let eyeTilt = abs(rightCenter.y - leftCenter.y) / eyeSpan

        return horizontalOffset < 0.35 && verticalOffset < 0.55 && eyeTilt < 0.35
    }

    private static func centroid(of region: VNFaceLandmarkRegion2D, in boundingBox: CGRect) -> CGPoint {
        let points = region.normalizedPoints
        guard !points.isEmpty else {
            return CGPoint(x: boundingBox.midX, y: boundingBox.midY)
        }

        let sum = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + CGFloat(point.x), y: partial.y + CGFloat(point.y))
        }
        let average = CGPoint(
            x: sum.x / CGFloat(points.count),
            y: sum.y / CGFloat(points.count)
        )

        return CGPoint(
            x: boundingBox.origin.x + average.x * boundingBox.width,
            y: boundingBox.origin.y + average.y * boundingBox.height
        )
    }
}
