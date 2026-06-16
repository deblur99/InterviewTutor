import Foundation

enum CoachHintKind: String, CaseIterable, Sendable {
    case silence
    case gaze
    case filler
    case keywords

    var message: String {
        switch self {
        case .silence:
            "잠시 멈추고 핵심부터 말해 보세요."
        case .gaze:
            "카메라를 바라보며 답변해 보세요."
        case .filler:
            "필러가 길어지고 있어요. 잠깐 멈추고 다음 문장을 생각해 보세요."
        case .keywords:
            "아직 말하지 않은 키워드가 있어요. 프롬프터를 참고해 보세요."
        }
    }

    var icon: String {
        switch self {
        case .silence: "mic.slash"
        case .gaze: "eye.slash"
        case .filler: "text.word.spacing"
        case .keywords: "lightbulb"
        }
    }
}

struct CoachHint: Equatable, Sendable {
    let kind: CoachHintKind
    let message: String

    init(kind: CoachHintKind) {
        self.kind = kind
        self.message = kind.message
    }
}

enum KeywordCoverageTracker {
    static func coverage(keywords: [String], transcript: String) -> Double {
        let cleaned = keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return 1 }

        let lowered = transcript.lowercased()
        let matched = cleaned.filter { lowered.contains($0) }.count
        return Double(matched) / Double(cleaned.count)
    }

    static func uncoveredKeywords(keywords: [String], transcript: String) -> [String] {
        let lowered = transcript.lowercased()
        return keywords.filter { keyword in
            let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !normalized.isEmpty && !lowered.contains(normalized)
        }
    }
}
