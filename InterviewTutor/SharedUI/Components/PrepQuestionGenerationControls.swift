import SwiftUI

struct PrepQuestionGenerationControls: View {
    let isLoading: Bool
    let needsRegeneration: Bool
    let canGenerate: Bool
    var hasPreparedQuestions: Bool = false
    let onGenerate: () -> Void
    let onCancel: () -> Void

    private var isGenerateEnabled: Bool {
        canGenerate && (needsRegeneration || !hasPreparedQuestions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                Text("질문을 생성하는 중입니다. 설정을 변경하려면 취소한 뒤 다시 진행해 주세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if needsRegeneration {
                Text("설정이 변경되었습니다. 질문을 다시 생성해 주세요.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer(minLength: 0)

                if isLoading {
                    Button("취소", role: .cancel, action: onCancel)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(action: onGenerate) {
                        Label("질문 생성", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isGenerateEnabled)
                }
            }
        }
    }
}
