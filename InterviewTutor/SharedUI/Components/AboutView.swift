import AppKit
import SwiftUI

enum AboutLinks {
    static let githubURL = URL(string: "https://github.com/deblur99/InterviewTutor/")!
    static let privacyPolicyURL = URL(string: "https://deblur99.github.io/InterviewTutor-privacy-policy/")!
    static let linkedInURL = URL(string: "https://www.linkedin.com/in/deblur99/")!
    static let emailAddress = "freegymewr@gmail.com"
    static let emailURL = URL(string: "mailto:\(emailAddress)")!
}

private struct TitleBlockHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 48

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct AboutView: View {
    static let windowID = "about-interviewtutor"
    static let preferredWidth: CGFloat = 320
    static let preferredHeight: CGFloat = 280

    @State private var titleBlockHeight: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerSection

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                aboutLink("GitHub", destination: AboutLinks.githubURL)
                aboutLink("개인정보처리방침", destination: AboutLinks.privacyPolicyURL)
                aboutLink("LinkedIn", destination: AboutLinks.linkedInURL)
                aboutLink("Email", destination: AboutLinks.emailURL)
            }
        }
        .font(.body)
        .padding(24)
        .frame(width: Self.preferredWidth, height: Self.preferredHeight, alignment: .leading)
        .onPreferenceChange(TitleBlockHeightKey.self) { titleBlockHeight = $0 }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            appIcon
                .frame(width: titleBlockHeight, height: titleBlockHeight)

            titleBlock
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("InterviewTutor")
                .font(.title2.bold())
            Text("macOS용 화상면접 연습 앱")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .preference(key: TitleBlockHeightKey.self, value: geometry.size.height)
            }
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = NSApplication.shared.applicationIconImage {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        }
    }

    private func aboutLink(_ title: String, destination: URL) -> some View {
        Link(title, destination: destination)
            .lineLimit(1)
    }
}
