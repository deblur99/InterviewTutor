import SwiftUI

struct FreePracticeQuestionFeedbackSheet: View {
    let record: QuestionRecord
    let progressLabel: String
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("문항 피드백")
                        .font(.title2.bold())
                    Text(progressLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(record.category.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.12), in: Capsule())
            }

            QuestionScoreBadges(
                speechScore: record.speechScore,
                contentScore: record.contentScore,
                postureScore: record.postureScore
            )

            Group {
                Text("질문")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(record.questionText)
                    .font(.headline)
            }

            if !record.transcribedAnswer.isEmpty {
                Group {
                    Text("내 답변")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(record.transcribedAnswer)
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Group {
                Text("코치 피드백")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(record.aiFeedback)
                    .font(.body)
            }

            Spacer()

            Button("다음 문항") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding(28)
        .frame(minWidth: 480, minHeight: 420)
    }
}
