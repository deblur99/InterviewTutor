import Foundation
import SwiftData

@Model
final class InterviewSession {
    var stageRawValue: String
    var date: Date
    var videoFilePath: String
    var expectedQuestionCount: Int
    var expectedDurationSeconds: Int

    var profile: CandidateProfile?

    @Relationship(deleteRule: .cascade, inverse: \QuestionRecord.session)
    var questions: [QuestionRecord]

    var stage: SessionStage {
        get { SessionStage(rawValue: stageRawValue) ?? .beginner }
        set { stageRawValue = newValue.rawValue }
    }

    init(
        stage: SessionStage = .beginner,
        date: Date = .now,
        videoFilePath: String = "",
        expectedQuestionCount: Int = 0,
        expectedDurationSeconds: Int = 0,
        profile: CandidateProfile? = nil,
        questions: [QuestionRecord] = []
    ) {
        self.stageRawValue = stage.rawValue
        self.date = date
        self.videoFilePath = videoFilePath
        self.expectedQuestionCount = expectedQuestionCount
        self.expectedDurationSeconds = expectedDurationSeconds
        self.profile = profile
        self.questions = questions
    }

    var sortedQuestions: [QuestionRecord] {
        questions.sorted { $0.orderIndex < $1.orderIndex }
    }
}
