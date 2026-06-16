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

                Text("세션 미리보기")
                    .font(.largeTitle.bold())

                if stage == .expert {
                    ExpertSessionSetupView(
                        configuration: $expertConfig,
                        weaknessSummary: WeakTopicAnalyzer.weaknessSummary(from: profile)
                    )
                }

                if viewModel.isLoadingQuestions {
                    ProgressView(loadingMessage)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    summaryCard
                    questionPreview
                    CenteredPrimaryActionButton(
                        title: "면접 시작",
                        systemImage: "video.fill",
                        isDisabled: viewModel.questionFlow.questions.isEmpty
                    ) {
                        if stage == .expert {
                            viewModel.persistExpertConfiguration(expertConfig, context: modelContext)
                        }
                        navigateToSession = true
                    }
                    .padding(.top, 8)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("세션 준비")
        .task {
            if stage == .expert {
                await viewModel.prepareExpertIfNeeded(expertConfig, context: modelContext)
            } else {
                await viewModel.prepareQuestions(context: modelContext)
            }
        }
        .onChange(of: expertConfig.preparationToken) { _, _ in
            guard stage == .expert else { return }
            viewModel.scheduleExpertConfigurationUpdate(expertConfig, context: modelContext)
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

    private var summaryCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("질문 수", value: "\(viewModel.questionFlow.totalCount)개")
                LabeledContent("예상 시간", value: "\(viewModel.questionFlow.expectedDurationSeconds / 60)분")
                LabeledContent("구성", value: sessionSummary)
                if stage == .expert {
                    LabeledContent("면접관 톤", value: expertConfig.interviewerTone.displayName)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
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
