import Foundation

struct DocumentRefinementResult: Sendable {
    let text: String
    let usedAI: Bool
    let warningMessage: String?
}

enum DocumentRefinementError: Error {
    case guardrailTriggered
    case contextTooLarge
}
