import SwiftUI

struct TimerRingView: View {
    let totalSeconds: TimeInterval
    let remainingSeconds: TimeInterval

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return max(0, min(1, remainingSeconds / totalSeconds))
    }

    private var ringColor: Color {
        if progress < 0.2 { return .red }
        if progress < 0.4 { return .orange }
        return Color.accentColor
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 8)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: progress)

            VStack(spacing: 2) {
                Text("\(Int(remainingSeconds))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("초")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 120, height: 120)
    }
}

#Preview {
    TimerRingView(totalSeconds: 60, remainingSeconds: 35)
        .padding()
}
