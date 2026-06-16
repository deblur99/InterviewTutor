import SwiftUI

struct FreePracticeTopicPicker: View {
    @Binding var configuration: FreePracticeConfiguration

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Text("연습 항목")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(PracticeTopic.practiceOrder) { topic in
                        TopicToggleCard(
                            topic: topic,
                            isSelected: configuration.selectedTopics.contains(topic)
                        ) {
                            toggle(topic)
                        }
                    }
                }

                Stepper(
                    "연습 문항 수: \(configuration.questionCount)개",
                    value: $configuration.questionCount,
                    in: 1...10
                )

                if configuration.selectedTopics.isEmpty {
                    Text("하나 이상의 항목을 선택해 주세요.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private func toggle(_ topic: PracticeTopic) {
        if configuration.selectedTopics.contains(topic) {
            configuration.selectedTopics.remove(topic)
        } else {
            configuration.selectedTopics.insert(topic)
        }
    }
}

private struct TopicToggleCard: View {
    let topic: PracticeTopic
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: topic.icon)
                    .frame(width: 20)
                Text(topic.displayName)
                    .font(.subheadline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(10)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
