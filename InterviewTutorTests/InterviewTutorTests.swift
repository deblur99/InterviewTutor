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

struct QuestionFlowViewModelTests {

    @Test func buildsExpectedDurationFromQuestions() {
        let flow = QuestionFlowViewModel()
        flow.setQuestions([
            GeneratedQuestion(id: UUID(), questionText: "A", promptKeywords: "", recommendedSeconds: 60),
            GeneratedQuestion(id: UUID(), questionText: "B", promptKeywords: "", recommendedSeconds: 45),
            GeneratedQuestion(id: UUID(), questionText: "C", promptKeywords: "", recommendedSeconds: 60),
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
            GeneratedQuestion(id: UUID(), questionText: "A", promptKeywords: "", recommendedSeconds: 60),
            GeneratedQuestion(id: UUID(), questionText: "B", promptKeywords: "", recommendedSeconds: 45),
            GeneratedQuestion(id: UUID(), questionText: "C", promptKeywords: "", recommendedSeconds: 60),
        ])

        #expect(flow.category(for: 0) == .selfIntro)
        #expect(flow.category(for: 1) == .documentBased)
        #expect(flow.category(for: 2) == .closing)
    }
}
