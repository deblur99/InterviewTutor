import Foundation

struct RecordingSegment: Sendable, Identifiable {
    let questionID: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval

    var id: UUID { questionID }
    var duration: TimeInterval { endTime - startTime }
}

struct TranscriptChunk: Sendable {
    let questionID: UUID
    let text: String
    let isFinal: Bool
}

struct SessionSnapshot: Sendable {
    let isRecording: Bool
    let elapsedSeconds: TimeInterval
    let currentSegmentIndex: Int
}

struct FillerWordReport: Sendable {
    let totalCount: Int
    let breakdown: [String: Int]
}

struct GeneratedQuestion: Sendable, Identifiable {
    let id: UUID
    let questionText: String
    let promptKeywords: String
    let recommendedSeconds: Int
}
