import Foundation

struct FreePracticeConfiguration: Codable, Equatable, Sendable {
    var selectedTopics: Set<PracticeTopic>
    var questionCount: Int

    static let `default` = FreePracticeConfiguration(
        selectedTopics: PracticeTopic.defaultSelection,
        questionCount: 2
    )

    var isValid: Bool {
        !selectedTopics.isEmpty && questionCount >= 1
    }

    var summaryLabel: String {
        let topics = orderedSelectedTopics.map(\.displayName).joined(separator: ", ")
        return "\(topics) · \(questionCount)문항"
    }

    var orderedSelectedTopics: [PracticeTopic] {
        PracticeTopic.practiceOrder.filter { selectedTopics.contains($0) }
    }

    func topicSequence() -> [PracticeTopic] {
        let ordered = orderedSelectedTopics
        guard !ordered.isEmpty else { return [] }
        return (0..<questionCount).map { ordered[$0 % ordered.count] }
    }

    var preparationToken: String {
        let topics = orderedSelectedTopics.map(\.rawValue).joined(separator: ",")
        return "\(topics)|\(questionCount)"
    }

    /// 선택 항목 중 AI 생성이 필요한 항목이 있는지
    var requiresAIGeneration: Bool {
        orderedSelectedTopics.contains { !$0.usesPresetQuestions }
    }

    /// 자유 연습은 항상 옵션 선택 후 수동 생성
    var usesManualQuestionGeneration: Bool {
        isValid
    }
}
