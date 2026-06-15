import Foundation

enum QuestionCategory: String, Codable, CaseIterable, Identifiable {
    case selfIntro
    case documentBased
    case closing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .selfIntro: "자기소개"
        case .documentBased: "서류 기반"
        case .closing: "마무리"
        }
    }
}
