import SwiftUI

struct ScoreSummaryPanel: View {
    let overallScore: Int
    let grade: LetterGrade
    let speechScore: Int
    let contentScore: Int
    let postureScore: Int
    var postureWarning: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("종합 점수")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(overallScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("/ 100")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                GradeBadgeView(grade: grade)
            }

            VStack(spacing: 10) {
                DimensionScoreRow(label: "발화", score: speechScore, color: .blue)
                DimensionScoreRow(label: "내용", score: contentScore, color: .green)
                DimensionScoreRow(label: "자세", score: postureScore, color: .teal)
            }

            if let postureWarning {
                Label(postureWarning, systemImage: "video.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct DimensionScoreRow: View {
    let label: String
    let score: Int
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.bold())
                .frame(width: 36, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * CGFloat(score) / 100)
                }
            }
            .frame(height: 8)
            Text("\(score)")
                .font(.subheadline.monospacedDigit().bold())
                .frame(width: 32, alignment: .trailing)
        }
    }
}

struct QuestionScoreBadges: View {
    let speechScore: Int?
    let contentScore: Int?
    let postureScore: Int?

    var body: some View {
        if speechScore != nil || contentScore != nil || postureScore != nil {
            HStack(spacing: 8) {
                if let speechScore {
                    miniBadge("발화", score: speechScore, color: .blue)
                }
                if let contentScore {
                    miniBadge("내용", score: contentScore, color: .green)
                }
                if let postureScore {
                    miniBadge("자세", score: postureScore, color: .teal)
                }
            }
        }
    }

    private func miniBadge(_ label: String, score: Int, color: Color) -> some View {
        Text("\(label) \(score)")
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}
