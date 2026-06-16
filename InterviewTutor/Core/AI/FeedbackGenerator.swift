import Foundation
import FoundationModels

@MainActor
final class FeedbackGenerator {
    private let model = SystemLanguageModel.default

    func generateFeedback(
        questions: [QuestionRecord]
    ) async -> [Int: String] {
        var results: [Int: String] = [:]

        for question in questions {
            let duration = question.endTimestamp - question.startTimestamp
            let recommended = TimeInterval(question.recommendedSeconds)

            if case .available = model.availability, !question.transcribedAnswer.isEmpty {
                if let feedback = await generateAIFeedback(for: question, stage: .beginner) {
                    results[question.orderIndex] = feedback
                    continue
                }
            }

            results[question.orderIndex] = fallbackFeedback(
                question: question,
                fillerCount: question.fillerWordCount,
                duration: duration,
                recommended: recommended
            )
        }

        return results
    }

    func generateFeedbackForQuestion(
        _ question: QuestionRecord,
        fillerReport: FillerWordReport?,
        stage: SessionStage = .beginner
    ) async -> String {
        if case .available = model.availability, !question.transcribedAnswer.isEmpty {
            if let feedback = await generateAIFeedback(for: question, stage: stage) {
                return feedback
            }
        }

        let duration = question.endTimestamp - question.startTimestamp
        return fallbackFeedback(
            question: question,
            fillerCount: fillerReport?.totalCount ?? question.fillerWordCount,
            duration: duration,
            recommended: TimeInterval(question.recommendedSeconds),
            stage: stage
        )
    }

    private func generateAIFeedback(for question: QuestionRecord, stage: SessionStage) async -> String? {
        do {
            let instructions = switch stage {
            case .beginner:
                """
                화상면접 연습 코치로서 지원자의 답변에 대해 간결하고 건설적인 피드백을 제공합니다.
                3~5문장으로 답변 구조, 구체성, 개선점을 제시하세요.
                """
            case .skilled, .expert:
                """
                숙련 단계 화상면접 코치입니다. 답변의 구체성, 논리 구조(SITUATION-ACTION-RESULT), 질문 적합성을 중심으로 평가하세요.
                추상적 표현·근거 부족·결론 누락을 지적하고, 한 가지 실행 가능한 개선 제안을 포함하세요. 3~5문장.
                """
            case .freePractice:
                """
                자유 연습 코치입니다. 선택한 연습 항목에 맞춰 답변을 평가하고, 바로 적용할 수 있는 한 가지 개선 팁을 제시하세요. 2~4문장.
                """
            }

            let session = LanguageModelSession(instructions: instructions)

            let prompt = """
            [질문] \(question.questionText)
            [답변 STT] \(question.transcribedAnswer)
            [권장 시간] \(question.recommendedSeconds)초
            [실제 시간] \(Int(question.endTimestamp - question.startTimestamp))초
            [필러워드 횟수] \(question.fillerWordCount)회
            """

            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            return nil
        }
    }

    private func fallbackFeedback(
        question: QuestionRecord,
        fillerCount: Int,
        duration: TimeInterval,
        recommended: TimeInterval,
        stage: SessionStage = .beginner
    ) -> String {
        var parts: [String] = []

        if question.transcribedAnswer.isEmpty {
            parts.append("답변이 인식되지 않았습니다. 마이크와 발음을 확인해 주세요.")
        } else if question.transcribedAnswer.count < 30 {
            if stage == .beginner {
                parts.append("답변이 다소 짧습니다. STAR 구조(상황-과제-행동-결과)로 구체적 사례를 추가해 보세요.")
            } else {
                parts.append("답변이 다소 짧습니다. 상황·본인 역할·행동·결과를 순서대로 보강해 보세요.")
            }
        } else if stage == .skilled || stage == .expert {
            parts.append("답변 내용이 인식되었습니다. 주장마다 근거 사례와 수치를 연결하면 논리 구조가 더 명확해집니다.")
        } else if stage == .freePractice {
            parts.append("답변이 인식되었습니다. 이 항목에서 한 문장 더 구체화하면 설득력이 높아집니다.")
        } else {
            parts.append("답변 내용이 인식되었습니다. 핵심 성과를 수치로 보강하면 더 설득력이 높아집니다.")
        }

        if duration > recommended + 15 {
            parts.append("권장 시간(\(Int(recommended))초)보다 \(Int(duration - recommended))초 길었습니다. 핵심만 전달하도록 연습해 보세요.")
        } else if duration < recommended - 15 && duration > 0 {
            parts.append("답변이 다소 짧았습니다. 경험의 맥락과 본인 역할을 더 설명해 보세요.")
        }

        if fillerCount >= 5 {
            parts.append("필러워드(어, 음 등)가 \(fillerCount)회 감지되었습니다. 답변 전 핵심 키워드 3개를 먼저 정리해 보세요.")
        } else if fillerCount > 0 {
            parts.append("필러워드가 \(fillerCount)회 사용되었습니다. 문장 사이 1초 멈춤으로 자연스러움을 유지해 보세요.")
        }

        return parts.joined(separator: " ")
    }

    func generatePracticeSummary(
        questions: [QuestionRecord],
        configuration: FreePracticeConfiguration
    ) async -> String {
        let topics = configuration.orderedSelectedTopics.map(\.displayName).joined(separator: ", ")

        if case .available = model.availability,
           let summary = await generatePracticeSummaryWithAI(questions: questions, topics: topics) {
            return summary
        }

        return fallbackPracticeSummary(questions: questions, configuration: configuration)
    }

    private func generatePracticeSummaryWithAI(
        questions: [QuestionRecord],
        topics: String
    ) async -> String? {
        do {
            let session = LanguageModelSession(instructions: """
            자유 연습 세션 종합 코치입니다. 오늘 연습한 항목 전체를 돌아보며 강점 1가지, 개선점 1가지, 다음 연습 제안 1가지를 제시하세요. 4~6문장.
            """)

            let details = questions.enumerated().map { index, question in
                """
                \(index + 1). [\(question.category.displayName)] \(question.questionText)
                답변: \(question.transcribedAnswer.prefix(200))
                피드백: \(question.aiFeedback.prefix(150))
                """
            }.joined(separator: "\n")

            let prompt = """
            [연습 항목] \(topics)
            [문항별 기록]
            \(details)
            """

            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            return nil
        }
    }

    private func fallbackPracticeSummary(
        questions: [QuestionRecord],
        configuration: FreePracticeConfiguration
    ) -> String {
        let topics = configuration.orderedSelectedTopics.map(\.displayName).joined(separator: ", ")
        let avgContent = questions.compactMap(\.contentScore).reduce(0, +)
        let scoredCount = questions.compactMap(\.contentScore).count
        let average = scoredCount > 0 ? avgContent / scoredCount : 0

        var parts = ["오늘은 \(topics) 항목을 \(questions.count)문항 연습했습니다."]
        if average > 0 {
            parts.append("평균 내용 점수는 \(average)점입니다.")
        }
        if let weakest = questions.min(by: { ($0.contentScore ?? 100) < ($1.contentScore ?? 100) }) {
            parts.append("다음에는 \(weakest.category.displayName) 항목에서 사례와 수치를 한 가지 더 보강해 보세요.")
        }
        return parts.joined(separator: " ")
    }
}
