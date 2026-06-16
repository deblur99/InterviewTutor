import Foundation

enum WeakTopicAnalyzer {
    private static let weakScoreThreshold = 65
    private static let minimumAnswersPerCategory = 2

    static func weakCategories(from profile: CandidateProfile) -> [QuestionCategory] {
        let scorableCategories: Set<QuestionCategory> = [
            .documentBased, .behavioral, .companyFit, .technical, .pressure, .comprehensive,
        ]

        var totals: [QuestionCategory: (sum: Int, count: Int)] = [:]

        for session in profile.sessions {
            for question in session.questions {
                guard scorableCategories.contains(question.category),
                      let score = question.contentScore else { continue }
                var entry = totals[question.category, default: (0, 0)]
                entry.sum += score
                entry.count += 1
                totals[question.category] = entry
            }
        }

        return totals
            .filter { $0.value.count >= minimumAnswersPerCategory }
            .filter { Double($0.value.sum) / Double($0.value.count) < Double(weakScoreThreshold) }
            .sorted { lhs, rhs in
                let lhsAvg = Double(lhs.value.sum) / Double(lhs.value.count)
                let rhsAvg = Double(rhs.value.sum) / Double(rhs.value.count)
                return lhsAvg < rhsAvg
            }
            .map(\.key)
    }

    static func weaknessSummary(from profile: CandidateProfile) -> String? {
        let weak = weakCategories(from: profile)
        guard !weak.isEmpty else { return nil }
        return weak.map(\.displayName).joined(separator: ", ")
    }
}
