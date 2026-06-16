import AVFoundation
import SwiftData
import SwiftUI

struct FreePracticeSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: FreePracticeViewModel

    var body: some View {
        Group {
            switch viewModel.phase {
            case .preparing:
                ProgressView("카메라 준비 중...")
            case .analyzingSession:
                analyzingView
            case .completed:
                if let session = viewModel.completedSession {
                    PostSessionView(session: session) {
                        try? modelContext.save()
                        dismiss()
                    }
                    .onAppear {
                        modelContext.insert(session)
                        for question in session.questions {
                            modelContext.insert(question)
                        }
                    }
                }
            default:
                activePracticeView
            }
        }
        .navigationBarBackButtonHidden(viewModel.phase != .preparing && viewModel.phase != .completed)
        .sheet(isPresented: showFeedbackBinding) {
            if let record = viewModel.feedbackRecord {
                FreePracticeQuestionFeedbackSheet(
                    record: record,
                    progressLabel: viewModel.progressLabel,
                    onContinue: {
                        viewModel.acknowledgeFeedback()
                    }
                )
            }
        }
        .task {
            await viewModel.setupCamera()
            if viewModel.previewLayer != nil {
                await viewModel.startPractice(context: modelContext)
            }
        }
        .onDisappear {
            Task { await viewModel.cleanup() }
        }
    }

    private var showFeedbackBinding: Binding<Bool> {
        Binding(
            get: { viewModel.phase == .questionFeedback && viewModel.feedbackRecord != nil },
            set: { _ in }
        )
    }

    private var activePracticeView: some View {
        HStack(spacing: 0) {
            cameraSection
                .frame(maxWidth: .infinity)

            sidePanel
                .frame(width: 320)
                .background(.regularMaterial)
        }
    }

    private var cameraSection: some View {
        ZStack(alignment: .bottom) {
            if let previewLayer = viewModel.previewLayer {
                CameraPreviewRepresentable(previewLayer: previewLayer)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay { ProgressView("카메라 연결 중...") }
                    .padding()
            }

            VStack {
                HStack {
                    phaseIndicator
                    Spacer()
                    Text(viewModel.progressLabel)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6), in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding()
                Spacer()
            }
        }
    }

    private var sidePanel: some View {
        VStack(spacing: 20) {
            if let question = viewModel.currentQuestion {
                VStack(alignment: .leading, spacing: 8) {
                    Text(question.category.displayName)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(question.questionText)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            timerSection

            Spacer()

            if viewModel.phase == .answering {
                Button("답변 완료") {
                    Task { await viewModel.skipToNext() }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }

            if viewModel.phase == .analyzingQuestion {
                ProgressView("피드백 생성 중...")
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var timerSection: some View {
        switch viewModel.timerState {
        case .idle:
            EmptyView()
        case .running(let remaining):
            if let question = viewModel.currentQuestion {
                TimerRingView(
                    totalSeconds: TimeInterval(question.recommendedSeconds),
                    remainingSeconds: remaining
                )
            }
        case .finished:
            Text("시간 종료")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var phaseIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
            Text(phaseLabel)
                .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.6), in: Capsule())
        .foregroundStyle(.white)
    }

    private var phaseLabel: String {
        switch viewModel.phase {
        case .questionTTS: "질문 재생 중"
        case .pauseBeforeAnswer: "답변 준비"
        case .answering: "답변 중"
        case .analyzingQuestion: "분석 중"
        default: "연습 중"
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("연습 마무리 중")
                .font(.title2.bold())
            Text(viewModel.analysisProgress)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
