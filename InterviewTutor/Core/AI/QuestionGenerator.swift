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
struct GeneratedBehavioralQuestionSet {
    var questions: [GeneratedQuestionItem]
}

@Generable
struct GeneratedCompanyQuestionSet {
    var questions: [GeneratedQuestionItem]
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

    func buildFullQuestionSet(
        documentQuestions: [GeneratedQuestion],
        stage: SessionStage = .beginner
    ) -> [GeneratedQuestion] {
        switch stage {
        case .beginner:
            return buildBeginnerQuestionSet(documentQuestions: documentQuestions)
        case .skilled, .expert:
            return documentQuestions
        }
    }

    func buildBeginnerQuestionSet(documentQuestions: [GeneratedQuestion]) -> [GeneratedQuestion] {
        var result: [GeneratedQuestion] = []

        result.append(GeneratedQuestion(
            questionText: "1분 이내로 자기소개를 해 주세요.",
            promptKeywords: "이름, 경력, 지원동기, 강점",
            recommendedSeconds: 60,
            category: .selfIntro
        ))

        result.append(contentsOf: documentQuestions.map {
            GeneratedQuestion(
                id: $0.id,
                questionText: $0.questionText,
                promptKeywords: $0.promptKeywords,
                recommendedSeconds: $0.recommendedSeconds,
                category: .documentBased
            )
        })

        result.append(GeneratedQuestion(
            questionText: "마지막으로 하고 싶은 말씀이 있으시면 해 주세요.",
            promptKeywords: "감사, 열정, 회사 관심",
            recommendedSeconds: 60,
            category: .closing
        ))

        return result
    }

    func buildSkilledQuestionSet(
        documentQuestions: [GeneratedQuestion],
        behavioralQuestions: [GeneratedQuestion],
        companyQuestions: [GeneratedQuestion]
    ) -> [GeneratedQuestion] {
        var result: [GeneratedQuestion] = []

        result.append(GeneratedQuestion(
            questionText: "1분 이내로 자기소개를 해 주세요.",
            promptKeywords: "이름, 경력, 지원동기, 강점",
            recommendedSeconds: 60,
            category: .selfIntro
        ))

        result.append(contentsOf: documentQuestions.map {
            GeneratedQuestion(
                id: $0.id,
                questionText: $0.questionText,
                promptKeywords: $0.promptKeywords,
                recommendedSeconds: $0.recommendedSeconds,
                category: .documentBased
            )
        })

        result.append(contentsOf: behavioralQuestions.map {
            GeneratedQuestion(
                id: $0.id,
                questionText: $0.questionText,
                promptKeywords: $0.promptKeywords,
                recommendedSeconds: max($0.recommendedSeconds, 75),
                category: .behavioral
            )
        })

        result.append(contentsOf: companyQuestions.map {
            GeneratedQuestion(
                id: $0.id,
                questionText: $0.questionText,
                promptKeywords: $0.promptKeywords,
                recommendedSeconds: $0.recommendedSeconds,
                category: .companyFit
            )
        })

        result.append(GeneratedQuestion(
            questionText: "마지막으로 하고 싶은 말씀이 있으시면 해 주세요.",
            promptKeywords: "감사, 열정, 회사 관심",
            recommendedSeconds: 60,
            category: .closing
        ))

        return result
    }

    func generateBehavioralQuestions(for profile: CandidateProfile, count: Int) async -> [GeneratedQuestion] {
        if case .available = model.availability,
           let generated = await generateBehavioralWithFoundationModels(profile: profile, count: count) {
            return generated
        }
        return behavioralFallbackQuestions(for: profile, count: count)
    }

    func generateCompanyQuestions(for profile: CandidateProfile, count: Int) async -> [GeneratedQuestion] {
        if case .available = model.availability,
           let generated = await generateCompanyWithFoundationModels(profile: profile, count: count) {
            return generated
        }
        return companyFallbackQuestions(for: profile, count: count)
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
                recommendedSeconds: min(max(item.recommendedSeconds, 30), 60),
                category: .documentBased
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
                recommendedSeconds: 45,
                category: .documentBased
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
                recommendedSeconds: 45,
                category: .documentBased
            )
        }
    }

    private func generateBehavioralWithFoundationModels(
        profile: CandidateProfile,
        count: Int
    ) async -> [GeneratedQuestion]? {
        do {
            let session = LanguageModelSession(instructions: """
            인성·상황 면접 질문을 생성합니다. STAR(상황-과제-행동-결과) 답변을 유도하세요.
            이론·정의 질문은 금지합니다.
            """)

            let prompt = """
            [회사] \(profile.company)
            [산업] \(profile.industry)
            [직무] \(profile.role)
            인성·상황 질문 \(count)개를 생성하세요.
            """

            let response = try await session.respond(to: prompt, generating: GeneratedBehavioralQuestionSet.self)
            let questions = response.content.questions.compactMap { item -> GeneratedQuestion? in
                guard InterviewQuestionValidator.isValidQuestionText(item.questionText) else { return nil }
                return GeneratedQuestion(
                    questionText: item.questionText,
                    promptKeywords: item.promptKeywords.isEmpty ? "상황, 과제, 행동, 결과, STAR" : item.promptKeywords,
                    recommendedSeconds: min(max(item.recommendedSeconds, 60), 90),
                    category: .behavioral
                )
            }
            return questions.count >= count ? Array(questions.prefix(count)) : nil
        } catch {
            return nil
        }
    }

    private func behavioralFallbackQuestions(for profile: CandidateProfile, count: Int) -> [GeneratedQuestion] {
        let templates = [
            "팀원과 의견이 충돌했던 상황을 STAR 구조로 설명해 주세요.",
            "예상치 못한 문제가 발생했을 때 어떻게 대응했는지 구체적으로 말씀해 주세요.",
            "리더십을 발휘해야 했던 경험과 그 결과를 설명해 주세요.",
            "실패했던 경험과 그로부터 무엇을 배웠는지 말씀해 주세요.",
        ]

        return templates.prefix(count).map { text in
            GeneratedQuestion(
                questionText: text,
                promptKeywords: "상황, 과제, 행동, 결과, STAR",
                recommendedSeconds: 90,
                category: .behavioral
            )
        }
    }

    private func generateCompanyWithFoundationModels(
        profile: CandidateProfile,
        count: Int
    ) async -> [GeneratedQuestion]? {
        do {
            let session = LanguageModelSession(instructions: """
            지원 회사·산업·직무에 맞는 면접 질문을 생성합니다.
            채용공고와 이력서 맥락만 사용하고, 외부 추측은 하지 마세요.
            """)

            let prompt = """
            [회사] \(profile.company)
            [산업] \(profile.industry)
            [직무] \(profile.role)
            [채용공고]
            \(profile.jobDescription.prefix(1500))

            회사·직무 맞춤 질문 \(count)개를 생성하세요.
            """

            let response = try await session.respond(to: prompt, generating: GeneratedCompanyQuestionSet.self)
            let questions = response.content.questions.compactMap { item -> GeneratedQuestion? in
                guard InterviewQuestionValidator.isValidQuestionText(item.questionText) else { return nil }
                return GeneratedQuestion(
                    questionText: item.questionText,
                    promptKeywords: item.promptKeywords.isEmpty ? "회사, 직무, 기여, 동기" : item.promptKeywords,
                    recommendedSeconds: min(max(item.recommendedSeconds, 45), 60),
                    category: .companyFit
                )
            }
            return questions.count >= count ? Array(questions.prefix(count)) : nil
        } catch {
            return nil
        }
    }

    private func companyFallbackQuestions(for profile: CandidateProfile, count: Int) -> [GeneratedQuestion] {
        let templates = [
            "\(profile.company)에 지원한 구체적인 이유와 입사 후 기여하고 싶은 점을 말씀해 주세요.",
            "\(profile.industry) 산업에서 \(profile.role) 직무가 중요한 이유를 본인 관점에서 설명해 주세요.",
            "채용공고의 핵심 요구 역량 중 본인 경험과 가장 연결되는 부분을 설명해 주세요.",
        ]

        return templates.prefix(count).map { text in
            GeneratedQuestion(
                questionText: text,
                promptKeywords: "회사, 직무, 기여, 동기",
                recommendedSeconds: 60,
                category: .companyFit
            )
        }
    }
}
