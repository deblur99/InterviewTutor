import SwiftUI

struct ExtractedTextReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let fieldTitle: String
    let usedOCR: Bool
    let sourceDescription: String
    let hadExistingContent: Bool
    @Binding var reviewedText: String
    let textBeforeRefinement: String?
    let removedCharacterCount: Int?
    let isRefining: Bool
    let warningMessage: String?
    let onRefine: () async -> Void
    let onUndoRefinement: () -> Void
    let onApply: () -> Void

    @State private var showOriginalText = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    guidanceBanner

                    if let textBeforeRefinement, removedCharacterCount != nil {
                        refinementResultBanner(originalText: textBeforeRefinement)
                    }

                    if let warningMessage {
                        refinementWarningBanner(message: warningMessage)
                    }

                    TextEditor(text: $reviewedText)
                        .font(.body)
                        .padding(8)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary, lineWidth: 1)
                        }
                        .frame(minHeight: 220, maxHeight: 320)
                        .disabled(isRefining)

                    footerBar
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("\(fieldTitle) 검토")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("적용") {
                        onApply()
                        dismiss()
                    }
                    .disabled(reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRefining)
                }
            }
            .frame(minWidth: 560, minHeight: 480)
        }
    }

    private var footerBar: some View {
        HStack(alignment: .center) {
            Button {
                Task { await onRefine() }
            } label: {
                Label("불필요한 부분 다듬기", systemImage: "sparkles.2")
            }
            .buttonStyle(.bordered)
            .disabled(isRefining || reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if isRefining {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 4)
            }

            Spacer()

            Text("\(reviewedText.count)자")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func refinementWarningBanner(message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func refinementResultBanner(originalText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("다듬기 완료", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)

                if let removedCharacterCount {
                    Text("\(removedCharacterCount)자 제거됨")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("되돌리기") {
                    onUndoRefinement()
                    showOriginalText = false
                }
                .font(.caption)
            }

            DisclosureGroup("변경 전 보기", isExpanded: $showOriginalText) {
                ScrollView {
                    Text(originalText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
                .padding(10)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
            .font(.caption)
        }
        .padding()
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var guidanceBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("추출된 내용을 확인해 주세요", systemImage: "doc.text.magnifyingglass")
                .font(.headline)

            Text("아래 텍스트는 \(sourceDescription) 결과입니다. 오타나 누락이 있으면 수정한 뒤 적용을 눌러 주세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if usedOCR {
                Label("이미지 인식 결과 — 일부 글자가 틀릴 수 있습니다.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if hadExistingContent {
                Label("적용하면 현재 입력 중인 내용이 아래 텍스트로 교체됩니다.", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ExtractedTextReviewSheet(
        fieldTitle: "이력서",
        usedOCR: true,
        sourceDescription: "PNG 이미지 인식",
        hadExistingContent: true,
        reviewedText: .constant("추출된 이력서 텍스트 예시입니다."),
        textBeforeRefinement: "추출된 이력서 텍스트 예시입니다. 페이지 1/3",
        removedCharacterCount: 12,
        isRefining: false,
        warningMessage: "일부 내용이 Apple Intelligence 안전 필터에 걸려 기본 정리로 대체되었습니다.",
        onRefine: {},
        onUndoRefinement: {},
        onApply: {}
    )
}
