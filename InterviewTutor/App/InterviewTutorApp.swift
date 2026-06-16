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
    }
}
