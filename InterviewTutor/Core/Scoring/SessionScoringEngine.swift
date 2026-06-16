import Foundation

struct SessionScoreSummary: Equatable {
    let speechScore: Int
    let contentScore: Int
    let postureScore: Int
    let overallScore: Int
    let overallGrade: LetterGrade
}

enum SessionScoringEngine {
    static let contentWeight = 0.50
    static let speechWeight = 0.30
    static let postureWeight = 0.20

    static func applyQuestionScores(
        to record: QuestionRecord,
        speechScore: Int,
        contentScore: Int,
        postureScore: Int,
        metrics: PostureMetrics
    ) {
        record.speechScore = speechScore
        record.contentScore = contentScore
        record.postureScore = postureScore
        record.gazeTowardCameraRatio = metrics.gazeTowardCameraRatio
        record.faceDetectedRatio = metrics.faceDetectedRatio
        record.postureStabilityScore = metrics.postureStabilityScore
    }

    static func summarize(questions: [QuestionRecord]) -> SessionScoreSummary? {
        let scored = questions.filter {
            $0.speechScore != nil && $0.contentScore != nil && $0.postureScore != nil
        }
        guard !scored.isEmpty else { return nil }

        let speech = average(scored.compactMap(\.speechScore))
        let content = average(scored.compactMap(\.contentScore))
        let posture = average(scored.compactMap(\.postureScore))
        let overall = Int(
            (Double(content) * contentWeight
                + Double(speech) * speechWeight
                + Double(posture) * postureWeight)
                .rounded()
        )

        return SessionScoreSummary(
            speechScore: speech,
            contentScore: content,
            postureScore: posture,
            overallScore: overall,
            overallGrade: LetterGrade(score: overall)
        )
    }

    static func applySessionScores(to session: InterviewSession, summary: SessionScoreSummary) {
        session.speechScore = summary.speechScore
        session.contentScore = summary.contentScore
        session.postureScore = summary.postureScore
        session.overallScore = summary.overallScore
        session.overallGrade = summary.overallGrade
    }

    private static func average(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let sum = values.reduce(0, +)
        return Int((Double(sum) / Double(values.count)).rounded())
    }
}
