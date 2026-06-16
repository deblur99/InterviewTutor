import Foundation

enum QuestionCategory: String, Codable, CaseIterable, Identifiable {
    case selfIntro
    case documentBased
    case followUp
    case behavioral
    case companyFit
    case closing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .selfIntro: "자기소개"
        case .documentBased: "서류 기반"
        case .followUp: "꼬리질문"
        case .behavioral: "인성·상황"
        case .companyFit: "회사·직무"
        case .closing: "마무리"
        }
    }
}
