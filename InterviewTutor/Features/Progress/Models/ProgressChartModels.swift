import Charts
import Foundation

enum ProgressChartAxisMode: String, CaseIterable, Identifiable {
    case date = "날짜"
    case sessionIndex = "회차"

    var id: String { rawValue }
}

enum ScoreSeries: String, CaseIterable, Identifiable {
    case overall = "종합"
    case speech = "발화"
    case content = "내용"
    case posture = "자세"

    var id: String { rawValue }

    var colorName: String {
        switch self {
        case .overall: "purple"
        case .speech: "blue"
        case .content: "green"
        case .posture: "teal"
        }
    }
}

struct SessionScorePoint: Identifiable {
    let id: UUID
    let date: Date
    let sessionIndex: Int
    let overallScore: Int
    let speechScore: Int
    let contentScore: Int
    let postureScore: Int
    let grade: LetterGrade

    init(session: InterviewSession) {
        id = UUID()
        date = session.date
        sessionIndex = session.sessionIndex ?? 0
        overallScore = session.overallScore ?? 0
        speechScore = session.speechScore ?? 0
        contentScore = session.contentScore ?? 0
        postureScore = session.postureScore ?? 0
        grade = session.overallGrade ?? .f
    }

    func value(for series: ScoreSeries) -> Int {
        switch series {
        case .overall: overallScore
        case .speech: speechScore
        case .content: contentScore
        case .posture: postureScore
        }
    }

    var xLabelDate: String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}

enum ProgressChartDataBuilder {
    static func scoredSessions(from profile: CandidateProfile) -> [SessionScorePoint] {
        profile.sessions
            .filter { $0.overallScore != nil }
            .sorted { lhs, rhs in
                let leftIndex = lhs.sessionIndex ?? Int.max
                let rightIndex = rhs.sessionIndex ?? Int.max
                if leftIndex != rightIndex { return leftIndex < rightIndex }
                return lhs.date < rhs.date
            }
            .map(SessionScorePoint.init)
    }

    static func bestGrade(in points: [SessionScorePoint]) -> LetterGrade? {
        guard !points.isEmpty else { return nil }
        return points.map(\.grade).max { lhs, rhs in
            gradeRank(lhs) < gradeRank(rhs)
        }
    }

    private static func gradeRank(_ grade: LetterGrade) -> Int {
        switch grade {
        case .s: 6
        case .a: 5
        case .b: 4
        case .c: 3
        case .d: 2
        case .f: 1
        }
    }
}
