import SwiftData
import SwiftUI

struct PreSessionView: View {
    let profile: CandidateProfile
    let stage: SessionStage

    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: SessionViewModel
    @State private var expertConfig: ExpertSessionConfiguration
    @State private var navigateToSession = false

    init(profile: CandidateProfile, stage: SessionStage) {
        self.profile = profile
        self.stage = stage
        let config = stage == .expert ? profile.expertSessionConfiguration : .default
        _expertConfig = State(initialValue: config)
        _viewModel = State(initialValue: SessionViewModel(
            profile: profile,
            stage: stage,
            expertConfiguration: stage == .expert ? config : nil
        ))
    }

    private var loadingMessage: String {
        if viewModel.isLoadingFromPool {
            "저장된 질문 불러오는 중..."
        } else {
            "면접 질문 생성 중..."
        }
    }

    private var sessionSummary: String {
        if stage == .expert {
            expertConfig.sessionSummaryLabel
        } else {
            stage.preset.sessionSummaryLabel
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    StageBadgeView(stage: stage)
                    Spacer()
                }

                PrepSessionTitle(title: "세션 미리보기")

                if stage == .expert {
                    AdaptivePrepSectionsLayout {
                        ExpertSessionSetupView(
                            configuration: $expertConfig,
                            weaknessSummary: WeakTopicAnalyzer.weaknessSummary(from: profile),
                            isSettingsLocked: viewModel.isLoadingQuestions
                        ) {
                            expertQuestionGenerationControls
                        }
                    } content: {
                        previewPanelContent
                    }
                } else {
                    previewPanelContent
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("세션 준비")
        .task {
            if stage == .expert {
                viewModel.markExpertQuestionsStale(expertConfig, context: modelContext)
            } else {
                await viewModel.prepareQuestions(context: modelContext)
            }
        }
        .onChange(of: expertConfig) { oldValue, newValue in
            guard stage == .expert, !viewModel.isLoadingQuestions else { return }
            if oldValue.questionGenerationToken != newValue.questionGenerationToken {
                viewModel.markExpertQuestionsStale(newValue, context: modelContext)
            } else {
                viewModel.syncExpertPresentationSettings(newValue)
            }
        }
        .onDisappear {
            viewModel.cancelPendingConfigurationUpdates()
            if stage == .expert {
                viewModel.persistExpertConfiguration(expertConfig, context: modelContext)
            }
            if !navigateToSession {
                viewModel.releaseReservedQuestions(context: modelContext)
            }
        }
        .navigationDestination(isPresented: $navigateToSession) {
            SessionView(viewModel: viewModel)
        }
        .alert("오류", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("확인") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var isSessionStartDisabled: Bool {
        if viewModel.isLoadingQuestions { return true }
        if stage == .expert {
            return viewModel.needsQuestionRegeneration || viewModel.questionFlow.questions.isEmpty
        }
        return viewModel.questionFlow.questions.isEmpty
    }

    private func startSession() {
        if stage == .expert {
            viewModel.persistExpertConfiguration(expertConfig, context: modelContext)
        }
        navigateToSession = true
    }

    private var previewPanelContent: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isLoadingQuestions {
                    ProgressView(loadingMessage)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    summaryContents
                    questionPreview
                }

                PrepContentPanelFooter(
                    startTitle: "면접 시작",
                    startSystemImage: "video.fill",
                    isStartDisabled: isSessionStartDisabled,
                    onStart: startSession
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private var expertQuestionGenerationControls: some View {
        PrepQuestionGenerationControls(
            isLoading: viewModel.isLoadingQuestions,
            needsRegeneration: viewModel.needsQuestionRegeneration,
            canGenerate: true,
            hasPreparedQuestions: !viewModel.questionFlow.questions.isEmpty
        ) {
            Task {
                await viewModel.generateExpertQuestions(context: modelContext)
            }
        } onCancel: {
            viewModel.cancelQuestionGeneration()
        }
    }

    private var summaryContents: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("예상 질문 개요", systemImage: "checkmark.bubble.fill")
                .font(.headline)

            LabeledContent("질문 수", value: "\(viewModel.questionFlow.totalCount)개")
            LabeledContent("예상 시간", value: "\(viewModel.questionFlow.expectedDurationSeconds / 60)분")
            LabeledContent("구성", value: sessionSummary)
            if stage == .expert {
                LabeledContent("면접관 톤", value: expertConfig.interviewerTone.displayName)
            }
        }
    }

    private var questionPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘의 질문")
                .font(.headline)

            ForEach(Array(viewModel.questionFlow.questions.enumerated()), id: \.element.id) { index, question in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(question.questionText)
                                .font(.subheadline)
                            if stage == .expert, question.category != .selfIntro, question.category != .closing {
                                Text(question.category.displayName)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                            }
                        }
                        Text("\(question.recommendedSeconds)초 권장")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
