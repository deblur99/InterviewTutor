import SwiftUI

struct SessionCameraOverlayView: View {
    let isPaused: Bool
    let isPreparingPrompter: Bool
    let prompterContent: AnswerPrompterContent?
    let showsPrompterHUD: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                if showsPrompterHUD, let prompterContent, !isPreparingPrompter {
                    AnswerPrompterHUDOverlay(
                        content: prompterContent,
                        maxHeight: geometry.size.height * 0.42
                    )
                }

                if isPreparingPrompter {
                    PrompterPreparationOverlay()
                }

                if isPaused {
                    SessionPausedOverlay()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct AnswerPrompterHUDOverlay: View {
    let content: AnswerPrompterContent
    let maxHeight: CGFloat

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label("프롬프터", systemImage: "text.bubble.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.9))

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(content.scriptSentences.enumerated()), id: \.offset) { _, sentence in
                        Text(sentence)
                            .font(.body)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()
                    .overlay(.white.opacity(0.35))

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow.opacity(0.95))
                        .padding(.top, 2)
                    Text(content.tip)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .topLeading)
        .background(Color(red: 0.72, green: 0.62, blue: 0.92).opacity(0.55))
    }
}

private struct PrompterPreparationOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.72)

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("답변 준비 중...")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("프롬프터 전문을 생성하고 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }
}

private struct SessionPausedOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.88)

            VStack(spacing: 12) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.9))
                Text("일시정지")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("재개를 누르면 세션이 계속됩니다.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
