import Foundation
import FoundationModels

@Generable
struct FollowUpQuestionResult {
    @Guide(description: "이전 답변을 심화하는 꼬리질문 한 문장")
    var questionText: String
    @Guide(description: "답변 시 참고할 키워드, 쉼표로 구분")
    var promptKeywords: String
}

@MainActor
final class FollowUpQuestionGenerator {
    private let model = SystemLanguageModel.default

    func generate(
        profile: CandidateProfile,
        parentQuestion: GeneratedQuestion,
        answerTranscript: String
    ) async -> GeneratedQuestion {
        if case .available = model.availability,
           let generated = await generateWithFoundationModels(
               profile: profile,
               parentQuestion: parentQuestion,
               answerTranscript: answerTranscript
           ) {
            return generated
        }

        return fallbackFollowUp(parentQuestion: parentQuestion, answerTranscript: answerTranscript)
    }

    private func generateWithFoundationModels(
        profile: CandidateProfile,
        parentQuestion: GeneratedQuestion,
        answerTranscript: String
    ) async -> GeneratedQuestion? {
        do {
            let session = LanguageModelSession(instructions: """
            화상면접 면접관으로서 지원자의 직전 답변을 바탕으로 꼬리질문 하나를 생성합니다.
            답변에서 언급된 경험·역할·성과를 더 구체화하도록 유도하세요.
            이론·정의 질문은 금지합니다.
            """)

            let prompt = """
            [회사] \(profile.company)
            [직무] \(profile.role)
            [원 질문] \(parentQuestion.questionText)
            [지원자 답변 요약/전사]
            \(answerTranscript.prefix(1200))
            """

            let response = try await session.respond(to: prompt, generating: FollowUpQuestionResult.self)
            let text = response.content.questionText
            guard InterviewQuestionValidator.isValidQuestionText(text) else { return nil }

            return GeneratedQuestion(
                questionText: text,
                promptKeywords: response.content.promptKeywords,
                recommendedSeconds: 30,
                category: .followUp
            )
        } catch {
            return nil
        }
    }

    private func fallbackFollowUp(
        parentQuestion: GeneratedQuestion,
        answerTranscript: String
    ) -> GeneratedQuestion {
        let snippet = answerTranscript.prefix(40)
        let context = snippet.isEmpty ? "방금 말씀하신 내용" : "「\(snippet)…」"
        return GeneratedQuestion(
            questionText: "\(context)과 관련해 본인의 구체적 역할과 결과를 한 가지 더 설명해 주세요.",
            promptKeywords: "역할, 행동, 결과, 수치",
            recommendedSeconds: 30,
            category: .followUp
        )
    }
}
