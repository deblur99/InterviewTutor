import SwiftData
import SwiftUI

struct ProfileSessionHistorySheet: View {
    let profile: CandidateProfile
    let onSelectSession: (InterviewSession) -> Void

    @Environment(\.dismiss) private var dismiss

    private var stats: ProfileSessionStats {
        ProfileSessionStats.make(from: profile)
    }

    private var scoredSessions: [SessionScorePoint] {
        ProgressChartDataBuilder.scoredSessions(from: profile)
    }

    private var allSessions: [InterviewSession] {
        profile.sessions.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    profileHeader
                    if stats.totalCount == 0 {
                        emptyState
                    } else {
                        if !scoredSessions.isEmpty {
                            ProgressChartView(sessions: scoredSessions)
                        }
                        sessionList
                    }
                }
                .padding(24)
            }
            .navigationTitle("모의면접 기록")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 520)
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(profile.displayTitle)
                .font(.title2.bold())
            if stats.totalCount > 0 {
                HStack(spacing: 20) {
                    summaryChip("총 \(stats.totalCount)회")
                    if let latestScore = stats.latestScore {
                        summaryChip("최근 \(latestScore)점")
                    }
                    if let bestGrade = stats.bestGrade {
                        summaryChip("최고 \(bestGrade.displayName)")
                    }
                }
            }
        }
    }

    private func summaryChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("기록 없음", systemImage: "video.slash")
        } description: {
            Text("훈련 단계나 자유 연습을 완료하면 여기에 기록이 쌓입니다.")
        }
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("역대 기록")
                .font(.title3.bold())

            ForEach(allSessions, id: \.persistentModelID) { session in
                Button {
                    dismiss()
                    onSelectSession(session)
                } label: {
                    SessionHistoryRow(session: session)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
