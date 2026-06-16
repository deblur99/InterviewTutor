import SwiftUI

struct PostSessionView: View {
    let session: InterviewSession
    let onDone: () -> Void

    private var totalFillerWords: Int {
        session.questions.reduce(0) { $0 + $1.fillerWordCount }
    }

    private var totalDuration: TimeInterval {
        guard let last = session.sortedQuestions.last else { return 0 }
        return last.endTimestamp
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let summary = session.summaryFeedback, !summary.isEmpty {
                    summaryFeedbackSection(summary)
                }
                scorePanel
                summaryCards
                questionFeedbacks
                doneButton
            }
            .padding(32)
        }
        .navigationTitle("세션 피드백")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StageBadgeView(stage: session.stage)
                Text(session.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("수고하셨습니다!")
                .font(.largeTitle.bold())
        }
    }

    private func summaryFeedbackSection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("종합 피드백")
                .font(.title3.bold())
            Text(summary)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var scorePanel: some View {
        Group {
            if let overall = session.overallScore,
               let grade = session.overallGrade,
               let speech = session.speechScore,
               let content = session.contentScore,
               let posture = session.postureScore {
                ScoreSummaryPanel(
                    overallScore: overall,
                    grade: grade,
                    speechScore: speech,
                    contentScore: content,
                    postureScore: posture,
                    postureWarning: postureWarning
                )
            }
        }
    }

    private var postureWarning: String? {
        let ratios = session.sortedQuestions.compactMap(\.faceDetectedRatio)
        guard !ratios.isEmpty else { return nil }
        let average = ratios.reduce(0, +) / Double(ratios.count)
        return average < 0.3 ? "카메라·조명을 확인하고 얼굴이 잘 보이도록 연습해 보세요." : nil
    }

    private var summaryCards: some View {
        HStack(spacing: 16) {
            SummaryCard(title: "질문 수", value: "\(session.questions.count)개", icon: "list.bullet")
            SummaryCard(title: "필러워드", value: "\(totalFillerWords)회", icon: "text.word.spacing")
            SummaryCard(title: "소요 시간", value: formatDuration(totalDuration), icon: "clock")
        }
        .padding()
    }

    private var questionFeedbacks: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("질문별 피드백")
                .font(.title2.bold())

            ForEach(session.sortedQuestions, id: \.questionID) { question in
                QuestionFeedbackCard(question: question)
            }
        }
    }

    private var doneButton: some View {
        Button("홈으로") {
            onDone()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes)분 \(secs)초"
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct QuestionFeedbackCard: View {
    let question: QuestionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(question.category.displayName)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.12), in: Capsule())
                Spacer()
                QuestionScoreBadges(
                    speechScore: question.speechScore,
                    contentScore: question.contentScore,
                    postureScore: question.postureScore
                )
                if question.fillerWordCount > 0 {
                    Text("필러 \(question.fillerWordCount)회")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Text(question.questionText)
                .font(.headline)

            if !question.transcribedAnswer.isEmpty {
                Group {
                    Text("내 답변")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(question.transcribedAnswer)
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            if !question.aiFeedback.isEmpty {
                Group {
                    Text("피드백")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(question.aiFeedback)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }

            HStack {
                Text("답변 시간: \(Int(question.endTimestamp - question.startTimestamp))초")
                Spacer()
                Text("권장: \(question.recommendedSeconds)초")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}
