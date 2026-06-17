import Foundation
import FoundationModels

struct AnswerPrompterContent: Equatable, Sendable {
    let scriptSentences: [String]
    let tip: String
}

@Generable
struct GeneratedAnswerPrompter {
    @Guide(description: "면접 답변 참고용 전문. 완결된 문장 3~4개")
    var scriptSentences: [String]

    @Guide(description: "답변 시 기억할 실용 팁 한 문장")
    var tip: String
}

@MainActor
final class AnswerPrompterGenerator {
    private let model = SystemLanguageModel.default

    func generate(
        profile: CandidateProfile,
        question: GeneratedQuestion,
        stage: SessionStage
    ) async -> AnswerPrompterContent {
        if case .available = model.availability,
           let generated = await generateWithFoundationModels(
               profile: profile,
               question: question,
               stage: stage
           ) {
            return generated
        }

        return fallbackContent(for: question, profile: profile)
    }

    private func generateWithFoundationModels(
        profile: CandidateProfile,
        question: GeneratedQuestion,
        stage: SessionStage
    ) async -> AnswerPrompterContent? {
        do {
            let session = LanguageModelSession(instructions: """
            화상면접 연습용 프롬프터를 작성합니다.
            지원자가 질문에 답할 때 참고할 예시 답변 전문(3~4문장)과 실용 팁(1문장)을 제공합니다.
            전문은 자연스럽게 말할 수 있는 구어체 문장으로 작성하고, 지원자의 서류 정보를 반영하세요.
            """)

            let prompt = """
            [회사] \(profile.company)
            [직무] \(profile.role)
            [연습 단계] \(stage.displayName)
            [질문] \(question.questionText)
            [참고 키워드] \(question.promptKeywords)
            """

            let response = try await session.respond(to: prompt, generating: GeneratedAnswerPrompter.self)
            let sentences = response.content.scriptSentences
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard sentences.count >= 2 else { return nil }

            let tip = response.content.tip.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tip.isEmpty else { return nil }

            return AnswerPrompterContent(
                scriptSentences: Array(sentences.prefix(4)),
                tip: tip
            )
        } catch {
            return nil
        }
    }

    private func fallbackContent(for question: GeneratedQuestion, profile: CandidateProfile) -> AnswerPrompterContent {
        let keywords = question.promptKeywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let keywordPhrase = keywords.prefix(3).joined(separator: ", ")
        let topic = question.displayTopicName

        let sentences: [String]
        if let expected = question.expectedAnswer, !expected.isEmpty {
            let parts = expected
                .split(whereSeparator: { ".!?。".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            sentences = parts.isEmpty
                ? fallbackSentences(keywordPhrase: keywordPhrase, topic: topic, profile: profile, question: question)
                : Array(parts.prefix(4))
        } else {
            sentences = fallbackSentences(
                keywordPhrase: keywordPhrase,
                topic: topic,
                profile: profile,
                question: question
            )
        }

        return AnswerPrompterContent(
            scriptSentences: sentences,
            tip: "답변은 \(keywordPhrase.isEmpty ? topic : keywordPhrase)를 중심으로 짧은 문장으로 말하고, 마지막에 한 줄 결론을 덧붙이세요."
        )
    }

    private func fallbackSentences(
        keywordPhrase: String,
        topic: String,
        profile: CandidateProfile,
        question: GeneratedQuestion
    ) -> [String] {
        [
            "안녕하세요. \(profile.company) \(profile.role) 지원자입니다.",
            "질문 주신 \(topic) 내용에 대해 경험을 바탕으로 말씀드리겠습니다.",
            keywordPhrase.isEmpty
                ? "핵심 경험을 상황, 역할, 결과 순으로 간결하게 설명하겠습니다."
                : "\(keywordPhrase) 관점에서 제가 맡았던 역할과 성과를 연결해 설명드리겠습니다.",
            "이상으로 \(question.questionText.prefix(20))…에 대한 답변을 마치겠습니다.",
        ]
    }
}
