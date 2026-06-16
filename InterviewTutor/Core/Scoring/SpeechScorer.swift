import Foundation

enum SpeechScorer {
    private static let idealWPMRange = 120.0...180.0
    private static let maxFillersPerMinute = 8.0

    static func score(
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        recommendedSeconds: Int
    ) -> Int {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              duration > 0 else {
            return 0
        }

        let fillerScore = fillerComponent(count: fillerCount, duration: duration)
        let wpmScore = wpmComponent(transcript: transcript, duration: duration)
        let timingScore = timingComponent(duration: duration, recommended: TimeInterval(recommendedSeconds))

        let weighted = fillerScore * 0.4 + wpmScore * 0.35 + timingScore * 0.25
        return clampScore(weighted)
    }

    private static func fillerComponent(count: Int, duration: TimeInterval) -> Double {
        let minutes = max(duration / 60, 1 / 60)
        let perMinute = Double(count) / minutes
        let penalty = min(perMinute / maxFillersPerMinute, 1)
        return (1 - penalty) * 100
    }

    private static func wpmComponent(transcript: String, duration: TimeInterval) -> Double {
        let words = max(wordCount(in: transcript), 1)
        let minutes = max(duration / 60, 1 / 60)
        let wpm = Double(words) / minutes

        if idealWPMRange.contains(wpm) {
            return 100
        }

        let distance: Double
        if wpm < idealWPMRange.lowerBound {
            distance = idealWPMRange.lowerBound - wpm
        } else {
            distance = wpm - idealWPMRange.upperBound
        }

        return max(0, 100 - distance * 1.5)
    }

    private static func timingComponent(duration: TimeInterval, recommended: TimeInterval) -> Double {
        guard recommended > 0 else { return 70 }
        let delta = abs(duration - recommended)
        if delta <= 10 { return 100 }
        if delta <= 20 { return 80 }
        if delta <= 30 { return 60 }
        return max(20, 100 - delta)
    }

    private static func wordCount(in text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private static func clampScore(_ value: Double) -> Int {
        Int(min(100, max(0, value.rounded())))
    }
}
