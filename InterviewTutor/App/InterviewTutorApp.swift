import SwiftUI
import SwiftData

@main
struct InterviewTutorApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CandidateProfile.self,
            InterviewSession.self,
            QuestionRecord.self,
            CachedQuestion.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(ActiveProfileStore())
                .frame(
                    minWidth: MainWindowMetrics.minimumWidth,
                    minHeight: MainWindowMetrics.minimumHeight
                )
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(
            width: MainWindowMetrics.defaultWidth,
            height: MainWindowMetrics.defaultHeight
        )
        .windowResizability(.contentMinSize)
        .commands {
            InterviewTutorAppCommands()
        }

        Window("About InterviewTutor", id: AboutView.windowID) {
            AboutView()
        }
        .defaultSize(
            width: AboutView.preferredWidth,
            height: AboutView.preferredHeight
        )
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}

private enum MainWindowMetrics {
    static let defaultWidth: CGFloat = 1100
    static let defaultHeight: CGFloat = 750
    static let minimumWidth: CGFloat = 500
    static let minimumHeight: CGFloat = 750
}

private struct InterviewTutorAppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About InterviewTutor") {
                openWindow(id: AboutView.windowID)
            }
        }
    }
}
