import SwiftUI

struct CenteredPrimaryActionButton: View {
    let title: String
    let systemImage: String
    var maxButtonWidth: CGFloat = 400
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isDisabled)
            .frame(maxWidth: maxButtonWidth)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}
