import Foundation

enum PracticeTopic: String, Codable, CaseIterable, Identifiable, Hashable {
    case selfIntro
    case careerChangeReason
    case documentBased
    case companyFit
    case behavioral
    case reverseQuestion
    case closing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .selfIntro: "자기소개"
        case .careerChangeReason: "이직 사유"
        case .documentBased: "서류 관련"
        case .companyFit: "회사·직무"
        case .behavioral: "인성·상황"
        case .reverseQuestion: "역질문"
        case .closing: "마지막으로 할 말"
        }
    }

    var icon: String {
        switch self {
        case .selfIntro: "hand.wave"
        case .careerChangeReason: "arrow.triangle.2.circlepath"
        case .documentBased: "doc.text"
        case .companyFit: "building.2"
        case .behavioral: "person.2"
        case .reverseQuestion: "questionmark.bubble"
        case .closing: "text.bubble"
        }
    }

    var category: QuestionCategory {
        switch self {
        case .selfIntro: .selfIntro
        case .careerChangeReason: .behavioral
        case .documentBased: .documentBased
        case .companyFit: .companyFit
        case .behavioral: .behavioral
        case .reverseQuestion: .reverseQuestion
        case .closing: .closing
        }
    }

    /// AI 호출 없이 고정 템플릿으로 즉시 만들 수 있는 항목
    var usesPresetQuestions: Bool {
        switch self {
        case .documentBased, .behavioral, .companyFit:
            false
        case .selfIntro, .careerChangeReason, .reverseQuestion, .closing:
            true
        }
    }

    static var defaultSelection: Set<PracticeTopic> {
        [.documentBased, .behavioral]
    }

    /// Stable UI and round-robin order, independent of enum declaration order.
    static let practiceOrder: [PracticeTopic] = [
        .documentBased,
        .behavioral,
        .companyFit,
        .careerChangeReason,
        .selfIntro,
        .reverseQuestion,
        .closing,
    ]
}
