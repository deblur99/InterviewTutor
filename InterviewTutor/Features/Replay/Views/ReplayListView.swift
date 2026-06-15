import SwiftUI

struct ReplayListView: View {
    let profile: CandidateProfile

    var body: some View {
        List {
            if profile.sessions.isEmpty {
                ContentUnavailableView("세션 기록 없음", systemImage: "video.slash")
            } else {
                ForEach(profile.sessions.sorted(by: { $0.date > $1.date })) { session in
                    NavigationLink {
                        ReplayDetailView(session: session)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(session.stage.displayName)
                                .font(.headline)
                            Text(session.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("세션 기록")
    }
}
