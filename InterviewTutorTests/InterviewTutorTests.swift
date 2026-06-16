import Foundation
import Testing
@testable import InterviewTutor

struct FillerWordAnalyzerTests {

    @Test func countsKoreanFillerWords() {
        let report = FillerWordAnalyzer.analyze("어 그러니까 프로젝트를 어 진행했고 음 결과가 좋았습니다")
        #expect(report.totalCount == 4)
        #expect(report.breakdown["어"] == 2)
        #expect(report.breakdown["음"] == 1)
        #expect(report.breakdown["그러니까"] == 1)
    }

    @Test func returnsZeroForCleanText() {
        let report = FillerWordAnalyzer.analyze("프로젝트 일정을 관리하고 팀과 협업했습니다")
        #expect(report.totalCount == 0)
        #expect(report.breakdown.isEmpty)
    }
}

struct SupportedDocumentTypeTests {

    @Test func acceptsSupportedExtensions() {
        #expect(SupportedDocumentType(fileExtension: "pdf") == .pdf)
        #expect(SupportedDocumentType(fileExtension: "PNG") == .png)
        #expect(SupportedDocumentType(fileExtension: "jpg") == .jpeg)
        #expect(SupportedDocumentType(fileExtension: "jpeg") == .jpeg)
        #expect(SupportedDocumentType(fileExtension: "heic") == .heic)
        #expect(SupportedDocumentType(fileExtension: "gif") == nil)
    }
}

struct OnboardingViewModelTests {

    @Test func applyPendingReviewReplacesFieldText() {
        let viewModel = OnboardingViewModel()
        viewModel.jobDescription = "기존 내용"
        viewModel.pendingReview = PendingTextReview(
            field: .jobDescription,
            extractedText: "추출된 공고",
            usedOCR: false,
            sourceDescription: "PDF 텍스트",
            hadExistingContent: true
        )
        viewModel.reviewDraftText = "수정된 공고"

        viewModel.applyPendingReview()

        #expect(viewModel.jobDescription == "수정된 공고")
        #expect(viewModel.pendingReview == nil)
    }
}

struct DocumentTextRefinerTests {

    @Test func splitsLongTextIntoChunks() {
        let paragraph = String(repeating: "가", count: 1_500)
        let text = (0..<3).map { _ in paragraph }.joined(separator: "\n\n")
        let chunks = DocumentTextRefiner.chunks(of: text, maxLength: 2_000)

        #expect(chunks.count >= 2)
        #expect(chunks.allSatisfy { $0.count <= 2_000 })
    }
}

struct JobDescriptionSectionValidatorTests {

    @Test func detectsMissingRequiredSections() {
        let incomplete = """
        채용공고: iOS 개발자
        회사명: LG
        근무지: 서울
        """
        let missing = JobDescriptionSectionValidator.missingSections(in: incomplete)
        #expect(missing.contains(.unit))
        #expect(missing.contains(.major))
        #expect(missing.contains(.qualifications))
        #expect(missing.contains(.preferred))
        #expect(missing.contains(.process))
    }

    @Test func acceptsCompleteJobDescription() {
        let complete = """
        채용공고: iOS 개발자
        채용회사: LG
        모집단위: DX부문
        근무지: 서울
        전공 요구: 컴퓨터공학
        지원 자격: 3년 이상
        우대 사항: Swift 경험
        직무 소개: 앱 개발
        채용 절차: 서류-면접-최종
        """
        let missing = JobDescriptionSectionValidator.missingSections(in: complete)
        #expect(missing.isEmpty)
    }

    @Test func preservesRequiredSectionHeadersInFallback() {
        #expect(JobDescriptionSectionValidator.isRequiredSectionHeader("우대 사항"))
        #expect(JobDescriptionSectionValidator.isRequiredSectionHeader("채용 절차"))
        #expect(!JobDescriptionSectionValidator.isRequiredSectionHeader("1 / 3"))
    }
}

struct ProfileFingerprintTests {

    @Test func producesStableFingerprint() {
        let profile = CandidateProfile(
            company: "LG",
            role: "iOS",
            jobDescription: "JD",
            resumeText: "Resume",
            coverLetterText: "Cover"
        )
        let first = ProfileFingerprint.make(for: profile)
        let second = ProfileFingerprint.make(for: profile)
        #expect(first == second)
    }

    @Test func changesWhenProfileChanges() {
        let profile = CandidateProfile(company: "LG", role: "iOS")
        let before = ProfileFingerprint.make(for: profile)
        profile.company = "Samsung"
        let after = ProfileFingerprint.make(for: profile)
        #expect(before != after)
    }
}

struct CandidateProfileDisplayTests {

    @Test func buildsDisplayTitleFromCompanyAndRole() {
        let profile = CandidateProfile(company: "LG", role: "iOS")
        #expect(profile.displayTitle == "LG · iOS")
    }

    @Test func assignsProfileIDWhenMissing() {
        let profile = CandidateProfile(company: "LG")
        #expect(profile.profileID == nil)
        profile.ensureProfileID()
        #expect(profile.profileID != nil)
    }
}

struct InterviewQuestionValidatorTests {

    @Test func acceptsProperQuestionSentences() {
        #expect(InterviewQuestionValidator.isValidQuestionText(
            "해당 프로젝트에서 본인의 역할을 구체적으로 설명해 주세요."
        ))
        #expect(InterviewQuestionValidator.isValidQuestionText(
            "왜 이 회사에 지원하셨나요?"
        ))
    }

    @Test func rejectsResumeFragments() {
        #expect(!InterviewQuestionValidator.isValidQuestionText(
            "불꽃 감지기 데이터 처리 서버리스 API 개발 및 데이터 시각화"
        ))
        #expect(!InterviewQuestionValidator.isValidQuestionText(
            "Android 앱 설계·개발·현장 배포 전 과정 단독 수행 (기여도 100%)"
        ))
    }

    @Test func treatsCoverLetterPlaceholderAsEmpty() {
        #expect(ProfileDocumentText.meaningfulCoverLetter("(내용 없음)") == nil)
        #expect(ProfileDocumentText.meaningfulCoverLetter("실제 자소서 본문") == "실제 자소서 본문")
    }

    @Test func buildsQuestionsFromResumeTopics() {
        let resume = """
        불꽃 감지기 데이터 처리 서버리스 API 개발 및 데이터 시각화
        Android 앱 설계·개발·현장 배포 전 과정 단독 수행
        """
        let topics = ResumeTopicExtractor.topics(from: resume, limit: 2)
        #expect(topics.count == 2)
        let question = ResumeTopicExtractor.question(from: topics[0])
        #expect(InterviewQuestionValidator.isValidQuestionText(question))
        #expect(question.contains("설명해 주세요"))
    }
}

struct DocumentImportBatchTests {

    @Test func rejectsMultiplePDFsInOneBatch() {
        let urls = [
            URL(fileURLWithPath: "/tmp/resume.pdf"),
            URL(fileURLWithPath: "/tmp/jd.pdf"),
        ]

        #expect(throws: DocumentExtractionError.multiplePDFsNotAllowed) {
            try DocumentTextExtractor.validateBatch(urls)
        }
    }

    @Test func allowsSinglePDFWithImages() throws {
        let urls = [
            URL(fileURLWithPath: "/tmp/resume.pdf"),
            URL(fileURLWithPath: "/tmp/page1.png"),
            URL(fileURLWithPath: "/tmp/page2.jpg"),
        ]

        try DocumentTextExtractor.validateBatch(urls)
    }

    @Test func mergesMultipleImageResults() {
        let merged = DocumentTextExtractor.merge([
            DocumentExtractionResult(text: "Page 1", usedOCR: true, sourceDescription: "PNG 이미지 인식"),
            DocumentExtractionResult(text: "Page 2", usedOCR: true, sourceDescription: "JPEG 이미지 인식"),
        ])

        #expect(merged.text.contains("Page 1"))
        #expect(merged.text.contains("Page 2"))
        #expect(merged.sourceDescription == "이미지 2장 인식")
        #expect(merged.usedOCR)
    }
}

struct ActiveProfileStoreTests {

    @Test func selectsRequestedProfile() {
        let store = ActiveProfileStore()
        let first = CandidateProfile(profileID: UUID(), company: "LG", role: "iOS")
        let second = CandidateProfile(profileID: UUID(), company: "Samsung", role: "Android")

        store.select(first)
        #expect(store.isActive(first))
        #expect(!store.isActive(second))

        store.select(second)
        #expect(store.isActive(second))
        #expect(store.activeProfile(in: [first, second])?.company == "Samsung")
    }
}

struct QuestionFlowViewModelTests {

    @Test func buildsExpectedDurationFromQuestions() {
        let flow = QuestionFlowViewModel()
        flow.setQuestions([
            GeneratedQuestion(id: UUID(), questionText: "A", promptKeywords: "", recommendedSeconds: 60, category: .selfIntro),
            GeneratedQuestion(id: UUID(), questionText: "B", promptKeywords: "", recommendedSeconds: 45, category: .documentBased),
            GeneratedQuestion(id: UUID(), questionText: "C", promptKeywords: "", recommendedSeconds: 60, category: .closing),
        ])

        #expect(flow.totalCount == 3)
        #expect(flow.documentQuestionCount == 1)
        #expect(flow.expectedDurationSeconds == 195)
    }

    @Test func advancesThroughQuestions() {
        let flow = QuestionFlowViewModel()
        flow.setQuestions([
            GeneratedQuestion(id: UUID(), questionText: "A", promptKeywords: "", recommendedSeconds: 60),
            GeneratedQuestion(id: UUID(), questionText: "B", promptKeywords: "", recommendedSeconds: 45),
        ])

        #expect(flow.isFirstQuestion)
        #expect(flow.advance())
        #expect(flow.isLastQuestion)
        #expect(!flow.advance())
    }

    @Test func mapsCategories() {
        let flow = QuestionFlowViewModel()
        flow.setQuestions([
            GeneratedQuestion(id: UUID(), questionText: "A", promptKeywords: "", recommendedSeconds: 60, category: .selfIntro),
            GeneratedQuestion(id: UUID(), questionText: "B", promptKeywords: "", recommendedSeconds: 45, category: .documentBased),
            GeneratedQuestion(id: UUID(), questionText: "C", promptKeywords: "", recommendedSeconds: 60, category: .closing),
        ])

        #expect(flow.category(for: 0) == .selfIntro)
        #expect(flow.category(for: 1) == .documentBased)
        #expect(flow.category(for: 2) == .closing)
    }

    @Test func insertsFollowUpAfterDocumentQuestion() {
        let flow = QuestionFlowViewModel()
        let docID = UUID()
        flow.setQuestions([
            GeneratedQuestion(id: UUID(), questionText: "Intro", promptKeywords: "", recommendedSeconds: 60, category: .selfIntro),
            GeneratedQuestion(id: docID, questionText: "Doc", promptKeywords: "", recommendedSeconds: 60, category: .documentBased),
            GeneratedQuestion(id: UUID(), questionText: "Close", promptKeywords: "", recommendedSeconds: 60, category: .closing),
        ])

        let followUp = GeneratedQuestion(questionText: "Follow", promptKeywords: "역할", recommendedSeconds: 30, category: .followUp)
        flow.insertFollowUp(followUp, afterIndex: 1)

        #expect(flow.totalCount == 4)
        #expect(flow.category(for: 2) == .followUp)
        #expect(flow.questions[1].id == docID)
    }
}

struct SessionStagePresetTests {

    @Test func skilledPresetIncludesFollowUps() {
        let preset = SessionStagePreset.preset(for: .skilled)
        #expect(preset.documentQuestionCount == 3)
        #expect(preset.behavioralQuestionCount == 2)
        #expect(preset.companyQuestionCount == 1)
        #expect(preset.generatesFollowUps)
        #expect(preset.sessionSummaryLabel.contains("꼬리질문"))
    }

    @Test func skilledStageIsAvailable() {
        #expect(SessionStage.skilled.isAvailable)
        #expect(!SessionStage.expert.isAvailable)
        #expect(!SessionStage.skilled.coachEnabledByDefault)
    }
}

struct LetterGradeTests {

    @Test func mapsScoreToGrade() {
        #expect(LetterGrade(score: 95) == .s)
        #expect(LetterGrade(score: 85) == .a)
        #expect(LetterGrade(score: 75) == .b)
        #expect(LetterGrade(score: 65) == .c)
        #expect(LetterGrade(score: 55) == .d)
        #expect(LetterGrade(score: 30) == .f)
    }
}

struct SpeechScorerTests {

    @Test func scoresCleanSpeechHighly() {
        let transcript = String(repeating: "프로젝트 성과를 구체적으로 설명하고 협업 경험을 말했습니다 ", count: 12)
        let score = SpeechScorer.score(
            transcript: transcript,
            fillerCount: 0,
            duration: 60,
            recommendedSeconds: 60
        )
        #expect(score >= 70)
    }

    @Test func returnsZeroForEmptyTranscript() {
        let score = SpeechScorer.score(
            transcript: "",
            fillerCount: 0,
            duration: 30,
            recommendedSeconds: 60
        )
        #expect(score == 0)
    }
}

struct PostureScorerTests {

    @Test func scoresPerfectPostureHighly() {
        let metrics = PostureMetrics(
            faceDetectedRatio: 1,
            gazeTowardCameraRatio: 1,
            postureStabilityScore: 1
        )
        #expect(PostureScorer.score(metrics: metrics) == 100)
    }

    @Test func scoresMissingFaceLow() {
        #expect(PostureScorer.score(metrics: .empty) == 0)
    }
}

struct SessionScoringEngineTests {

    @Test func summarizesQuestionScores() {
        let record = QuestionRecord(
            orderIndex: 0,
            category: .documentBased,
            questionText: "질문",
            speechScore: 80,
            contentScore: 90,
            postureScore: 70
        )

        let summary = SessionScoringEngine.summarize(questions: [record])
        #expect(summary != nil)
        #expect(summary?.speechScore == 80)
        #expect(summary?.contentScore == 90)
        #expect(summary?.postureScore == 70)
        #expect(summary?.overallScore == 83)
        #expect(summary?.overallGrade == .a)
    }

    @Test func appliesScoresToSession() {
        let session = InterviewSession()
        let record = QuestionRecord(
            orderIndex: 0,
            category: .selfIntro,
            questionText: "자기소개",
            speechScore: 60,
            contentScore: 80,
            postureScore: 40
        )
        let metrics = PostureMetrics(faceDetectedRatio: 0.5, gazeTowardCameraRatio: 0.4, postureStabilityScore: 0.3)

        SessionScoringEngine.applyQuestionScores(
            to: record,
            speechScore: 60,
            contentScore: 80,
            postureScore: 40,
            metrics: metrics
        )

        #expect(record.speechScore == 60)
        #expect(record.gazeTowardCameraRatio == 0.4)

        if let summary = SessionScoringEngine.summarize(questions: [record]) {
            SessionScoringEngine.applySessionScores(to: session, summary: summary)
            #expect(session.overallScore == summary.overallScore)
            #expect(session.overallGrade == summary.overallGrade)
        }
    }
}

struct ProgressChartDataBuilderTests {

    @Test func filtersSessionsWithoutScores() {
        let profile = CandidateProfile(company: "LG", role: "iOS")
        let scored = InterviewSession(overallScore: 80, overallGrade: .a, sessionIndex: 1)
        let unscored = InterviewSession(sessionIndex: 2)
        profile.sessions = [scored, unscored]

        let points = ProgressChartDataBuilder.scoredSessions(from: profile)
        #expect(points.count == 1)
        #expect(points.first?.overallScore == 80)
    }
}

struct KeywordCoverageTrackerTests {

    @Test func calculatesCoverageFromTranscript() {
        let coverage = KeywordCoverageTracker.coverage(
            keywords: ["협업", "성과", "개선"],
            transcript: "팀과 협업하여 성과를 냈습니다"
        )
        #expect(coverage > 0.6)
    }

    @Test func listsUncoveredKeywords() {
        let missing = KeywordCoverageTracker.uncoveredKeywords(
            keywords: ["협업", "성과"],
            transcript: "협업 경험을 말했습니다"
        )
        #expect(missing == ["성과"])
    }
}

struct SessionPhaseTests {

    @Test func identifiesAnsweringPhases() {
        #expect(SessionPhase.selfIntro.isAnsweringPhase)
        #expect(SessionPhase.answering.isAnsweringPhase)
        #expect(SessionPhase.closing.isAnsweringPhase)
        #expect(!SessionPhase.questionTTS.isAnsweringPhase)
    }
}
