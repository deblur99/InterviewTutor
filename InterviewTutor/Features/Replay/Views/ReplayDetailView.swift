import AVFoundation
import AVKit
import SwiftUI

struct ReplayDetailView: View {
    let session: InterviewSession

    @State private var player: AVPlayer?
    @State private var selectedQuestionID: UUID?

    private var videoURL: URL? {
        guard !session.videoFilePath.isEmpty else { return nil }
        return VideoStorageManager.videoURL(for: session.videoFilePath)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ContentUnavailableView("영상 없음", systemImage: "video.slash")
                    .frame(height: 300)
            }

            questionTimeline

            if let selected = selectedQuestion {
                selectedQuestionDetail(selected)
            }
        }
        .padding(32)
        .navigationTitle("다시보기")
        .onAppear {
            if let videoURL {
                player = AVPlayer(url: videoURL)
            }
        }
        .onDisappear {
            player?.pause()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StageBadgeView(stage: session.stage)
                Text(session.date, style: .date)
                    .foregroundStyle(.secondary)
            }

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
                    postureScore: posture
                )
            }
        }
    }

    private var questionTimeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("질문 타임라인")
                .font(.headline)

            ForEach(session.sortedQuestions, id: \.questionID) { question in
                Button {
                    selectedQuestionID = question.questionID
                    seek(to: question.startTimestamp)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(question.questionText)
                                .font(.subheadline)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(formatTimestamp(question.startTimestamp))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: selectedQuestionID == question.questionID ? "play.circle.fill" : "play.circle")
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(10)
                    .background(
                        selectedQuestionID == question.questionID
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var selectedQuestion: QuestionRecord? {
        guard let id = selectedQuestionID else { return session.sortedQuestions.first }
        return session.sortedQuestions.first { $0.questionID == id }
    }

    private func selectedQuestionDetail(_ question: QuestionRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("선택된 질문")
                .font(.headline)

            if !question.transcribedAnswer.isEmpty {
                Text(question.transcribedAnswer)
                    .font(.subheadline)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }

            if !question.aiFeedback.isEmpty {
                Text(question.aiFeedback)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
        player?.play()
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}