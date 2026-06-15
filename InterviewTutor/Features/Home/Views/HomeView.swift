import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CandidateProfile.updatedAt, order: .reverse) private var profiles: [CandidateProfile]

    @State private var showOnboarding = false
    @State private var navigationPath = NavigationPath()
    @State private var poolRefillTask: Task<Void, Never>?

    private var profile: CandidateProfile? { profiles.first }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    if let profile {
                        profileSummary(profile)
                        stageSelection
                    } else {
                        emptyState
                    }
                }
                .padding(32)
            }
            .navigationTitle("면접도우미")
            .toolbar {
                if profile != nil {
                    ToolbarItem {
                        Button("프로필 수정") {
                            showOnboarding = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showOnboarding, onDismiss: {
                guard let profile, profile.isComplete else { return }
                poolRefillTask?.cancel()
                poolRefillTask = Task {
                    await QuestionPoolManager().ensurePoolFilled(profile: profile, context: modelContext)
                }
            }) {
                if let profile {
                    OnboardingFlowView(profile: profile)
                } else {
                    OnboardingFlowView()
                }
            }
            .navigationDestination(for: SessionStage.self) { stage in
                if let profile {
                    PreSessionView(profile: profile, stage: stage)
                }
            }
            .navigationDestination(for: InterviewSession.self) { session in
                ReplayDetailView(session: session)
            }
        }
        .onAppear {
            if profile == nil {
                showOnboarding = true
            }
        }
        .task(id: poolRefillToken) {
            guard let profile, profile.isComplete else { return }
            poolRefillTask?.cancel()
            poolRefillTask = Task {
                await QuestionPoolManager().ensurePoolFilled(profile: profile, context: modelContext)
            }
        }
        .onDisappear {
            poolRefillTask?.cancel()
        }
    }

    private var poolRefillToken: String? {
        guard let profile, profile.isComplete else { return nil }
        return ProfileFingerprint.make(for: profile)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("화상면접 연습")
                .font(.largeTitle.bold())
            Text("온보딩 정보를 바탕으로 단계별 면접 훈련을 진행합니다.")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("프로필이 없습니다", systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text("지원 회사, 직무, 채용공고, 이력서 정보를 입력해 주세요.")
        } actions: {
            Button("온보딩 시작") {
                showOnboarding = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func profileSummary(_ profile: CandidateProfile) -> some View {
        GroupBox("지원 정보") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("회사", value: profile.company)
                LabeledContent("산업", value: profile.industry)
                LabeledContent("직무", value: profile.role)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var stageSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("훈련 단계")
                .font(.title2.bold())

            ForEach(SessionStage.allCases) { stage in
                StageCard(
                    stage: stage,
                    isEnabled: stage.isAvailableInMVP && (profile?.isComplete ?? false)
                ) {
                    navigationPath.append(stage)
                }
            }

            if let profile, !profile.sessions.isEmpty {
                Divider()
                    .padding(.vertical, 8)
                Text("이전 세션")
                    .font(.title3.bold())
                ForEach(profile.sessions.sorted(by: { $0.date > $1.date })) { session in
                    Button {
                        navigationPath.append(session)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(session.stage.displayName)
                                    .font(.headline)
                                Text(session.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct StageCard: View {
    let stage: SessionStage
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(stage.displayName)
                            .font(.headline)
                        if !stage.isAvailableInMVP {
                            Text("준비 중")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2), in: Capsule())
                        }
                    }
                    Text(stage.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
            }
            .padding()
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [CandidateProfile.self, InterviewSession.self, QuestionRecord.self, CachedQuestion.self], inMemory: true)
}
