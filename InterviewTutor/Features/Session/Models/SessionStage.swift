import Foundation

enum SessionStage: String, Codable, CaseIterable, Identifiable {
    case beginner
    case skilled
    case expert

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: "갓 연습"
        case .skilled: "숙련"
        case .expert: "전문"
        }
    }

    var description: String {
        switch self {
        case .beginner: "서류 기반 질문 + 예상 답변 프롬프트"
        case .skilled: "꼬리질문, 인성, 회사 관련 질문"
        case .expert: "모든 범위의 질문 (실전 모드)"
        }
    }

    var isAvailableInMVP: Bool {
        self == .beginner
    }
}
