import Foundation
import FoundationModels

@Generable
struct GeneratedQuestionSet {
    @Guide(description: "서류 기반 화상면접 질문 5개. 이론적 지식 질문은 제외.")
    var questions: [GeneratedQuestionItem]
}

@Generable
struct GeneratedQuestionItem {
    @Guide(description: "면접관이 지원자에게 직접 묻는 질문 문장. 이력서·공고의 항목 제목을 그대로 복사하지 말 것.")
    var questionText: String
    @Guide(description: "답변 시 참고할 키워드, 쉼표로 구분")
    var promptKeywords: String
    @Guide(description: "권장 답변 시간(초), 30~60 사이")
    var recommendedSeconds: Int
}

@Generable
struct GeneratedFeedbackSet {
    var feedbacks: [GeneratedFeedbackItem]
}

@Generable
struct GeneratedFeedbackItem {
    var questionIndex: Int
    var feedback: String
}

@MainActor
final class QuestionGenerator {
    private let model = SystemLanguageModel.default

    func generateQuestions(for profile: CandidateProfile, count: Int = 5) async -> [GeneratedQuestion] {
        let documentQuestions = await generateDocumentQuestions(for: profile, count: count)
        return buildFullQuestionSet(documentQuestions: documentQuestions)
    }

    func generateDocumentQuestions(for profile: CandidateProfile, count: Int) async -> [GeneratedQuestion] {
        if case .available = model.availability {
            return await generateWithFoundationModels(profile: profile, count: count)
        }
        return fallbackQuestions(for: profile, count: count)
    }

    func buildFullQuestionSet(documentQuestions: [GeneratedQuestion]) -> [GeneratedQuestion] {
        var result: [GeneratedQuestion] = []

        result.append(GeneratedQuestion(
            id: UUID(),
            questionText: "1분 이내로 자기소개를 해 주세요.",
            promptKeywords: "이름, 경력, 지원동기, 강점",
            recommendedSeconds: 60
        ))

        result.append(contentsOf: documentQuestions)
        result.append(GeneratedQuestion(
            id: UUID(),
            questionText: "마지막으로 하고 싶은 말씀이 있으시면 해 주세요.",
            promptKeywords: "감사, 열정, 회사 관심",
            recommendedSeconds: 60
        ))

        return result
    }

    private func generateWithFoundationModels(
        profile: CandidateProfile,
        count: Int
    ) async -> [GeneratedQuestion] {
        do {
            let session = LanguageModelSession(instructions: """
            당신은 화상면접 연습을 돕는 면접관입니다.
            지원자의 이력서와 채용공고를 바탕으로 실무 경험 중심의 면접 질문을 생성합니다.
            이론적 배경이나 개념 정의 질문은 절대 포함하지 마세요.

            반드시 지킬 규칙:
            - questionText는 면접관이 입으로 묻는 질문 문장이어야 합니다.
            - 이력서·채용공고·자기소개서의 문장, 프로젝트명, 항목 제목을 그대로 복사하지 마세요.
            - 질문은 "…설명해 주세요", "…말씀해 주세요"처럼 질문 형태로 끝내세요.
            - 자기소개서가 없으면 이력서와 채용공고만 참고하세요.
            """)

            let coverLetterSection: String
            if let coverLetter = ProfileDocumentText.meaningfulCoverLetter(profile.coverLetterText) {
                coverLetterSection = String(coverLetter.prefix(2000))
            } else {
                coverLetterSection = "(제출되지 않음 — 이력서와 채용공고만 참고)"
            }

            let prompt = """
            다음 정보를 바탕으로 서류 기반 면접 질문 \(count)개를 생성하세요.

            [회사] \(profile.company)
            [직무] \(profile.role)
            [산업] \(profile.industry)
            [채용공고]
            \(profile.jobDescription.prefix(2000))

            [이력서]
            \(profile.resumeText.prefix(2000))

            [자기소개서]
            \(coverLetterSection)
            """

            let response = try await session.respond(to: prompt, generating: GeneratedQuestionSet.self)

            let generated = response.content.questions.map { item in
                GeneratedQuestion(
                    id: UUID(),
                    questionText: item.questionText,
                    promptKeywords: item.promptKeywords,
                    recommendedSeconds: min(max(item.recommendedSeconds, 30), 60)
                )
            }

            let valid = generated.filter { InterviewQuestionValidator.isValidQuestionText($0.questionText) }
            if valid.count >= count {
                return Array(valid.prefix(count))
            }

            return supplementQuestions(valid: valid, profile: profile, count: count)
        } catch {
            return fallbackQuestions(for: profile, count: count)
        }
    }

    private func supplementQuestions(
        valid: [GeneratedQuestion],
        profile: CandidateProfile,
        count: Int
    ) -> [GeneratedQuestion] {
        var result = valid
        let resumeBased = resumeTopicQuestions(for: profile, count: count)

        for candidate in resumeBased {
            guard result.count < count else { break }
            guard !result.contains(where: { $0.questionText == candidate.questionText }) else { continue }
            result.append(candidate)
        }

        if result.count < count {
            let generic = genericFallbackQuestions(for: profile, count: count - result.count)
            for candidate in generic {
                guard result.count < count else { break }
                guard !result.contains(where: { $0.questionText == candidate.questionText }) else { continue }
                result.append(candidate)
            }
        }

        return Array(result.prefix(count))
    }

    private func fallbackQuestions(for profile: CandidateProfile, count: Int) -> [GeneratedQuestion] {
        let resumeBased = resumeTopicQuestions(for: profile, count: count)
        if resumeBased.count >= count {
            return Array(resumeBased.prefix(count))
        }

        var result = resumeBased
        let generic = genericFallbackQuestions(for: profile, count: count - result.count)
        result.append(contentsOf: generic)
        return Array(result.prefix(count))
    }

    private func resumeTopicQuestions(for profile: CandidateProfile, count: Int) -> [GeneratedQuestion] {
        ResumeTopicExtractor.topics(from: profile.resumeText, limit: count).map { topic in
            GeneratedQuestion(
                id: UUID(),
                questionText: ResumeTopicExtractor.question(from: topic),
                promptKeywords: "역할, 성과, 기술, 협업",
                recommendedSeconds: 45
            )
        }
    }

    private func genericFallbackQuestions(for profile: CandidateProfile, count: Int) -> [GeneratedQuestion] {
        var templates = [
            "이력서에 기재된 \(profile.role) 경험 중 가장 도전적이었던 프로젝트와 본인의 역할을 설명해 주세요.",
            "\(profile.company)에 지원하게 된 구체적인 계기와 입사 후 기여하고 싶은 부분을 말씀해 주세요.",
            "팀 내 갈등이나 의견 충돌 상황을 어떻게 해결했는지 경험을 공유해 주세요.",
            "채용공고의 핵심 요건 중 본인이 가장 자신 있는 역량과 그 근거를 설명해 주세요.",
            "프로젝트 일정이 촉박했을 때 우선순위를 어떻게 정하고 실행했는지 말씀해 주세요.",
            "새로운 기술이나 업무 영역을 빠르게 학습했던 경험을 소개해 주세요.",
        ]

        if ProfileDocumentText.meaningfulCoverLetter(profile.coverLetterText) != nil {
            templates.insert(
                "자기소개서에 언급한 강점이 실제 업무에서 어떻게 발휘되었는지 사례를 들어 설명해 주세요.",
                at: 2
            )
        }

        return templates.prefix(count).map { text in
            GeneratedQuestion(
                id: UUID(),
                questionText: text,
                promptKeywords: "경험, 역할, 성과, 배운점",
                recommendedSeconds: 45
            )
        }
    }
}
