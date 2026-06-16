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
}
