import AppKit
import Foundation
import PDFKit
import Vision

nonisolated final class DocumentTextExtractor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.interviewtutor.document.extraction")

    func extract(from url: URL) async throws -> DocumentExtractionResult {
        try await extract(from: [url])
    }

    func extract(from urls: [URL]) async throws -> DocumentExtractionResult {
        try Self.validateBatch(urls)

        var results: [DocumentExtractionResult] = []
        for url in urls {
            results.append(try await extractSingle(from: url))
        }
        return Self.merge(results)
    }

    static func validateBatch(_ urls: [URL]) throws {
        guard !urls.isEmpty else {
            throw DocumentExtractionError.emptyBatch
        }

        let pdfCount = urls.filter { SupportedDocumentType(fileExtension: $0.pathExtension) == .pdf }.count
        if pdfCount > 1 {
            throw DocumentExtractionError.multiplePDFsNotAllowed
        }
    }

    static func merge(_ results: [DocumentExtractionResult]) -> DocumentExtractionResult {
        guard let first = results.first else {
            return DocumentExtractionResult(text: "", usedOCR: false, sourceDescription: "")
        }
        guard results.count > 1 else { return first }

        let text = results
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")

        return DocumentExtractionResult(
            text: text,
            usedOCR: results.contains(where: \.usedOCR),
            sourceDescription: mergedSourceDescription(from: results)
        )
    }

    private func extractSingle(from url: URL) async throws -> DocumentExtractionResult {
        let fileExtension = url.pathExtension
        guard let documentType = SupportedDocumentType(fileExtension: fileExtension) else {
            throw DocumentExtractionError.unsupportedFormat
        }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        switch documentType {
        case .pdf:
            return try await extractFromPDF(url: url)
        case .png, .jpeg, .heic:
            return try await extractFromImage(url: url, type: documentType)
        }
    }

    private func extractFromPDF(url: URL) async throws -> DocumentExtractionResult {
        try await QueueConfined.run(on: queue) {
            guard let document = PDFDocument(url: url) else {
                throw DocumentExtractionError.unreadableFile
            }

            var embeddedText = ""
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index), let pageText = page.string else { continue }
                embeddedText.append(pageText)
                embeddedText.append("\n")
            }

            let trimmedEmbedded = embeddedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedEmbedded.count >= 20 {
                return DocumentExtractionResult(
                    text: trimmedEmbedded,
                    usedOCR: false,
                    sourceDescription: "PDF 텍스트"
                )
            }

            var ocrText = ""
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let pageImage = page.thumbnail(of: CGSize(width: 2_048, height: 2_048), for: .mediaBox)
                guard let cgImage = Self.cgImage(from: pageImage) else { continue }
                let pageOCR = try Self.recognizeText(in: cgImage)
                if !pageOCR.isEmpty {
                    ocrText.append(pageOCR)
                    ocrText.append("\n")
                }
            }

            let trimmedOCR = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedOCR.isEmpty else {
                throw DocumentExtractionError.emptyContent
            }

            return DocumentExtractionResult(
                text: trimmedOCR,
                usedOCR: true,
                sourceDescription: "PDF 이미지 인식"
            )
        }
    }

    private func extractFromImage(url: URL, type: SupportedDocumentType) async throws -> DocumentExtractionResult {
        try await QueueConfined.run(on: queue) {
            guard let cgImage = Self.loadImage(from: url) else {
                throw DocumentExtractionError.unreadableFile
            }

            let text = try Self.recognizeText(in: cgImage)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw DocumentExtractionError.emptyContent
            }

            return DocumentExtractionResult(
                text: trimmed,
                usedOCR: true,
                sourceDescription: Self.imageSourceLabel(for: type) + " 인식"
            )
        }
    }

    private static func recognizeText(in cgImage: CGImage) throws -> String {
        var recognizedLines: [String] = []
        var requestError: Error?

        let request = VNRecognizeTextRequest { request, error in
            if let error {
                requestError = error
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            recognizedLines = observations.compactMap { $0.topCandidates(1).first?.string }
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        if let requestError {
            throw requestError
        }

        return recognizedLines.joined(separator: "\n")
    }

    private static func loadImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func cgImage(from image: NSImage) -> CGImage? {
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    private static func imageSourceLabel(for type: SupportedDocumentType) -> String {
        switch type {
        case .png: "PNG 이미지"
        case .jpeg: "JPEG 이미지"
        case .heic: "HEIC 이미지"
        case .pdf: "PDF"
        }
    }

    private static func mergedSourceDescription(from results: [DocumentExtractionResult]) -> String {
        var pdfCount = 0
        var imageCount = 0

        for result in results {
            if result.sourceDescription.hasPrefix("PDF") {
                pdfCount += 1
            } else {
                imageCount += 1
            }
        }

        switch (pdfCount, imageCount) {
        case (1, 0):
            return results.first(where: { $0.sourceDescription.hasPrefix("PDF") })?.sourceDescription ?? "PDF"
        case (0, 1):
            return results[0].sourceDescription
        case (0, _) where imageCount > 1:
            return "이미지 \(imageCount)장 인식"
        case (1, _) where imageCount > 0:
            return "PDF + 이미지 \(imageCount)장"
        default:
            return "첨부 파일 \(results.count)개"
        }
    }
}