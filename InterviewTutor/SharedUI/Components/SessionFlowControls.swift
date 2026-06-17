import SwiftUI

struct SessionFlowControls: View {
    let isPaused: Bool
    let isEnabled: Bool
    let onTogglePause: () -> Void
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(isPaused ? "재개" : "일시정지", action: onTogglePause)
                .buttonStyle(.bordered)
                .disabled(!isEnabled)

            Button("나가기", role: .destructive, action: onExit)
                .buttonStyle(.bordered)
                .disabled(!isEnabled)
        }
        .frame(maxWidth: .infinity)
    }
}
