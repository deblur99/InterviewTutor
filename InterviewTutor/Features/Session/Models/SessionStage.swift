import Foundation

enum SessionStage: String, Codable, CaseIterable, Identifiable {
    case beginner
    case skilled
    case expert
    case freePractice

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: "갓 연습"
        case .skilled: "익숙해지기"
        case .expert: "실전 연습"
        case .freePractice: "자유 연습"
        }
    }

    var description: String {
        switch self {
        case .beginner: "서류 기반 질문 + 예상 답변 프롬프트"
        case .skilled: "꼬리질문, 인성, 회사 관련 질문"
        case .expert: "모든 범위의 질문 · 옵션 선택 후 질문 생성"
        case .freePractice: "원하는 항목만 골라 집중 연습"
        }
    }

    var isAvailableInMVP: Bool {
        isAvailable
    }

    var isAvailable: Bool {
        switch self {
        case .beginner, .skilled, .expert: true
        case .freePractice: false
        }
    }

    var isStructuredStage: Bool {
        self != .freePractice
    }

    var preset: SessionStagePreset {
        SessionStagePreset.preset(for: self)
    }

    var showsFullPrompter: Bool {
        self == .beginner
    }

    var coachEnabledByDefault: Bool {
        self == .beginner
    }

    var coachHUDEnabledByDefault: Bool {
        self == .beginner
    }
}
