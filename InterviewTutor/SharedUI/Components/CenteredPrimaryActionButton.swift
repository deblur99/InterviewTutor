import SwiftUI

struct CenteredPrimaryActionButton: View {
    let title: String
    let systemImage: String
    var maxButtonWidth: CGFloat = PrimaryActionButton.preferredWidth
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            PrimaryActionButton(
                title: title,
                systemImage: systemImage,
                isDisabled: isDisabled,
                action: action
            )
            .frame(width: maxButtonWidth)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}
