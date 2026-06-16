import AVFoundation
import Foundation

enum AudioSampleConverter {
    static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard CMSampleBufferGetNumSamples(sampleBuffer) > 0 else { return nil }
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription),
              let format = AVAudioFormat(streamDescription: streamDescription) else {
            return nil
        }

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        pcmBuffer.frameLength = frameCount

        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?

        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else { return nil }

        let audioBuffer = audioBufferList.mBuffers
        guard let destination = pcmBuffer.mutableAudioBufferList.pointee.mBuffers.mData,
              let source = audioBuffer.mData else {
            return nil
        }

        memcpy(destination, source, Int(audioBuffer.mDataByteSize))
        return pcmBuffer
    }
}

enum AudioLevelMonitor {
    static let defaultRMSThreshold: Float = 0.015

    static func rms(from sampleBuffer: CMSampleBuffer) -> Float {
        guard let pcmBuffer = AudioSampleConverter.pcmBuffer(from: sampleBuffer) else { return 0 }

        if let channelData = pcmBuffer.floatChannelData {
            let frames = Int(pcmBuffer.frameLength)
            guard frames > 0 else { return 0 }
            let samples = UnsafeBufferPointer(start: channelData[0], count: frames)
            var sum: Float = 0
            for sample in samples {
                sum += sample * sample
            }
            return sqrt(sum / Float(frames))
        }

        if let channelData = pcmBuffer.int16ChannelData {
            let frames = Int(pcmBuffer.frameLength)
            guard frames > 0 else { return 0 }
            let samples = UnsafeBufferPointer(start: channelData[0], count: frames)
            var sum: Float = 0
            for sample in samples {
                let normalized = Float(sample) / Float(Int16.max)
                sum += normalized * normalized
            }
            return sqrt(sum / Float(frames))
        }

        return 0
    }
}
