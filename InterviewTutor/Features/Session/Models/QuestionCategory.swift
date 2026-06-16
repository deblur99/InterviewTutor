import Foundation

enum QuestionCategory: String, Codable, CaseIterable, Identifiable {
    case selfIntro
    case documentBased
    case followUp
    case behavioral
    case companyFit
    case technical
    case pressure
    case comprehensive
    case reverseQuestion
    case closing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .selfIntro: "자기소개"
        case .documentBased: "서류 기반"
        case .followUp: "꼬리질문"
        case .behavioral: "인성·상황"
        case .companyFit: "회사·직무"
        case .technical: "기술·실무"
        case .pressure: "압박"
        case .comprehensive: "종합"
        case .reverseQuestion: "역질문"
        case .closing: "마무리"
        }
    }

    /// 풀 생성·약점 분석에 사용하는 카테고리
    static var poolCategories: [QuestionCategory] {
        [.documentBased, .behavioral, .companyFit, .technical, .pressure, .comprehensive]
    }
}
