import Foundation
import FoundationModels

@Generable
struct QuestionContentScoreResult {
    @Guide(description: "답변 내용 점수. 0~100 정수.")
    var score: Int
    @Guide(description: "점수 산정 근거 한 문장")
    var rationale: String
}

@MainActor
final class ContentScorer {
    private let model = SystemLanguageModel.default

    func score(question: QuestionRecord, transcript: String) async -> Int {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        if case .available = model.availability,
           let aiScore = await scoreWithFoundationModels(question: question, transcript: trimmed) {
            return aiScore
        }

        return fallbackScore(question: question, transcript: trimmed)
    }

    private func scoreWithFoundationModels(
        question: QuestionRecord,
        transcript: String
    ) async -> Int? {
        do {
            let session = LanguageModelSession(instructions: """
            화상면접 답변 내용을 0~100점으로 평가합니다.
            질문 적합성, 구체성, 논리 구조, 키워드 반영을 기준으로 합리적인 점수를 부여하세요.
            """)
            let prompt = """
            [질문] \(question.questionText)
            [참고 키워드] \(question.promptKeywords)
            [답변] \(transcript)
            """
            let response = try await session.respond(to: prompt, generating: QuestionContentScoreResult.self)
            return min(100, max(0, response.content.score))
        } catch {
            return nil
        }
    }

    private func fallbackScore(question: QuestionRecord, transcript: String) -> Int {
        let keywordScore = keywordCoverageScore(question: question, transcript: transcript)
        let lengthScore = lengthScore(for: transcript)
        let starScore = starStructureScore(transcript: transcript)
        let weighted = keywordScore * 0.45 + lengthScore * 0.25 + starScore * 0.30
        return Int(min(100, max(0, weighted.rounded())))
    }

    private func keywordCoverageScore(question: QuestionRecord, transcript: String) -> Double {
        let keywords = question.keywordList
        guard !keywords.isEmpty else { return 70 }

        let lowered = transcript.lowercased()
        let matched = keywords.filter { keyword in
            lowered.contains(keyword.lowercased())
        }.count

        return Double(matched) / Double(keywords.count) * 100
    }

    private func lengthScore(for transcript: String) -> Double {
        let count = transcript.count
        if count < 30 { return 25 }
        if count < 80 { return 55 }
        if count < 200 { return 80 }
        return 95
    }

    private func starStructureScore(transcript: String) -> Double {
        let markers = ["상황", "과제", "행동", "결과", "문제", "해결", "성과", "협업", "개선"]
        let hits = markers.filter { transcript.contains($0) }.count
        return min(100, Double(hits) / 3 * 100)
    }
}
