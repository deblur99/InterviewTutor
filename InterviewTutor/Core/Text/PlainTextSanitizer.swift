import Foundation

enum PlainTextSanitizer {
    /// 말하기용 프롬프터·추천 답변에서 마크다운 강조 문법을 제거합니다.
    static func strippingMarkdownEmphasis(_ text: String) -> String {
        var result = text

        let patterns: [(String, String)] = [
            (#"\*\*(.+?)\*\*"#, "$1"),
            (#"__(.+?)__"#, "$1"),
            (#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, "$1"),
            (#"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#, "$1"),
            (#"`(.+?)`"#, "$1"),
            (#"~~(.+?)~~"#, "$1"),
            (#"\[(.+?)\]\([^)]*\)"#, "$1"),
        ]

        for (pattern, template) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: template
            )
        }

        return result
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "~~", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
