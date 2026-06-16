import SwiftData
import SwiftUI

struct ProfileSessionSummaryCard: View {
    let stats: ProfileSessionStats
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("모의면접 기록", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                if stats.totalCount == 0 {
                    Text("아직 모의면접 기록이 없습니다. 훈련을 시작해 보세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    HStack(spacing: 16) {
                        metricBlock(title: "총 연습", value: "\(stats.totalCount)회")
                        if let latestScore = stats.latestScore {
                            metricBlock(title: "최근 종합", value: "\(latestScore)점")
                        }
                        if let latestGrade = stats.latestGrade {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("최근 등급")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(latestGrade.displayName)
                                    .font(.headline)
                                    .foregroundStyle(latestGrade.accentColor)
                            }
                        }
                        if let bestGrade = stats.bestGrade {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("최고 등급")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(bestGrade.displayName)
                                    .font(.headline)
                                    .foregroundStyle(bestGrade.accentColor)
                            }
                        }
                    }

                    VStack(spacing: 6) {
                        ForEach(stats.recentSessions, id: \.persistentModelID) { session in
                            SessionHistoryRow(session: session, compact: true)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func metricBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

struct SessionHistoryRow: View {
    let session: InterviewSession
    var compact: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                HStack(spacing: 8) {
                    Text(session.stage.displayName)
                        .font(compact ? .caption.bold() : .headline)
                    if let grade = session.overallGrade, let score = session.overallScore {
                        Text("\(grade.displayName) · \(score)점")
                            .font(.caption2.bold())
                            .foregroundStyle(grade.accentColor)
                    } else {
                        Text("점수 없음")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(session.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !compact {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(compact ? 8 : 12)
        .background(.background.opacity(compact ? 0.5 : 1), in: RoundedRectangle(cornerRadius: compact ? 8 : 12))
        .overlay {
            if !compact {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 1)
            }
        }
    }
}
