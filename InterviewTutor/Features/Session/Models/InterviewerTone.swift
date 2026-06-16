import Foundation

enum InterviewerTone: String, Codable, CaseIterable, Identifiable {
    case calm
    case neutral
    case challenging

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calm: "차분"
        case .neutral: "표준"
        case .challenging: "압박"
        }
    }

    var description: String {
        switch self {
        case .calm: "느린 속도, 여유 있는 답변 준비 시간"
        case .neutral: "일반 면접관 톤"
        case .challenging: "빠른 속도, 짧은 준비 시간"
        }
    }

    var speechRateMultiplier: Float {
        switch self {
        case .calm: 0.82
        case .neutral: 0.90
        case .challenging: 1.0
        }
    }

    var pitchMultiplier: Float {
        switch self {
        case .calm: 0.95
        case .neutral: 1.0
        case .challenging: 1.06
        }
    }

    var preAnswerPauseSeconds: TimeInterval {
        switch self {
        case .calm: 2.0
        case .neutral: 1.5
        case .challenging: 0.8
        }
    }
}
