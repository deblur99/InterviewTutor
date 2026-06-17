import AVFoundation
import SwiftData
import SwiftUI

struct SessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: SessionViewModel

    @State private var showExitConfirmation = false

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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .confirmationDialog(
            "세션을 나가시겠습니까?",
            isPresented: $showExitConfirmation,
            titleVisibility: .visible
        ) {
            Button("나가기", role: .destructive) {
                Task {
                    await viewModel.exitSession(context: modelContext)
                    dismiss()
                }
            }
            Button("계속하기", role: .cancel) {}
        } message: {
            Text("진행중인 내용은 저장되지 않습니다.")
        }
    }

    private static let sidePanelWidth: CGFloat = 320

    private var activeSessionView: some View {
        HStack(spacing: 0) {
            cameraSection
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0)

            sidePanel
                .frame(width: Self.sidePanelWidth)
                .layoutPriority(1)
                .background(.regularMaterial)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cameraSection: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Group {
                    if let previewLayer = viewModel.previewLayer {
                        CameraPreviewRepresentable(previewLayer: previewLayer)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.quaternary)
                            .overlay {
                                ProgressView("카메라 연결 중...")
                            }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .aspectRatio(16 / 9, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    SessionCameraOverlayView(
                        isPaused: viewModel.isSessionPaused,
                        isPreparingPrompter: viewModel.phase == .preparingPrompter || viewModel.isGeneratingPrompter,
                        prompterContent: viewModel.currentPrompterContent,
                        showsPrompterHUD: viewModel.showsCameraPrompterHUD,
                        coachMetrics: viewModel.phase.isAnsweringPhase ? SessionCameraOverlayCoachMetrics(
                            fillerCount: viewModel.coachMonitor.liveFillerCount,
                            keywordCoveragePercent: viewModel.coachMonitor.keywordCoveragePercent,
                            gazePercent: viewModel.coachMonitor.gazePercent,
                            keywords: viewModel.currentKeywords
                        ) : nil
                    )
                }
                .overlay(alignment: .top) {
                    phaseIndicator
                        .padding(12)
                }
                .padding()

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
                .padding(.horizontal)
                .padding(.bottom, 8)
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

            Spacer()

            if viewModel.showsSessionControls {
                SessionFlowControls(
                    isPaused: viewModel.isSessionPaused,
                    isEnabled: true,
                    onTogglePause: {
                        if viewModel.isSessionPaused {
                            viewModel.resumeSession()
                        } else {
                            viewModel.pauseSession()
                        }
                    },
                    onExit: {
                        showExitConfirmation = true
                    }
                )
            }

            if viewModel.phase.isAnsweringPhase {
                Button("답변 완료") {
                    viewModel.skipToNext()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        case .paused(let remaining):
            if let question = viewModel.currentQuestion {
                VStack(spacing: 8) {
                    TimerRingView(
                        totalSeconds: TimeInterval(question.recommendedSeconds),
                        remainingSeconds: remaining
                    )
                    Text("일시정지")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
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
        if viewModel.isSessionPaused {
            return "일시정지"
        }

        switch viewModel.phase {
        case .preparingPrompter: return "답변 준비"
        case .selfIntro: return "자기소개"
        case .questionTTS: return "질문 재생 중"
        case .pauseBeforeAnswer: return "답변 준비"
        case .answering: return "답변 중"
        case .closing: return "마무리 발언"
        default: return "녹화 중"
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
