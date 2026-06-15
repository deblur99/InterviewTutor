import Foundation
import FoundationModels

@MainActor
final class DocumentTextRefiner {
    private static let maxChunkLength = 2_000
    private static let maxTotalLength = 12_000

    private let defaultModel = SystemLanguageModel.default
    private lazy var transformationModel = SystemLanguageModel(
        guardrails: .permissiveContentTransformations
    )

    func refine(_ text: String, for field: OnboardingTextField) async -> DocumentRefinementResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return DocumentRefinementResult(text: text, usedAI: false, warningMessage: nil)
        }

        guard case .available = defaultModel.availability else {
            let fallback = fallbackRefine(trimmed, for: field)
            return DocumentRefinementResult(
                text: fallback,
                usedAI: false,
                warningMessage: combinedWarnings(
                    base: "Apple Intelligence를 사용할 수 없어 기본 정리만 적용했습니다.",
                    refinedText: fallback,
                    field: field
                )
            )
        }

        let input = String(trimmed.prefix(Self.maxTotalLength))
        let chunks = Self.chunks(of: input, maxLength: Self.maxChunkLength)

        var refinedChunks: [String] = []
        var aiChunkCount = 0
        var guardrailTriggered = false

        for chunk in chunks {
            switch await refineChunk(chunk, for: field) {
            case .success(let refined):
                refinedChunks.append(refined)
                aiChunkCount += 1
            case .guardrailFailure:
                guardrailTriggered = true
                refinedChunks.append(fallbackRefine(chunk, for: field))
            case .failure:
                refinedChunks.append(fallbackRefine(chunk, for: field))
            }
        }

        let merged = refinedChunks
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let finalText = merged.isEmpty ? fallbackRefine(input, for: field) : merged

        let baseWarning: String?
        if aiChunkCount == chunks.count {
            baseWarning = nil
        } else if guardrailTriggered {
            baseWarning = "일부 내용이 Apple Intelligence 안전 필터에 걸려 기본 정리로 대체되었습니다. 결과를 확인해 주세요."
        } else {
            baseWarning = aiChunkCount > 0
                ? "일부 구간은 기본 정리만 적용되었습니다."
                : "AI 다듬기에 실패해 기본 정리만 적용했습니다."
        }

        return DocumentRefinementResult(
            text: finalText,
            usedAI: aiChunkCount > 0,
            warningMessage: combinedWarnings(base: baseWarning, refinedText: finalText, field: field)
        )
    }

    private func combinedWarnings(
        base: String?,
        refinedText: String,
        field: OnboardingTextField
    ) -> String? {
        var messages: [String] = []
        if let base, !base.isEmpty { messages.append(base) }
        if field == .jobDescription,
           let sectionWarning = JobDescriptionSectionValidator.missingSectionsMessage(for: refinedText) {
            messages.append(sectionWarning)
        }
        return messages.isEmpty ? nil : messages.joined(separator: " ")
    }

    private enum ChunkRefinementResult {
        case success(String)
        case guardrailFailure
        case failure
    }

    private func refineChunk(_ text: String, for field: OnboardingTextField) async -> ChunkRefinementResult {
        do {
            let instructions = field == .jobDescription
                ? """
                지원 서류 전처리 편집자입니다. 채용공고에서 면접 질문 생성에 필요한 핵심 섹션을 보존합니다.
                \(JobDescriptionRequiredSection.preservationGuide)
                머리글, 바닥글, 페이지 번호, 쿠키 안내, OCR 잡문자만 제거합니다.
                """
                : """
                지원 서류 전처리 편집자입니다. 면접 질문 생성에 필요한 핵심 내용만 남깁니다.
                사실 관계, 수치, 고유명사, 직무/자격 요건은 유지하고 머리글, 바닥글, 페이지 번호, 잡문자만 제거합니다.
                """

            let session = LanguageModelSession(model: transformationModel, instructions: instructions)

            let prompt = field == .jobDescription
                ? jobDescriptionPrompt(for: text)
                : generalPrompt(field: field, text: text)

            let response = try await session.respond(to: prompt)
            let refined = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard refined.count >= 10 else { return .failure }
            return .success(refined)
        } catch {
            if Self.isGuardrailError(error) {
                return .guardrailFailure
            }
            return .failure
        }
    }

    private func jobDescriptionPrompt(for text: String) -> String {
        """
        아래 채용공고 텍스트를 면접 준비용으로 정리해 주세요.

        반드시 유지할 항목:
        - 채용공고 이름
        - 채용하는 회사
        - 모집단위
        - 근무지
        - 전공 요구
        - 지원 자격
        - 우대 사항
        - 직무 소개
        - 채용 절차

        위 항목의 제목과 본문은 삭제·요약·통합하지 마세요.
        페이지 번호, 반복 공백, OCR 잡문자, 쿠키/개인정보/저작권 안내만 제거하세요.
        편집된 본문만 출력하세요.

        [원문]
        \(text)
        """
    }

    private func generalPrompt(field: OnboardingTextField, text: String) -> String {
        """
        아래 \(field.title) 텍스트를 면접 준비용으로 정리해 주세요.
        불필요한 안내 문구, 페이지 번호, 반복 공백, OCR 잡문자만 제거하고 핵심 내용은 유지하세요.
        편집된 본문만 출력하세요.

        \(text)
        """
    }

    private static func isGuardrailError(_ error: Error) -> Bool {
        if case LanguageModelSession.GenerationError.guardrailViolation = error {
            return true
        }

        let description = String(describing: error).lowercased()
        return description.contains("guardrail")
            || description.contains("safety guardrails")
    }

    nonisolated static func chunks(of text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }

        var result: [String] = []
        var current = ""

        for paragraph in text.components(separatedBy: "\n\n") {
            let candidate = current.isEmpty ? paragraph : current + "\n\n" + paragraph
            if candidate.count > maxLength, !current.isEmpty {
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = paragraph
            } else if paragraph.count > maxLength {
                if !current.isEmpty {
                    result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                    current = ""
                }
                result.append(contentsOf: hardSplit(paragraph, maxLength: maxLength))
            } else {
                current = candidate
            }
        }

        if !current.isEmpty {
            result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return result.filter { !$0.isEmpty }
    }

    nonisolated private static func hardSplit(_ text: String, maxLength: Int) -> [String] {
        var chunks: [String] = []
        var start = text.startIndex

        while start < text.endIndex {
            let end = text.index(start, offsetBy: maxLength, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[start..<end]))
            start = end
        }

        return chunks
    }

    private func fallbackRefine(_ text: String, for field: OnboardingTextField) -> String {
        let pageNumberPattern = #"^\s*[\d\-–—|./\s]*\d+\s*/\s*\d+[\d\-–—|./\s]*$"#
        let urlOnlyPattern = #"^https?://\S+$"#

        return text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                guard !line.isEmpty else { return false }
                if field == .jobDescription, JobDescriptionSectionValidator.isRequiredSectionHeader(line) {
                    return true
                }
                if line.count <= 2 { return false }
                if line.range(of: pageNumberPattern, options: .regularExpression) != nil { return false }
                if line.range(of: urlOnlyPattern, options: .regularExpression) != nil { return false }
                if line.allSatisfy({ $0.isNumber || $0.isWhitespace || $0 == "-" || $0 == "|" || $0 == "." }) {
                    return false
                }
                if field == .jobDescription {
                    let lowered = line.lowercased()
                    let boilerplate = ["cookie", "copyright", "all rights reserved", "개인정보처리방침", "이용약관"]
                    if boilerplate.contains(where: { lowered.contains($0) }) { return false }
                }
                return true
            }
            .joined(separator: "\n")
    }
}
