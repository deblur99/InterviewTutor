import Foundation

@MainActor
final class FreePracticeQuestionBuilder {
    private let questionGenerator = QuestionGenerator()

    func buildQuestions(
        profile: CandidateProfile,
        configuration: FreePracticeConfiguration
    ) async -> [GeneratedQuestion] {
        let sequence = configuration.topicSequence()
        var results: [GeneratedQuestion] = []
        var poolByTopic: [PracticeTopic: [GeneratedQuestion]] = [:]

        for topic in Set(sequence) {
            guard !Task.isCancelled else { return results }
            let needed = sequence.filter { $0 == topic }.count
            poolByTopic[topic] = await generatePool(for: topic, profile: profile, count: needed)
        }

        var usageIndex: [PracticeTopic: Int] = [:]
        for topic in sequence {
            guard !Task.isCancelled else { return results }
            let index = usageIndex[topic, default: 0]
            if let pool = poolByTopic[topic], index < pool.count {
                results.append(pool[index])
                usageIndex[topic] = index + 1
            }
        }

        let custom = profile.customInterviewQuestions
            .filter { $0.applies(to: .freePractice) && $0.isValid }
            .map { $0.toGeneratedQuestion() }

        return results + custom
    }

    private func generatePool(
        for topic: PracticeTopic,
        profile: CandidateProfile,
        count: Int
    ) async -> [GeneratedQuestion] {
        guard count > 0 else { return [] }

        switch topic {
        case .documentBased:
            return await questionGenerator.generateDocumentQuestions(for: profile, count: count)
        case .behavioral:
            return await questionGenerator.generateBehavioralQuestions(for: profile, count: count)
        case .companyFit:
            return await questionGenerator.generateCompanyQuestions(for: profile, count: count)
        case .careerChangeReason:
            return questionGenerator.careerChangeReasonQuestions(for: profile, count: count)
        case .selfIntro:
            return (0..<count).map { _ in questionGenerator.selfIntroQuestion() }
        case .reverseQuestion:
            return questionGenerator.reverseQuestions(for: profile, count: count)
        case .closing:
            return (0..<count).map { _ in questionGenerator.closingQuestion() }
        }
    }
}
