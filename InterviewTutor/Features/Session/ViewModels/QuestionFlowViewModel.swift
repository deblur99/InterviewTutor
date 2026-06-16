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
        questions.filter { $0.category == .documentBased }.count
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

    func insertFollowUp(_ question: GeneratedQuestion, afterIndex index: Int) {
        let insertAt = min(index + 1, questions.count)
        questions.insert(question, at: insertAt)
    }

    func reset() {
        currentIndex = 0
    }

    func category(for index: Int) -> QuestionCategory {
        guard index >= 0, index < questions.count else { return .documentBased }
        return questions[index].category
    }
}
