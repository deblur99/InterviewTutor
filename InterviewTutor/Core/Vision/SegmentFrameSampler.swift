import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

enum SegmentFrameSampler {
    static let defaultSampleInterval: TimeInterval = 0.5
    static let maxFramesPerSegment = 30

    static func sampleFrames(
        from videoURL: URL,
        startTime: TimeInterval,
        endTime: TimeInterval,
        sampleInterval: TimeInterval = defaultSampleInterval,
        maxFrames: Int = maxFramesPerSegment
    ) throws -> [CVPixelBuffer] {
        guard endTime > startTime else { return [] }

        let asset = AVURLAsset(url: videoURL)
        guard let track = asset.tracks(withMediaType: .video).first else { return [] }

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return [] }
        reader.add(output)

        let startCM = CMTime(seconds: startTime, preferredTimescale: 600)
        let duration = CMTime(seconds: endTime - startTime, preferredTimescale: 600)
        reader.timeRange = CMTimeRange(start: startCM, duration: duration)

        guard reader.startReading() else { return [] }

        var buffers: [CVPixelBuffer] = []
        var lastSampleTime: TimeInterval?

        while let sampleBuffer = output.copyNextSampleBuffer() {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            if let lastSampleTime, presentationTime - lastSampleTime < sampleInterval {
                continue
            }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }

            lastSampleTime = presentationTime
            buffers.append(pixelBuffer)
            if buffers.count >= maxFrames { break }
        }

        reader.cancelReading()
        return buffers
    }
}
