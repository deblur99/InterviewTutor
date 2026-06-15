import Foundation
import SwiftData

struct SessionQuestionSet: Sendable {
    let questions: [GeneratedQuestion]
    let reservedDocumentQuestionIDs: [UUID]
}

@MainActor
final class QuestionPoolManager {
    static let targetPoolSize = 8
    static let sessionDocumentQuestionCount = 5

    private let questionGenerator = QuestionGenerator()

    func invalidatePoolIfNeeded(profile: CandidateProfile, context: ModelContext) {
        let fingerprint = ProfileFingerprint.make(for: profile)
        guard profile.questionPoolFingerprint != fingerprint else { return }

        for cached in profile.cachedQuestions {
            context.delete(cached)
        }
        profile.cachedQuestions.removeAll()
        profile.questionPoolFingerprint = fingerprint
        try? context.save()
    }

    func ensurePoolFilled(profile: CandidateProfile, context: ModelContext) async {
        guard profile.isComplete else { return }

        invalidatePoolIfNeeded(profile: profile, context: context)

        let fingerprint = ProfileFingerprint.make(for: profile)
        let unusedCount = unusedQuestions(for: profile, fingerprint: fingerprint).count
        let deficit = max(0, Self.targetPoolSize - unusedCount)
        guard deficit > 0 else { return }

        let generated = await questionGenerator.generateDocumentQuestions(for: profile, count: deficit)
        for question in generated {
            let cached = CachedQuestion.from(question, fingerprint: fingerprint, profile: profile)
            context.insert(cached)
            profile.cachedQuestions.append(cached)
        }
        try? context.save()
    }

    func prepareSessionQuestions(
        profile: CandidateProfile,
        context: ModelContext
    ) async -> SessionQuestionSet {
        invalidatePoolIfNeeded(profile: profile, context: context)

        let fingerprint = ProfileFingerprint.make(for: profile)
        var available = unusedQuestions(for: profile, fingerprint: fingerprint)

        let needed = Self.sessionDocumentQuestionCount
        if available.count < needed {
            let deficit = needed - available.count
            let generated = await questionGenerator.generateDocumentQuestions(for: profile, count: deficit)
            for question in generated {
                let cached = CachedQuestion.from(question, fingerprint: fingerprint, profile: profile)
                cached.status = .unused
                context.insert(cached)
                profile.cachedQuestions.append(cached)
                available.append(cached)
            }
            try? context.save()
        }

        let selected = Array(available.prefix(needed))
        for cached in selected {
            cached.status = .reserved
        }
        try? context.save()

        let documentQuestions = selected.map { $0.toGeneratedQuestion() }
        let reservedIDs = selected.map(\.questionID)
        let fullSet = questionGenerator.buildFullQuestionSet(documentQuestions: documentQuestions)

        return SessionQuestionSet(questions: fullSet, reservedDocumentQuestionIDs: reservedIDs)
    }

    func markAnswered(questionIDs: [UUID], profile: CandidateProfile, context: ModelContext) {
        let idSet = Set(questionIDs)
        for cached in profile.cachedQuestions where idSet.contains(cached.questionID) {
            cached.status = .answered
        }
        try? context.save()
    }

    func releaseReserved(questionIDs: [UUID], profile: CandidateProfile, context: ModelContext) {
        let idSet = Set(questionIDs)
        for cached in profile.cachedQuestions where idSet.contains(cached.questionID) {
            if cached.status == .reserved {
                cached.status = .unused
            }
        }
        try? context.save()
    }

    func unusedCount(for profile: CandidateProfile) -> Int {
        let fingerprint = ProfileFingerprint.make(for: profile)
        return unusedQuestions(for: profile, fingerprint: fingerprint).count
    }

    private func unusedQuestions(
        for profile: CandidateProfile,
        fingerprint: String
    ) -> [CachedQuestion] {
        profile.cachedQuestions
            .filter { $0.profileFingerprint == fingerprint && $0.status == .unused }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
