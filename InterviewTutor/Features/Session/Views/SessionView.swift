import AVFoundation
import AppKit
import SwiftData
import SwiftUI

struct SessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: SessionViewModel

    var body: some View {
        Group {
            switch viewModel.phase {
            case .preSession:
                ProgressView("카메라 준비 중...")
            case .analyzing:
                analyzingView
            case .postSession:
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
                activeSessionView
            }
        }
        .navigationBarBackButtonHidden(viewModel.phase != .preSession && viewModel.phase != .postSession)
        .task {
            await viewModel.setupCamera()
            if viewModel.previewLayer != nil {
                await viewModel.startSession()
            }
        }
        .onDisappear {
            Task { await viewModel.cleanup(context: modelContext) }
        }
    }

    private var activeSessionView: some View {
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
                    .overlay {
                        ProgressView("카메라 연결 중...")
                    }
                    .padding()
            }

            VStack(spacing: 8) {
                if viewModel.phase.isAnsweringPhase, viewModel.isCoachEnabled {
                    LiveCoachStatusBar(
                        fillerCount: viewModel.coachMonitor.liveFillerCount,
                        keywordCoveragePercent: viewModel.coachMonitor.keywordCoveragePercent,
                        gazePercent: viewModel.coachMonitor.gazePercent
                    )
                }

                if let hint = viewModel.activeCoachHint {
                    CoachHintOverlay(hint: hint)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            VStack {
                phaseIndicator
                    .padding()
                Spacer()
            }
        }
    }

    private var sidePanel: some View {
        VStack(spacing: 20) {
            if let question = viewModel.currentQuestion {
                VStack(alignment: .leading, spacing: 8) {
                    Text("현재 질문")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(question.questionText)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            timerSection

            coachControls

            InWindowPrompterView(
                keywords: viewModel.currentKeywords,
                showAnswerHints: viewModel.stage.showsFullPrompter
            )

            Spacer()

            if case .answering = viewModel.phase {
                Button("다음 질문") {
                    Task { await viewModel.skipToNext() }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .onChange(of: viewModel.hudState) { _, _ in
            viewModel.updateHUD(anchorWindow: NSApp.keyWindow)
        }
        .onChange(of: viewModel.coachMonitor.liveFillerCount) { _, _ in
            viewModel.updateHUD(anchorWindow: NSApp.keyWindow)
        }
        .onChange(of: viewModel.coachMonitor.keywordCoveragePercent) { _, _ in
            viewModel.updateHUD(anchorWindow: NSApp.keyWindow)
        }
        .onChange(of: viewModel.coachMonitor.gazePercent) { _, _ in
            viewModel.updateHUD(anchorWindow: NSApp.keyWindow)
        }
    }

    private var coachControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("실시간 코치", systemImage: "person.fill.questionmark")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Toggle("코치 힌트", isOn: $viewModel.isCoachEnabled)
                .toggleStyle(.switch)

            if viewModel.stage == .beginner {
                Toggle("HUD 프롬프터", isOn: $viewModel.isHUDEnabled)
                    .toggleStyle(.switch)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
        case .selfIntro: "자기소개"
        case .questionTTS: "질문 재생 중"
        case .pauseBeforeAnswer: "답변 준비"
        case .answering: "답변 중"
        case .closing: "마무리 발언"
        default: "녹화 중"
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("세션 분석 중")
                .font(.title2.bold())
            Text(viewModel.analysisProgress)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
