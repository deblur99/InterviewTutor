import Foundation
import SwiftData

@Model
final class CandidateProfile {
    var profileID: UUID?
    var company: String
    var industry: String
    var role: String
    var jobDescription: String
    var resumeText: String
    var coverLetterText: String
    var createdAt: Date
    var updatedAt: Date
    var questionPoolFingerprint: String?

    @Relationship(deleteRule: .cascade, inverse: \InterviewSession.profile)
    var sessions: [InterviewSession]

    @Relationship(deleteRule: .cascade, inverse: \CachedQuestion.profile)
    var cachedQuestions: [CachedQuestion]

    init(
        profileID: UUID? = nil,
        company: String = "",
        industry: String = "",
        role: String = "",
        jobDescription: String = "",
        resumeText: String = "",
        coverLetterText: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        questionPoolFingerprint: String? = nil,
        sessions: [InterviewSession] = [],
        cachedQuestions: [CachedQuestion] = []
    ) {
        self.profileID = profileID
        self.company = company
        self.industry = industry
        self.role = role
        self.jobDescription = jobDescription
        self.resumeText = resumeText
        self.coverLetterText = coverLetterText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.questionPoolFingerprint = questionPoolFingerprint
        self.sessions = sessions
        self.cachedQuestions = cachedQuestions
    }

    var isComplete: Bool {
        !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !industry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !resumeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !coverLetterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func ensureProfileID() {
        if profileID == nil {
            profileID = UUID()
        }
    }

    var displayTitle: String {
        let companyName = company.trimmingCharacters(in: .whitespacesAndNewlines)
        let roleName = role.trimmingCharacters(in: .whitespacesAndNewlines)
        if !companyName.isEmpty, !roleName.isEmpty {
            return "\(companyName) · \(roleName)"
        }
        if !companyName.isEmpty {
            return companyName
        }
        if !roleName.isEmpty {
            return roleName
        }
        return "새 프로필"
    }

    var displaySubtitle: String {
        let industryName = industry.trimmingCharacters(in: .whitespacesAndNewlines)
        if industryName.isEmpty {
            return isComplete ? "프로필 완료" : "입력 미완료"
        }
        return industryName
    }
}
