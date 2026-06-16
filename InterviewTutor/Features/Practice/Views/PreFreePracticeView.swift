import SwiftData
import SwiftUI

struct PreFreePracticeView: View {
    let profile: CandidateProfile

    @Environment(\.modelContext) private var modelContext

    @State private var configuration: FreePracticeConfiguration
    @State private var viewModel: FreePracticeViewModel
    @State private var navigateToSession = false

    init(profile: CandidateProfile) {
        self.profile = profile
        let config = profile.freePracticeConfiguration
        _configuration = State(initialValue: config)
        _viewModel = State(initialValue: FreePracticeViewModel(profile: profile, configuration: config))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    StageBadgeView(stage: .freePractice)
                    Spacer()
                }

                Text("자유 연습")
                    .font(.largeTitle.bold())

                Text("연습하고 싶은 항목만 골라 집중 훈련합니다. 문항마다 피드백을 받고, 마지막에 종합 피드백이 제공됩니다.")
                    .foregroundStyle(.secondary)

                FreePracticeTopicPicker(configuration: $configuration)

                if viewModel.isLoadingQuestions {
                    ProgressView("질문 준비 중...")
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if !viewModel.questions.isEmpty {
                    questionPreview
                }

                CenteredPrimaryActionButton(
                    title: "연습 시작",
                    systemImage: "play.fill",
                    isDisabled: !configuration.isValid || viewModel.questions.isEmpty
                ) {
                    viewModel.persistConfiguration(context: modelContext)
                    navigateToSession = true
                }
                .padding(.top, 8)
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("자유 연습")
        .task {
            await viewModel.prepareIfNeeded(context: modelContext)
        }
        .onChange(of: configuration.preparationToken) { _, _ in
            viewModel.scheduleConfigurationUpdate(configuration, context: modelContext)
        }
        .onDisappear {
            viewModel.cancelPendingUpdates()
            viewModel.persistConfiguration(context: modelContext)
        }
        .navigationDestination(isPresented: $navigateToSession) {
            FreePracticeSessionView(viewModel: viewModel)
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

    private var questionPreview: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("오늘의 연습")
                    .font(.headline)
                Text(configuration.summaryLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(Array(viewModel.questions.enumerated()), id: \.element.id) { index, question in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(question.category.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(question.questionText)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}
