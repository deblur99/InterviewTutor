import Foundation

@Observable
final class QuestionFlowViewModel {
    private(set) var questions: [GeneratedQuestion] = []
    private(set) var currentIndex = 0

    var currentQuestion: GeneratedQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var isFirstQuestion: Bool { currentIndex == 0 }
    var isLastQuestion: Bool { currentIndex >= questions.count - 1 }
    var totalCount: Int { questions.count }

    var documentQuestionCount: Int {
        max(0, questions.count - 2)
    }

    var expectedDurationSeconds: Int {
        questions.reduce(0) { $0 + $1.recommendedSeconds } + 30
    }

    func setQuestions(_ questions: [GeneratedQuestion]) {
        self.questions = questions
        self.currentIndex = 0
    }

    func advance() -> Bool {
        guard currentIndex < questions.count - 1 else { return false }
        currentIndex += 1
        return true
    }

    func reset() {
        currentIndex = 0
    }

    func category(for index: Int) -> QuestionCategory {
        if index == 0 { return .selfIntro }
        if index == questions.count - 1 { return .closing }
        return .documentBased
    }
}
