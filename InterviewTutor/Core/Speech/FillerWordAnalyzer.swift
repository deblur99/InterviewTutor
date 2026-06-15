import Foundation

enum FillerWordAnalyzer {
    static let defaultFillerWords = ["어", "음", "그러니까", "사실", "뭐랄까", "좀", "그", "약간", "막"]

    static func analyze(_ text: String, fillers: [String] = defaultFillerWords) -> FillerWordReport {
        var breakdown: [String: Int] = [:]
        let tokens = text
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)

        for token in tokens {
            let normalized = token.trimmingCharacters(in: .punctuationCharacters)
            if fillers.contains(normalized) {
                breakdown[normalized, default: 0] += 1
            }
        }

        let total = breakdown.values.reduce(0, +)
        return FillerWordReport(totalCount: total, breakdown: breakdown)
    }
}
