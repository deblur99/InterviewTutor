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
    var category: QuestionCategory

    init(
        id: UUID = UUID(),
        questionText: String,
        promptKeywords: String,
        recommendedSeconds: Int,
        category: QuestionCategory = .documentBased
    ) {
        self.id = id
        self.questionText = questionText
        self.promptKeywords = promptKeywords
        self.recommendedSeconds = recommendedSeconds
        self.category = category
    }
}
