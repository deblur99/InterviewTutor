import SwiftUI

struct FreePracticeCustomQuestionSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var topic = ""
    @State private var question = ""
    @State private var expectedAnswer = ""

    let onAdd: (String, String, String) -> Void

    private var canAdd: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("예: 프로젝트 리더십", text: $topic)
                    TextField("면접관에게 들을 질문", text: $question, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("포함하면 좋은 핵심 포인트", text: $expectedAnswer, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("추가 질문")
                } footer: {
                    Text("입력한 질문은 오늘의 연습 목록 맨 아래에 추가됩니다.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("그 외 추가 질문")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        onAdd(topic, question, expectedAnswer)
                        dismiss()
                    }
                    .disabled(!canAdd)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 360)
    }
}
