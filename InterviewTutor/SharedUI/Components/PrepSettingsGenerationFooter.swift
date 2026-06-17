import SwiftUI

struct PrepSettingsGenerationFooter<Content: View>: View {
    @ViewBuilder private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 8)
    }
}
