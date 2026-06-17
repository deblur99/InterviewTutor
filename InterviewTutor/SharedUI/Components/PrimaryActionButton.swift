import SwiftUI

struct PrimaryActionButton: View {
    static let preferredWidth: CGFloat = 200

    let title: String
    let systemImage: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isDisabled)
        .frame(width: Self.preferredWidth)
    }
}
