import Foundation

struct InterviewPrepTip: Equatable {
    let daysRemaining: Int
    let title: String
    let items: [String]
    let notificationMessage: String
}

enum InterviewPrepGuide {
    static func tip(for daysRemaining: Int) -> InterviewPrepTip? {
        tips[daysRemaining]
    }

    static let dDayEncouragement = "오늘은 면접 날입니다. 그동안 연습한 호흡 그대로, 자신 있게 임하세요!"

    private static let tips: [Int: InterviewPrepTip] = [
        7: InterviewPrepTip(
            daysRemaining: 7,
            title: "D-7 · 전체 점검",
            items: [
                "이력서·채용공고 핵심 키워드를 다시 정리하세요.",
                "자기소개 1분 버전을 소리 내어 말해 보세요.",
                "갓 연습 세션으로 서류 기반 질문에 익숙해지세요.",
            ],
            notificationMessage: "면접 일주일 전입니다. 자기소개와 서류 핵심 키워드를 오늘 정리해 보세요."
        ),
        6: InterviewPrepTip(
            daysRemaining: 6,
            title: "D-6 · 답변 구조 연습",
            items: [
                "STAR(상황-과제-행동-결과) 구조로 경험 2개를 정리하세요.",
                "인성·상황 질문 1회 연습해 보세요.",
                "답변 시간을 지키며 말하는 연습을 하세요.",
            ],
            notificationMessage: "D-6, 오늘은 STAR 구조로 대표 경험 하나를 끝까지 말해 보는 날입니다."
        ),
        5: InterviewPrepTip(
            daysRemaining: 5,
            title: "D-5 · 회사·직무 맞춤",
            items: [
                "지원 회사·직무와 연결되는 본인 강점을 3가지 적어 보세요.",
                "회사 관련 질문에 답할 회사 조사 메모를 확인하세요.",
                "숙련 단계 세션으로 꼬리질문에 대비하세요.",
            ],
            notificationMessage: "D-5, 회사와 직무에 맞는 본인 강점 3가지를 오늘 정리해 보세요."
        ),
        4: InterviewPrepTip(
            daysRemaining: 4,
            title: "D-4 · 약점 보완",
            items: [
                "이전 모의면접 피드백에서 반복된 약점을 확인하세요.",
                "취약 항목은 자유 연습으로 집중 훈련하세요.",
                "필러 워드 없이 핵심만 말하는 연습을 하세요.",
            ],
            notificationMessage: "D-4, 지난 연습 피드백의 약점 한 가지를 오늘 보완해 보세요."
        ),
        3: InterviewPrepTip(
            daysRemaining: 3,
            title: "D-3 · 실전 리허설",
            items: [
                "전문 단계 또는 긴 세션으로 실전 흐름을 경험하세요.",
                "카메라·마이크·조명 환경을 면접 당일과 같이 맞춰 보세요.",
                "역질문 2개를 준비하세요.",
            ],
            notificationMessage: "D-3, 오늘은 실전처럼 긴 세션 한 번으로 호흡을 점검해 보세요."
        ),
        2: InterviewPrepTip(
            daysRemaining: 2,
            title: "D-2 · 마무리 점검",
            items: [
                "자기소개·마무리 발언·역질문을 최종 확인하세요.",
                "면접 복장과 접속 환경(화상 시)을 점검하세요.",
                "충분한 수면을 위해 오늘 일정을 가볍게 잡으세요.",
            ],
            notificationMessage: "D-2, 자기소개와 역질문을 최종 점검하고 일찍 쉬어 체력을 아끼세요."
        ),
        1: InterviewPrepTip(
            daysRemaining: 1,
            title: "D-1 · 최종 리허설",
            items: [
                "가벼운 자유 연습 1~2문항으로 입만 풀어 주세요.",
                "이력서·공고 출력본 또는 메모를 손닿는 곳에 두세요.",
                "내일 면접 시간에 맞춰 기상·준비 루틴을 점검하세요.",
            ],
            notificationMessage: "내일이 면접입니다. 가볍게 1회만 연습하고, 일찍 쉬며 컨디션을 올려 두세요."
        ),
    ]
}
