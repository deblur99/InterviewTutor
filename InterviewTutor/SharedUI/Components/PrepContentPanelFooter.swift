import SwiftUI

struct PrepSessionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.largeTitle.bold())
    }
}

struct PrepContentPanelFooter: View {
    let startTitle: String
    let startSystemImage: String
    var isStartDisabled: Bool = false
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Divider()

            HStack {
                Spacer(minLength: 0)
                PrimaryActionButton(
                    title: startTitle,
                    systemImage: startSystemImage,
                    isDisabled: isStartDisabled,
                    action: onStart
                )
            }
        }
        .padding(.top, 4)
    }
}
