import SwiftUI

struct StageBadgeView: View {
    let stage: SessionStage

    var body: some View {
        Text(stage.displayName)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.blue.opacity(0.15), in: Capsule())
    }
}
