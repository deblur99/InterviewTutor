import SwiftUI

struct GradeBadgeView: View {
    let grade: LetterGrade

    var body: some View {
        Text(grade.displayName)
            .font(.title2.bold())
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(grade.accentColor.opacity(0.18), in: Capsule())
            .foregroundStyle(grade.accentColor)
    }
}
