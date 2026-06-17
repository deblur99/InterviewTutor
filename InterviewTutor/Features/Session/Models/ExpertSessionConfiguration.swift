import Foundation

struct ExpertSessionConfiguration: Codable, Equatable, Sendable {
    var documentQuestionCount: Int
    var behavioralQuestionCount: Int
    var companyQuestionCount: Int
    var technicalQuestionCount: Int
    var pressureQuestionCount: Int
    var comprehensiveQuestionCount: Int
    var focusWeakAreas: Bool
    var interviewerTone: InterviewerTone
    var timePressureMultiplier: Double

    static let `default` = ExpertSessionConfiguration(
        documentQuestionCount: 5,
        behavioralQuestionCount: 2,
        companyQuestionCount: 2,
        technicalQuestionCount: 2,
        pressureQuestionCount: 2,
        comprehensiveQuestionCount: 1,
        focusWeakAreas: false,
        interviewerTone: .neutral,
        timePressureMultiplier: 0.85
    )

    var generatesFollowUps: Bool { true }

    var totalCoreQuestions: Int {
        documentQuestionCount + behavioralQuestionCount + companyQuestionCount
            + technicalQuestionCount + pressureQuestionCount + comprehensiveQuestionCount
    }

    var sessionSummaryLabel: String {
        var parts = ["자기소개 → 서류 \(documentQuestionCount)"]
        if generatesFollowUps { parts[0] += " + 꼬리질문" }
        if technicalQuestionCount > 0 { parts.append("기술 \(technicalQuestionCount)") }
        if behavioralQuestionCount > 0 { parts.append("인성 \(behavioralQuestionCount)") }
        if companyQuestionCount > 0 { parts.append("회사 \(companyQuestionCount)") }
        if pressureQuestionCount > 0 { parts.append("압박 \(pressureQuestionCount)") }
        if comprehensiveQuestionCount > 0 { parts.append("종합 \(comprehensiveQuestionCount)") }
        parts.append("마무리")
        if focusWeakAreas { parts.append("(약점 집중)") }
        return parts.joined(separator: " → ")
    }

    func adjustedSeconds(_ base: Int, category: QuestionCategory) -> Int {
        var seconds = Double(base) * timePressureMultiplier
        if category == .pressure {
            seconds *= 0.75
        }
        return max(20, Int(seconds.rounded()))
    }

    func biased(for weakCategories: [QuestionCategory]) -> ExpertSessionConfiguration {
        guard focusWeakAreas, !weakCategories.isEmpty else { return self }

        var adjusted = self
        let boostable = weakCategories.filter { $0 != .documentBased && $0 != .selfIntro && $0 != .closing && $0 != .followUp }
        guard !boostable.isEmpty else { return self }

        for category in boostable.prefix(3) {
            guard adjusted.documentQuestionCount > 2 else { break }
            switch category {
            case .behavioral:
                adjusted.behavioralQuestionCount += 1
            case .companyFit:
                adjusted.companyQuestionCount += 1
            case .technical:
                adjusted.technicalQuestionCount += 1
            case .pressure:
                adjusted.pressureQuestionCount += 1
            case .comprehensive:
                adjusted.comprehensiveQuestionCount += 1
            default:
                continue
            }
            adjusted.documentQuestionCount -= 1
        }

        return adjusted
    }

    var preparationToken: String {
        [
            String(documentQuestionCount),
            String(behavioralQuestionCount),
            String(companyQuestionCount),
            String(technicalQuestionCount),
            String(pressureQuestionCount),
            String(comprehensiveQuestionCount),
            focusWeakAreas ? "1" : "0",
            interviewerTone.rawValue,
            String(format: "%.2f", timePressureMultiplier),
        ]
        .joined(separator: "|")
    }

    /// 질문 목록 재생성이 필요한 설정만 포함 (톤·시간 압박 제외)
    var questionGenerationToken: String {
        [
            String(documentQuestionCount),
            String(behavioralQuestionCount),
            String(companyQuestionCount),
            String(technicalQuestionCount),
            String(pressureQuestionCount),
            String(comprehensiveQuestionCount),
            focusWeakAreas ? "1" : "0",
        ]
        .joined(separator: "|")
    }
}
