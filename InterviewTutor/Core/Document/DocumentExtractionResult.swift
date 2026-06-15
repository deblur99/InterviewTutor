import Foundation

struct DocumentExtractionResult: Sendable {
    let text: String
    let usedOCR: Bool
    let sourceDescription: String
}

enum DocumentExtractionError: Error, LocalizedError {
    case unreadableFile
    case emptyContent
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .unreadableFile: "파일을 읽을 수 없습니다."
        case .emptyContent: "텍스트를 추출하지 못했습니다. 다른 파일을 시도하거나 직접 입력해 주세요."
        case .unsupportedFormat: "지원하지 않는 파일 형식입니다. PDF, PNG, JPEG, HEIC만 사용할 수 있습니다."
        }
    }
}

enum SupportedDocumentType: Sendable {
    case pdf
    case png
    case jpeg
    case heic

    init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "pdf": self = .pdf
        case "png": self = .png
        case "jpg", "jpeg": self = .jpeg
        case "heic": self = .heic
        default: return nil
        }
    }
}
