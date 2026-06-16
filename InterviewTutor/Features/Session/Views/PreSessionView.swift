import SwiftData
import SwiftUI

struct PreSessionView: View {
    let profile: CandidateProfile
    let stage: SessionStage

    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: SessionViewModel
    @State private var navigateToSession = false

    init(profile: CandidateProfile, stage: SessionStage) {
        self.profile = profile
        self.stage = stage
        _viewModel = State(initialValue: SessionViewModel(profile: profile, stage: stage))
    }

    private var loadingMessage: String {
        if viewModel.isLoadingFromPool {
            "저장된 질문 불러오는 중..."
        } else {
            "면접 질문 생성 중..."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                StageBadgeView(stage: stage)
                Spacer()
            }

            Text("세션 미리보기")
                .font(.largeTitle.bold())

            if viewModel.isLoadingQuestions {
                ProgressView(loadingMessage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                summaryCard
                questionPreview
                Spacer()
                startButton
            }
        }
        .padding(32)
        .navigationTitle("세션 준비")
        .task {
            await viewModel.prepareQuestions(context: modelContext)
        }
        .onDisappear {
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
                LabeledContent("구성", value: stage.preset.sessionSummaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                        Text(question.questionText)
                            .font(.subheadline)
                        Text("\(question.recommendedSeconds)초 권장")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var startButton: some View {
        Button {
            navigateToSession = true
        } label: {
            Label("면접 시작", systemImage: "video.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.questionFlow.questions.isEmpty)
    }
}
