import Foundation
import SwiftData

struct SessionQuestionSet: Sendable {
    let questions: [GeneratedQuestion]
    let reservedDocumentQuestionIDs: [UUID]
}

@MainActor
final class QuestionPoolManager {
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

    func ensurePoolFilled(
        profile: CandidateProfile,
        stage: SessionStage = .beginner,
        context: ModelContext
    ) async {
        guard profile.isComplete else { return }

        invalidatePoolIfNeeded(profile: profile, context: context)
        purgeInvalidCachedQuestions(profile: profile, context: context)

        let preset = stage.preset
        let fingerprint = ProfileFingerprint.make(for: profile)
        let unusedCount = unusedQuestions(for: profile, stage: stage, fingerprint: fingerprint).count
        let deficit = max(0, preset.poolTargetSize - unusedCount)
        guard deficit > 0 else { return }

        let generated = await generatePoolQuestions(
            for: profile,
            stage: stage,
            count: deficit
        )

        for question in generated {
            let cached = CachedQuestion.from(question, fingerprint: fingerprint, stage: stage, profile: profile)
            context.insert(cached)
            profile.cachedQuestions.append(cached)
        }
        try? context.save()
    }

    func prepareSessionQuestions(
        profile: CandidateProfile,
        stage: SessionStage = .beginner,
        expertConfiguration: ExpertSessionConfiguration? = nil,
        context: ModelContext
    ) async -> SessionQuestionSet {
        invalidatePoolIfNeeded(profile: profile, context: context)
        purgeInvalidCachedQuestions(profile: profile, context: context)

        let fingerprint = ProfileFingerprint.make(for: profile)

        switch stage {
        case .beginner:
            let preset = stage.preset
            return await prepareBeginnerSession(profile: profile, preset: preset, fingerprint: fingerprint, context: context)
        case .skilled:
            let preset = stage.preset
            return await prepareSkilledSession(profile: profile, preset: preset, stage: stage, fingerprint: fingerprint, context: context)
        case .expert:
            let config = (expertConfiguration ?? profile.expertSessionConfiguration)
                .biased(for: WeakTopicAnalyzer.weakCategories(from: profile))
            return await prepareExpertSession(
                profile: profile,
                configuration: config,
                fingerprint: fingerprint,
                context: context
            )
        case .freePractice:
            return SessionQuestionSet(questions: [], reservedDocumentQuestionIDs: [])
        }
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

    func unusedCount(for profile: CandidateProfile, stage: SessionStage = .beginner) -> Int {
        let fingerprint = ProfileFingerprint.make(for: profile)
        return unusedQuestions(for: profile, stage: stage, fingerprint: fingerprint).count
    }

    // MARK: - Beginner

    private func prepareBeginnerSession(
        profile: CandidateProfile,
        preset: SessionStagePreset,
        fingerprint: String,
        context: ModelContext
    ) async -> SessionQuestionSet {
        var available = unusedQuestions(for: profile, stage: .beginner, fingerprint: fingerprint, category: .documentBased)

        let needed = preset.documentQuestionCount
        if available.count < needed {
            let deficit = needed - available.count
            let generated = await questionGenerator.generateDocumentQuestions(for: profile, count: deficit)
            for question in generated {
                let cached = CachedQuestion.from(question, fingerprint: fingerprint, stage: .beginner, profile: profile)
                cached.status = .unused
                context.insert(cached)
                profile.cachedQuestions.append(cached)
                available.append(cached)
            }
            try? context.save()
        }

        let selected = Array(available.prefix(needed))
        reserve(selected, context: context)

        let documentQuestions = selected.map { $0.toGeneratedQuestion() }
        let fullSet = questionGenerator.buildBeginnerQuestionSet(documentQuestions: documentQuestions)
        return SessionQuestionSet(questions: fullSet, reservedDocumentQuestionIDs: selected.map(\.questionID))
    }

    // MARK: - Skilled

    private func prepareSkilledSession(
        profile: CandidateProfile,
        preset: SessionStagePreset,
        stage: SessionStage,
        fingerprint: String,
        context: ModelContext
    ) async -> SessionQuestionSet {
        let document = await selectOrGenerate(
            category: .documentBased,
            count: preset.documentQuestionCount,
            profile: profile,
            stage: stage,
            fingerprint: fingerprint,
            context: context
        ) { count in
            await questionGenerator.generateDocumentQuestions(for: profile, count: count)
        }

        let behavioral = await selectOrGenerate(
            category: .behavioral,
            count: preset.behavioralQuestionCount,
            profile: profile,
            stage: stage,
            fingerprint: fingerprint,
            context: context
        ) { count in
            await questionGenerator.generateBehavioralQuestions(for: profile, count: count)
        }

        let company = await selectOrGenerate(
            category: .companyFit,
            count: preset.companyQuestionCount,
            profile: profile,
            stage: stage,
            fingerprint: fingerprint,
            context: context
        ) { count in
            await questionGenerator.generateCompanyQuestions(for: profile, count: count)
        }

        let reservedIDs = document.map(\.questionID)
        let fullSet = questionGenerator.buildSkilledQuestionSet(
            documentQuestions: document.map { $0.toGeneratedQuestion() },
            behavioralQuestions: behavioral.map { $0.toGeneratedQuestion() },
            companyQuestions: company.map { $0.toGeneratedQuestion() }
        )

        return SessionQuestionSet(questions: fullSet, reservedDocumentQuestionIDs: reservedIDs)
    }

    // MARK: - Expert

    private func prepareExpertSession(
        profile: CandidateProfile,
        configuration: ExpertSessionConfiguration,
        fingerprint: String,
        context: ModelContext
    ) async -> SessionQuestionSet {
        let stage = SessionStage.expert

        let document = await selectOrGenerate(
            category: .documentBased,
            count: configuration.documentQuestionCount,
            profile: profile,
            stage: stage,
            fingerprint: fingerprint,
            context: context
        ) { count in
            await questionGenerator.generateDocumentQuestions(for: profile, count: count)
        }

        let technical = await selectOrGenerate(
            category: .technical,
            count: configuration.technicalQuestionCount,
            profile: profile,
            stage: stage,
            fingerprint: fingerprint,
            context: context
        ) { count in
            await questionGenerator.generateTechnicalQuestions(for: profile, count: count)
        }

        let behavioral = await selectOrGenerate(
            category: .behavioral,
            count: configuration.behavioralQuestionCount,
            profile: profile,
            stage: stage,
            fingerprint: fingerprint,
            context: context
        ) { count in
            await questionGenerator.generateBehavioralQuestions(for: profile, count: count)
        }

        let company = await selectOrGenerate(
            category: .companyFit,
            count: configuration.companyQuestionCount,
            profile: profile,
            stage: stage,
            fingerprint: fingerprint,
            context: context
        ) { count in
            await questionGenerator.generateCompanyQuestions(for: profile, count: count)
        }

        let pressure = await selectOrGenerate(
            category: .pressure,
            count: configuration.pressureQuestionCount,
            profile: profile,
            stage: stage,
            fingerprint: fingerprint,
            context: context
        ) { count in
            await questionGenerator.generatePressureQuestions(for: profile, count: count)
        }

        let comprehensive = await selectOrGenerate(
            category: .comprehensive,
            count: configuration.comprehensiveQuestionCount,
            profile: profile,
            stage: stage,
            fingerprint: fingerprint,
            context: context
        ) { count in
            await questionGenerator.generateComprehensiveQuestions(for: profile, count: count)
        }

        let reservedIDs = document.map(\.questionID)
        let fullSet = questionGenerator.buildExpertQuestionSet(
            documentQuestions: document.map { $0.toGeneratedQuestion() },
            technicalQuestions: technical.map { $0.toGeneratedQuestion() },
            behavioralQuestions: behavioral.map { $0.toGeneratedQuestion() },
            companyQuestions: company.map { $0.toGeneratedQuestion() },
            pressureQuestions: pressure.map { $0.toGeneratedQuestion() },
            comprehensiveQuestions: comprehensive.map { $0.toGeneratedQuestion() },
            configuration: configuration
        )

        return SessionQuestionSet(questions: fullSet, reservedDocumentQuestionIDs: reservedIDs)
    }

    private func selectOrGenerate(
        category: QuestionCategory,
        count: Int,
        profile: CandidateProfile,
        stage: SessionStage,
        fingerprint: String,
        context: ModelContext,
        generator: (Int) async -> [GeneratedQuestion]
    ) async -> [CachedQuestion] {
        var available = unusedQuestions(for: profile, stage: stage, fingerprint: fingerprint, category: category)

        if available.count < count {
            let deficit = count - available.count
            let generated = await generator(deficit)
            for question in generated {
                let cached = CachedQuestion.from(question, fingerprint: fingerprint, stage: stage, profile: profile)
                cached.status = .unused
                context.insert(cached)
                profile.cachedQuestions.append(cached)
                available.append(cached)
            }
            try? context.save()
        }

        let selected = Array(available.prefix(count))
        reserve(selected, context: context)
        return selected
    }

    private func generatePoolQuestions(
        for profile: CandidateProfile,
        stage: SessionStage,
        count: Int
    ) async -> [GeneratedQuestion] {
        switch stage {
        case .beginner:
            return await questionGenerator.generateDocumentQuestions(for: profile, count: count)
        case .skilled:
            let documentCount = max(1, count / 2)
            let behavioralCount = max(1, count / 3)
            let companyCount = max(0, count - documentCount - behavioralCount)

            var result: [GeneratedQuestion] = []
            result.append(contentsOf: await questionGenerator.generateDocumentQuestions(for: profile, count: documentCount))
            result.append(contentsOf: await questionGenerator.generateBehavioralQuestions(for: profile, count: behavioralCount))
            if companyCount > 0 {
                result.append(contentsOf: await questionGenerator.generateCompanyQuestions(for: profile, count: companyCount))
            }
            return result
        case .expert:
            let perCategory = max(1, count / QuestionCategory.poolCategories.count)
            var result: [GeneratedQuestion] = []
            result.append(contentsOf: await questionGenerator.generateDocumentQuestions(for: profile, count: perCategory))
            result.append(contentsOf: await questionGenerator.generateTechnicalQuestions(for: profile, count: perCategory))
            result.append(contentsOf: await questionGenerator.generateBehavioralQuestions(for: profile, count: perCategory))
            result.append(contentsOf: await questionGenerator.generateCompanyQuestions(for: profile, count: perCategory))
            result.append(contentsOf: await questionGenerator.generatePressureQuestions(for: profile, count: perCategory))
            result.append(contentsOf: await questionGenerator.generateComprehensiveQuestions(for: profile, count: max(1, count - perCategory * 5)))
            return Array(result.prefix(count))
        case .freePractice:
            return []
        }
    }

    private func reserve(_ questions: [CachedQuestion], context: ModelContext) {
        for cached in questions {
            cached.status = .reserved
        }
        try? context.save()
    }

    private func unusedQuestions(
        for profile: CandidateProfile,
        stage: SessionStage,
        fingerprint: String,
        category: QuestionCategory? = nil
    ) -> [CachedQuestion] {
        profile.cachedQuestions
            .filter {
                $0.profileFingerprint == fingerprint
                    && $0.stage == stage
                    && $0.status == .unused
                    && InterviewQuestionValidator.isValidQuestionText($0.questionText)
                    && (category == nil || $0.category == category)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func purgeInvalidCachedQuestions(profile: CandidateProfile, context: ModelContext) {
        let invalid = profile.cachedQuestions.filter {
            !InterviewQuestionValidator.isValidQuestionText($0.questionText)
        }
        guard !invalid.isEmpty else { return }

        for cached in invalid {
            context.delete(cached)
        }
        profile.cachedQuestions.removeAll { cached in
            invalid.contains { $0.questionID == cached.questionID }
        }
        try? context.save()
    }
}

// Backward-compatible defaults for beginner-only call sites
extension QuestionPoolManager {
    static let targetPoolSize = SessionStagePreset.preset(for: .beginner).poolTargetSize
    static let sessionDocumentQuestionCount = SessionStagePreset.preset(for: .beginner).documentQuestionCount
}
