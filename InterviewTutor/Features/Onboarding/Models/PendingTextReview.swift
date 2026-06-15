import Foundation

enum OnboardingTextField: String, Identifiable {
    case jobDescription
    case resume
    case coverLetter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jobDescription: "채용공고"
        case .resume: "이력서"
        case .coverLetter: "자기소개서"
        }
    }
}

struct PendingTextReview: Identifiable {
    let id = UUID()
    let field: OnboardingTextField
    var extractedText: String
    let usedOCR: Bool
    let sourceDescription: String
    let hadExistingContent: Bool
}
