import Foundation

struct ProfileSessionStats {
    let totalCount: Int
    let scoredCount: Int
    let latestSession: InterviewSession?
    let latestScore: Int?
    let latestGrade: LetterGrade?
    let bestGrade: LetterGrade?
    let recentSessions: [InterviewSession]

    static func make(from profile: CandidateProfile) -> ProfileSessionStats {
        let sorted = profile.sessions.sorted { $0.date > $1.date }
        let scoredPoints = ProgressChartDataBuilder.scoredSessions(from: profile)
        let latestScored = sorted.first { $0.overallScore != nil }

        return ProfileSessionStats(
            totalCount: sorted.count,
            scoredCount: scoredPoints.count,
            latestSession: sorted.first,
            latestScore: latestScored?.overallScore,
            latestGrade: latestScored?.overallGrade,
            bestGrade: ProgressChartDataBuilder.bestGrade(in: scoredPoints),
            recentSessions: Array(sorted.prefix(3))
        )
    }
}
