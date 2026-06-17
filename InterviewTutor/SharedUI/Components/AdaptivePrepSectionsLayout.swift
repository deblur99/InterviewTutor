import SwiftUI

enum PrepSectionsLayoutMetrics {
    static let settingsMaxWidth: CGFloat = 380
    static var horizontalBreakpoint: CGFloat { settingsMaxWidth * 2 + 200 }
}

struct PrepSectionsUsesHorizontalLayoutPreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

private struct PrepSectionsUsesHorizontalLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var prepSectionsUsesHorizontalLayout: Bool {
        get { self[PrepSectionsUsesHorizontalLayoutKey.self] }
        set { self[PrepSectionsUsesHorizontalLayoutKey.self] = newValue }
    }
}

private struct ContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct AdaptivePrepSectionsLayout<Settings: View, Content: View>: View {
    @ViewBuilder private let settings: () -> Settings
    @ViewBuilder private let content: () -> Content

    @State private var containerWidth: CGFloat = 0

    init(
        @ViewBuilder settings: @escaping () -> Settings,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.settings = settings
        self.content = content
    }

    private var usesHorizontalLayout: Bool {
        containerWidth > PrepSectionsLayoutMetrics.horizontalBreakpoint
    }

    var body: some View {
        layoutContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: ContainerWidthKey.self, value: geometry.size.width)
                }
            }
            .onPreferenceChange(ContainerWidthKey.self) { width in
                guard width > 0, containerWidth != width else { return }
                containerWidth = width
            }
            .preference(
                key: PrepSectionsUsesHorizontalLayoutPreferenceKey.self,
                value: usesHorizontalLayout
            )
            .environment(\.prepSectionsUsesHorizontalLayout, usesHorizontalLayout)
    }

    @ViewBuilder
    private var layoutContent: some View {
        if usesHorizontalLayout {
            HStack(alignment: .top, spacing: 24) {
                settingsSection
                contentSection
            }
        } else {
            VStack(alignment: .leading, spacing: 24) {
                settingsSection
                contentSection
            }
        }
    }

    private var settingsSection: some View {
        settings()
            .frame(maxWidth: PrepSectionsLayoutMetrics.settingsMaxWidth, alignment: .leading)
    }

    private var contentSection: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
