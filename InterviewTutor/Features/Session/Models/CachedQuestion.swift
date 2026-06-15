import Foundation
import SwiftData

@Model
final class CachedQuestion {
    var questionID: UUID
    var questionText: String
    var promptKeywords: String
    var recommendedSeconds: Int
    var profileFingerprint: String
    var statusRawValue: String
    var createdAt: Date

    var profile: CandidateProfile?

    var status: CachedQuestionStatus {
        get { CachedQuestionStatus(rawValue: statusRawValue) ?? .unused }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        questionID: UUID = UUID(),
        questionText: String,
        promptKeywords: String,
        recommendedSeconds: Int,
        profileFingerprint: String,
        status: CachedQuestionStatus = .unused,
        createdAt: Date = .now,
        profile: CandidateProfile? = nil
    ) {
        self.questionID = questionID
        self.questionText = questionText
        self.promptKeywords = promptKeywords
        self.recommendedSeconds = recommendedSeconds
        self.profileFingerprint = profileFingerprint
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.profile = profile
    }

    func toGeneratedQuestion() -> GeneratedQuestion {
        GeneratedQuestion(
            id: questionID,
            questionText: questionText,
            promptKeywords: promptKeywords,
            recommendedSeconds: recommendedSeconds
        )
    }

    static func from(_ question: GeneratedQuestion, fingerprint: String, profile: CandidateProfile) -> CachedQuestion {
        CachedQuestion(
            questionID: question.id,
            questionText: question.questionText,
            promptKeywords: question.promptKeywords,
            recommendedSeconds: question.recommendedSeconds,
            profileFingerprint: fingerprint,
            profile: profile
        )
    }
}
