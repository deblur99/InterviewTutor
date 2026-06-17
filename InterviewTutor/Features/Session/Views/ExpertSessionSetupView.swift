import SwiftUI

struct ExpertSessionSetupView<Footer: View>: View {
    @Binding var configuration: ExpertSessionConfiguration
    let weaknessSummary: String?
    var isSettingsLocked: Bool = false
    @ViewBuilder private let footer: () -> Footer

    init(
        configuration: Binding<ExpertSessionConfiguration>,
        weaknessSummary: String?,
        isSettingsLocked: Bool = false,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        _configuration = configuration
        self.weaknessSummary = weaknessSummary
        self.isSettingsLocked = isSettingsLocked
        self.footer = footer
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                settingsContent
                    .disabled(isSettingsLocked)

                PrepSettingsGenerationFooter {
                    footer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("실전 연습 설정", systemImage: "gear.circle")
                .font(.headline)

            questionCountStepper("서류 기반", value: $configuration.documentQuestionCount, range: 2...8)
            questionCountStepper("기술·실무", value: $configuration.technicalQuestionCount, range: 0...5)
            questionCountStepper("인성·상황", value: $configuration.behavioralQuestionCount, range: 0...4)
            questionCountStepper("회사·직무", value: $configuration.companyQuestionCount, range: 0...4)
            questionCountStepper("압박", value: $configuration.pressureQuestionCount, range: 0...4)
            questionCountStepper("종합", value: $configuration.comprehensiveQuestionCount, range: 0...2)

            VStack(alignment: .leading, spacing: 6) {
                Text("시간 압박: \(Int(configuration.timePressureMultiplier * 100))%")
                    .font(.subheadline)
                Slider(value: $configuration.timePressureMultiplier, in: 0.6...1.0, step: 0.05)
            }

            Picker("면접관 톤", selection: $configuration.interviewerTone) {
                ForEach(InterviewerTone.allCases) { tone in
                    Text(tone.displayName).tag(tone)
                }
            }
            .pickerStyle(.segmented)

            Text(configuration.interviewerTone.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("약점 집중 훈련", isOn: $configuration.focusWeakAreas)

            if let weaknessSummary {
                Text("취약 영역: \(weaknessSummary)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if configuration.focusWeakAreas {
                Text("이전 세션 데이터가 쌓이면 취약 영역을 자동 반영합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func questionCountStepper(
        _ title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        Stepper("\(title): \(value.wrappedValue)문항", value: value, in: range)
    }
}

extension ExpertSessionSetupView where Footer == EmptyView {
    init(
        configuration: Binding<ExpertSessionConfiguration>,
        weaknessSummary: String?,
        isSettingsLocked: Bool = false
    ) {
        self.init(
            configuration: configuration,
            weaknessSummary: weaknessSummary,
            isSettingsLocked: isSettingsLocked,
            footer: { EmptyView() }
        )
    }
}
