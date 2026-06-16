import CoreGraphics
import Foundation
import Vision

enum UpperBodyPostureEstimator {
    static func postureStability(in pixelBuffer: CVPixelBuffer) -> Double? {
        if let bodyScore = bodyPoseStability(in: pixelBuffer) {
            return bodyScore
        }
        return faceOnlyStability(in: pixelBuffer)
    }

    private static func bodyPoseStability(in pixelBuffer: CVPixelBuffer) -> Double? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first else { return nil }

        guard let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              leftShoulder.confidence > 0.3,
              rightShoulder.confidence > 0.3 else {
            return nil
        }

        let shoulderTilt = abs(Double(leftShoulder.location.y - rightShoulder.location.y))
        let shoulderScore = max(0, 1 - shoulderTilt * 4)

        var neckScore = 0.5
        if let neck = try? observation.recognizedPoint(.neck),
           neck.confidence > 0.3 {
            let shoulderMidX = (leftShoulder.location.x + rightShoulder.location.x) / 2
            let lateralOffset = abs(Double(neck.location.x - shoulderMidX))
            neckScore = max(0, 1 - lateralOffset * 3)
        }

        return min(1, max(0, shoulderScore * 0.6 + neckScore * 0.4))
    }

    private static func faceOnlyStability(in pixelBuffer: CVPixelBuffer) -> Double? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let face = request.results?.first else { return nil }

        let box = face.boundingBox
        let centerOffset = abs(box.midX - 0.5)
        let sizeScore = min(1, box.width * 2)
        let centerScore = max(0, 1 - centerOffset * 2)
        let roll = abs(face.roll?.doubleValue ?? 0)
        let rollScore = max(0, 1 - roll * 2)

        return min(1, max(0, sizeScore * 0.35 + centerScore * 0.35 + rollScore * 0.3))
    }
}
