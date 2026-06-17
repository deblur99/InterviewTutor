import SwiftUI

struct ProfileCustomQuestionLibraryView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var profile: CandidateProfile

    @State private var newQuestionText = ""
    @State private var newExpectedAnswer = ""
    @State private var newRecommendedSeconds = 90.0
    @State private var selectedStages = Set(SessionStage.allCases)

    var body: some View {
        NavigationStack {
            List {
                Section("새 사용자 질문") {
                    TextField("질문", text: $newQuestionText, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("예상 답변 (선택)", text: $newExpectedAnswer, axis: .vertical)
                        .lineLimit(2...5)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("권장 답변 시간: \(Int(newRecommendedSeconds))초")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $newRecommendedSeconds, in: 30...180, step: 5)
                    }

                    stageSelection

                    Button {
                        addQuestion()
                    } label: {
                        Label("사용자 질문 추가", systemImage: "plus")
                    }
                    .disabled(newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedStages.isEmpty)
                }

                Section("등록된 사용자 질문") {
                    if profile.customInterviewQuestions.isEmpty {
                        ContentUnavailableView("등록된 질문 없음", systemImage: "text.badge.plus")
                    } else {
                        ForEach(profile.customInterviewQuestions) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.questionText)
                                    .font(.body)
                                if !item.expectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(item.expectedAnswer)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 8) {
                                    Text("\(item.recommendedSeconds)초")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                    Text(item.stages.map(\.displayName).joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteQuestions)
                    }
                }
            }
            .navigationTitle("사용자 질문 라이브러리")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .frame(minWidth: 620, minHeight: 500)
    }

    private var stageSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("적용 단계")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(SessionStage.allCases) { stage in
                Toggle(stage.displayName, isOn: Binding(
                    get: { selectedStages.contains(stage) },
                    set: { isOn in
                        if isOn {
                            selectedStages.insert(stage)
                        } else {
                            selectedStages.remove(stage)
                        }
                    }
                ))
            }
        }
    }

    private func addQuestion() {
        let question = CustomInterviewQuestion(
            questionText: newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines),
            expectedAnswer: newExpectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines),
            recommendedSeconds: Int(newRecommendedSeconds),
            stages: selectedStages
        )

        guard question.isValid else { return }

        var updated = profile.customInterviewQuestions
        updated.append(question)
        profile.customInterviewQuestions = updated
        profile.updatedAt = .now

        newQuestionText = ""
        newExpectedAnswer = ""
        newRecommendedSeconds = 90
        selectedStages = Set(SessionStage.allCases)
    }

    private func deleteQuestions(at offsets: IndexSet) {
        var updated = profile.customInterviewQuestions
        updated.remove(atOffsets: offsets)
        profile.customInterviewQuestions = updated
        profile.updatedAt = .now
    }
}
