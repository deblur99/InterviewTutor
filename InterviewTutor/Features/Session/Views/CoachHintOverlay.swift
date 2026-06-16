import SwiftUI

struct CoachHintOverlay: View {
    let hint: CoachHint

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: hint.kind.icon)
                .font(.title3)
            Text(hint.message)
                .font(.subheadline.bold())
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
}

struct LiveCoachStatusBar: View {
    let fillerCount: Int
    let keywordCoveragePercent: Int
    let gazePercent: Int

    var body: some View {
        HStack(spacing: 12) {
            statusChip("필러 \(fillerCount)", icon: "text.word.spacing")
            statusChip("키워드 \(keywordCoveragePercent)%", icon: "checkmark.circle")
            statusChip("응시 \(gazePercent)%", icon: "eye")
        }
        .font(.caption2.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.45), in: Capsule())
    }

    private func statusChip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .labelStyle(.titleAndIcon)
    }
}
