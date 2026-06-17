import Foundation

struct CustomInterviewQuestion: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    var questionText: String
    var expectedAnswer: String
    var recommendedSeconds: Int
    var stageRawValues: [String]

    init(
        id: UUID = UUID(),
        questionText: String,
        expectedAnswer: String = "",
        recommendedSeconds: Int = 90,
        stages: Set<SessionStage> = Set(SessionStage.allCases)
    ) {
        self.id = id
        self.questionText = questionText
        self.expectedAnswer = expectedAnswer
        self.recommendedSeconds = min(max(recommendedSeconds, 30), 180)
        self.stageRawValues = stages.map(\.rawValue).sorted()
    }

    var stages: Set<SessionStage> {
        Set(stageRawValues.compactMap(SessionStage.init(rawValue:)))
    }

    func applies(to stage: SessionStage) -> Bool {
        stages.contains(stage)
    }

    var isValid: Bool {
        !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func toGeneratedQuestion() -> GeneratedQuestion {
        let answer = expectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        return GeneratedQuestion(
            questionText: questionText.trimmingCharacters(in: .whitespacesAndNewlines),
            promptKeywords: answer.isEmpty ? "핵심, 근거, 결론" : answer,
            recommendedSeconds: recommendedSeconds,
            category: .comprehensive,
            topicLabel: "사용자 등록 질문",
            expectedAnswer: answer.isEmpty ? nil : answer
        )
    }
}
