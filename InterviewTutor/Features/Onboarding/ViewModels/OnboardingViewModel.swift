import Foundation
import SwiftData
import UniformTypeIdentifiers

@Observable
final class OnboardingViewModel {
    var company = ""
    var industry = ""
    var role = ""
    var jobDescription = ""
    var resumeText = ""
    var coverLetterText = ""
    var currentStep = 0

    var isImporting = false
    var importingFileCount = 0
    var importErrorMessage: String?
    var pendingReview: PendingTextReview?
    var reviewDraftText = ""
    var reviewTextBeforeRefinement: String?
    var isRefiningReviewText = false
    var refinementWarningMessage: String?
    var activeImportField: OnboardingTextField?

    static let supportedContentTypes: [UTType] = [.pdf, .png, .jpeg, .heic]

    private let existingProfile: CandidateProfile?
    private let textExtractor = DocumentTextExtractor()
    private let textRefiner = DocumentTextRefiner()

    var isEditingExistingProfile: Bool { existingProfile != nil }

    init(profile: CandidateProfile? = nil) {
        self.existingProfile = profile
        if let profile {
            company = profile.company
            industry = profile.industry
            role = profile.role
            jobDescription = profile.jobDescription
            resumeText = profile.resumeText
            coverLetterText = profile.coverLetterText
        }
    }

    static let steps = ["회사 정보", "채용공고", "이력서", "자기소개서"]

    var isLastStep: Bool {
        currentStep == Self.steps.count - 1
    }

    func canProceedFromCurrentStep() -> Bool {
        switch currentStep {
        case 0:
            !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !industry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1:
            !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2:
            !resumeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 3:
            !coverLetterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            false
        }
    }

    func beginImport(for field: OnboardingTextField) {
        activeImportField = field
        importErrorMessage = nil
    }

    func importDocuments(from urls: [URL]) async {
        guard let field = activeImportField else { return }

        isImporting = true
        importingFileCount = urls.count
        importErrorMessage = nil
        defer {
            isImporting = false
            importingFileCount = 0
            activeImportField = nil
        }

        do {
            let result = try await textExtractor.extract(from: urls)
            pendingReview = PendingTextReview(
                field: field,
                extractedText: result.text,
                usedOCR: result.usedOCR,
                sourceDescription: result.sourceDescription,
                hadExistingContent: !text(for: field).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            reviewDraftText = result.text
            reviewTextBeforeRefinement = nil
            refinementWarningMessage = nil
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    func importDocument(from url: URL) async {
        await importDocuments(from: [url])
    }

    func refineReviewDraftText() async {
        guard let review = pendingReview else { return }
        guard !reviewDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isRefiningReviewText = true
        refinementWarningMessage = nil
        defer { isRefiningReviewText = false }

        reviewTextBeforeRefinement = reviewDraftText
        let result = await textRefiner.refine(reviewDraftText, for: review.field)
        reviewDraftText = result.text
        refinementWarningMessage = result.warningMessage
    }

    func clearRefinementWarning() {
        refinementWarningMessage = nil
    }

    func undoReviewDraftRefinement() {
        guard let previous = reviewTextBeforeRefinement else { return }
        reviewDraftText = previous
        reviewTextBeforeRefinement = nil
    }

    var reviewDraftRemovedCharacterCount: Int? {
        guard let before = reviewTextBeforeRefinement else { return nil }
        let removed = before.count - reviewDraftText.count
        return removed > 0 ? removed : nil
    }

    func applyPendingReview() {
        guard let review = pendingReview else { return }
        setText(reviewDraftText, for: review.field)
        pendingReview = nil
        reviewDraftText = ""
        reviewTextBeforeRefinement = nil
        refinementWarningMessage = nil
    }

    func dismissPendingReview() {
        pendingReview = nil
        reviewDraftText = ""
        reviewTextBeforeRefinement = nil
        refinementWarningMessage = nil
    }

    func clearImportError() {
        importErrorMessage = nil
    }

    func text(for field: OnboardingTextField) -> String {
        switch field {
        case .jobDescription: jobDescription
        case .resume: resumeText
        case .coverLetter: coverLetterText
        }
    }

    func setText(_ text: String, for field: OnboardingTextField) {
        switch field {
        case .jobDescription: jobDescription = text
        case .resume: resumeText = text
        case .coverLetter: coverLetterText = text
        }
    }

    @discardableResult
    func save(context: ModelContext) -> CandidateProfile {
        let profile: CandidateProfile
        if let existingProfile {
            existingProfile.company = company
            existingProfile.industry = industry
            existingProfile.role = role
            existingProfile.jobDescription = jobDescription
            existingProfile.resumeText = resumeText
            existingProfile.coverLetterText = coverLetterText
            existingProfile.updatedAt = .now
            existingProfile.ensureProfileID()
            profile = existingProfile
        } else {
            let newProfile = CandidateProfile(
                profileID: UUID(),
                company: company,
                industry: industry,
                role: role,
                jobDescription: jobDescription,
                resumeText: resumeText,
                coverLetterText: coverLetterText
            )
            context.insert(newProfile)
            profile = newProfile
        }
        try? context.save()
        return profile
    }

    func resetForNewProfile() {
        company = ""
        industry = ""
        role = ""
        jobDescription = ""
        resumeText = ""
        coverLetterText = ""
        currentStep = 0
        dismissPendingReview()
        clearImportError()
    }
}
