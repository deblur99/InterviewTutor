import Foundation
import SwiftData

@Model
final class CachedQuestion {
    var questionID: UUID
    var questionText: String
    var promptKeywords: String
    var recommendedSeconds: Int
    var profileFingerprint: String
    var stageRawValue: String?
    var categoryRawValue: String?
    var statusRawValue: String
    var createdAt: Date

    var profile: CandidateProfile?

    var status: CachedQuestionStatus {
        get { CachedQuestionStatus(rawValue: statusRawValue) ?? .unused }
        set { statusRawValue = newValue.rawValue }
    }

    var stage: SessionStage {
        get { SessionStage(rawValue: stageRawValue ?? "") ?? .beginner }
        set { stageRawValue = newValue.rawValue }
    }

    var category: QuestionCategory {
        get { QuestionCategory(rawValue: categoryRawValue ?? "") ?? .documentBased }
        set { categoryRawValue = newValue.rawValue }
    }

    init(
        questionID: UUID = UUID(),
        questionText: String,
        promptKeywords: String,
        recommendedSeconds: Int,
        profileFingerprint: String,
        stage: SessionStage = .beginner,
        category: QuestionCategory = .documentBased,
        status: CachedQuestionStatus = .unused,
        createdAt: Date = .now,
        profile: CandidateProfile? = nil
    ) {
        self.questionID = questionID
        self.questionText = questionText
        self.promptKeywords = promptKeywords
        self.recommendedSeconds = recommendedSeconds
        self.profileFingerprint = profileFingerprint
        self.stageRawValue = stage.rawValue
        self.categoryRawValue = category.rawValue
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.profile = profile
    }

    func toGeneratedQuestion() -> GeneratedQuestion {
        GeneratedQuestion(
            id: questionID,
            questionText: questionText,
            promptKeywords: promptKeywords,
            recommendedSeconds: recommendedSeconds,
            category: category
        )
    }

    static func from(
        _ question: GeneratedQuestion,
        fingerprint: String,
        stage: SessionStage,
        profile: CandidateProfile
    ) -> CachedQuestion {
        CachedQuestion(
            questionID: question.id,
            questionText: question.questionText,
            promptKeywords: question.promptKeywords,
            recommendedSeconds: question.recommendedSeconds,
            profileFingerprint: fingerprint,
            stage: stage,
            category: question.category,
            profile: profile
        )
    }
}
