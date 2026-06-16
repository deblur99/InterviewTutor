import Foundation

enum ProfileDocumentText {
    private static let coverLetterPlaceholders: Set<String> = [
        "(내용 없음)",
        "내용 없음",
        "해당 없음",
        "해당사항 없음",
        "없음",
        "-",
        "n/a",
        "na",
        "null",
    ]

    static func meaningfulCoverLetter(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if coverLetterPlaceholders.contains(trimmed.lowercased()) { return nil }
        return trimmed
    }
}

enum InterviewQuestionValidator {
    private static let questionMarkers = [
        "?", "？",
        "주세요", "주실까요", "주시겠",
        "습니까", "인가요", "하셨나요", "하셨는지",
        "말씀해", "설명해", "소개해", "알려", "공유해", "이야기해",
        "어떻게", "왜 ", "무엇을", "어떤 ", "어느 ",
    ]

    static func isValidQuestionText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (12...220).contains(trimmed.count) else { return false }
        return questionMarkers.contains(where: trimmed.contains)
    }
}

enum ResumeTopicExtractor {
    static func topics(from resumeText: String, limit: Int) -> [String] {
        let lines = resumeText
            .components(separatedBy: .newlines)
            .flatMap(splitBullets(in:))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-•*·\t ")) }
            .filter { (12...100).contains($0.count) }
            .filter { !looksLikeMetadata($0) }

        var seen = Set<String>()
        var topics: [String] = []
        for line in lines {
            let key = line.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            topics.append(line)
            if topics.count >= limit { break }
        }
        return topics
    }

    static func question(from topic: String) -> String {
        let clipped = String(topic.prefix(72))
        return "이력서의 「\(clipped)」 경험에 대해 본인의 역할과 성과를 구체적으로 설명해 주세요."
    }

    private static func splitBullets(in line: String) -> [String] {
        let separators = [" · ", " | ", " / "]
        for separator in separators where line.contains(separator) {
            return line.components(separatedBy: separator)
        }
        if line.contains("·") {
            return line.components(separatedBy: "·")
        }
        return [line]
    }

    private static func looksLikeMetadata(_ line: String) -> Bool {
        let lowered = line.lowercased()
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") { return true }
        if line.range(of: #"^\d{4}[\./-]"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"^\d+%$"#, options: .regularExpression) != nil { return true }
        if ["학력", "경력", "프로젝트", "기술스택", "자격증"].contains(where: line.hasPrefix) { return true }
        return false
    }
}
