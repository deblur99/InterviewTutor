import Foundation
import SwiftData

@Model
final class InterviewSession {
    var stageRawValue: String
    var date: Date
    var videoFilePath: String
    var expectedQuestionCount: Int
    var expectedDurationSeconds: Int
    var speechScore: Int?
    var contentScore: Int?
    var postureScore: Int?
    var overallScore: Int?
    var overallGradeRawValue: String?
    var sessionIndex: Int?

    var profile: CandidateProfile?

    @Relationship(deleteRule: .cascade, inverse: \QuestionRecord.session)
    var questions: [QuestionRecord]

    var stage: SessionStage {
        get { SessionStage(rawValue: stageRawValue) ?? .beginner }
        set { stageRawValue = newValue.rawValue }
    }

    var overallGrade: LetterGrade? {
        get {
            guard let raw = overallGradeRawValue else { return nil }
            return LetterGrade(rawValue: raw)
        }
        set { overallGradeRawValue = newValue?.rawValue }
    }

    init(
        stage: SessionStage = .beginner,
        date: Date = .now,
        videoFilePath: String = "",
        expectedQuestionCount: Int = 0,
        expectedDurationSeconds: Int = 0,
        speechScore: Int? = nil,
        contentScore: Int? = nil,
        postureScore: Int? = nil,
        overallScore: Int? = nil,
        overallGrade: LetterGrade? = nil,
        sessionIndex: Int? = nil,
        profile: CandidateProfile? = nil,
        questions: [QuestionRecord] = []
    ) {
        self.stageRawValue = stage.rawValue
        self.date = date
        self.videoFilePath = videoFilePath
        self.expectedQuestionCount = expectedQuestionCount
        self.expectedDurationSeconds = expectedDurationSeconds
        self.speechScore = speechScore
        self.contentScore = contentScore
        self.postureScore = postureScore
        self.overallScore = overallScore
        self.overallGradeRawValue = overallGrade?.rawValue
        self.sessionIndex = sessionIndex
        self.profile = profile
        self.questions = questions
    }

    var sortedQuestions: [QuestionRecord] {
        questions.sorted { $0.orderIndex < $1.orderIndex }
    }
}
