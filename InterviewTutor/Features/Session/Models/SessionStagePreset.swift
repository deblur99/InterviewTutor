import Foundation

struct SessionStagePreset: Equatable {
    let documentQuestionCount: Int
    let behavioralQuestionCount: Int
    let companyQuestionCount: Int
    let generatesFollowUps: Bool
    let followUpRecommendedSeconds: Int
    let poolTargetSize: Int

    static func preset(for stage: SessionStage) -> SessionStagePreset {
        switch stage {
        case .beginner:
            SessionStagePreset(
                documentQuestionCount: 5,
                behavioralQuestionCount: 0,
                companyQuestionCount: 0,
                generatesFollowUps: false,
                followUpRecommendedSeconds: 0,
                poolTargetSize: 8
            )
        case .skilled:
            SessionStagePreset(
                documentQuestionCount: 3,
                behavioralQuestionCount: 2,
                companyQuestionCount: 1,
                generatesFollowUps: true,
                followUpRecommendedSeconds: 30,
                poolTargetSize: 10
            )
        case .expert:
            SessionStagePreset(
                documentQuestionCount: 5,
                behavioralQuestionCount: 2,
                companyQuestionCount: 2,
                generatesFollowUps: true,
                followUpRecommendedSeconds: 30,
                poolTargetSize: 12
            )
        }
    }

    var sessionSummaryLabel: String {
        switch (behavioralQuestionCount, companyQuestionCount, generatesFollowUps) {
        case (0, 0, _):
            "자기소개 → 서류 기반 \(documentQuestionCount)문항 → 마무리"
        case (_, _, true):
            "자기소개 → 서류 \(documentQuestionCount) + 꼬리질문 → 인성 \(behavioralQuestionCount) → 회사 \(companyQuestionCount) → 마무리"
        default:
            "자기소개 → 서류 \(documentQuestionCount) → 인성 \(behavioralQuestionCount) → 회사 \(companyQuestionCount) → 마무리"
        }
    }
}
