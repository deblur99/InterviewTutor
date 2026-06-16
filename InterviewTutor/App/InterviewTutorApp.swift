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
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1100, height: 750)
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
