import SwiftData
import SwiftUI

struct PreFreePracticeView: View {
    let profile: CandidateProfile

    @Environment(\.modelContext) private var modelContext

    @State private var configuration: FreePracticeConfiguration
    @State private var viewModel: FreePracticeViewModel
    @State private var navigateToSession = false
    @State private var showCustomQuestionSheet = false

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

                HStack(alignment: .top, spacing: 24) {
                    FreePracticeTopicPicker(configuration: $configuration)
                        .frame(maxWidth: 380)

                    practiceQuestionsPanel
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        .sheet(isPresented: $showCustomQuestionSheet) {
            FreePracticeCustomQuestionSheet { topic, question, expectedAnswer in
                viewModel.addCustomQuestion(
                    topic: topic,
                    question: question,
                    expectedAnswer: expectedAnswer
                )
            }
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

    @ViewBuilder
    private var practiceQuestionsPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("오늘의 연습")
                    .font(.headline)

                if viewModel.isLoadingQuestions {
                    ProgressView("질문 준비 중...")
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if viewModel.questions.isEmpty {
                    Text(configuration.isValid
                         ? "질문을 생성하지 못했습니다."
                         : "항목을 선택하면 질문이 생성됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                } else {
                    Text(configuration.summaryLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("드래그하여 순서 변경")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    List {
                        ForEach(Array(viewModel.questions.enumerated()), id: \.element.id) { index, question in
                            questionRow(index: index, question: question)
                        }
                        .onMove { source, destination in
                            viewModel.moveQuestions(from: source, to: destination)
                        }
                    }
                    .listStyle(.plain)
                    .frame(minHeight: CGFloat(viewModel.questions.count) * 56 + 8)

                    Button {
                        showCustomQuestionSheet = true
                    } label: {
                        Label("그 외 추가 질문", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private func questionRow(index: Int, question: GeneratedQuestion) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)

            Text("\(index + 1).")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(question.displayTopicName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(question.questionText)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 2)
    }
}
