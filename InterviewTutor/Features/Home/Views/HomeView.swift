import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ActiveProfileStore.self) private var activeProfileStore

    @Query(sort: \CandidateProfile.updatedAt, order: .reverse) private var profiles: [CandidateProfile]

    @State private var showOnboarding = false
    @State private var showProfileManagement = false
    @State private var navigationPath = NavigationPath()
    @State private var poolRefillTask: Task<Void, Never>?

    private var activeProfile: CandidateProfile? {
        activeProfileStore.activeProfile(in: profiles)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    if let activeProfile {
                        profileSummary(activeProfile)
                        stageSelection(for: activeProfile)
                    } else {
                        emptyState
                    }
                }
                .padding(32)
            }
            .navigationTitle("면접도우미")
            .toolbar {
                if !profiles.isEmpty {
                    ToolbarItem {
                        Button("프로필 관리") {
                            showProfileManagement = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showOnboarding, onDismiss: handleOnboardingDismiss) {
                OnboardingFlowView(mode: .create) { savedProfile in
                    activeProfileStore.select(savedProfile)
                }
            }
            .sheet(isPresented: $showProfileManagement, onDismiss: handleOnboardingDismiss) {
                ProfileManagementView()
            }
            .navigationDestination(for: SessionStage.self) { stage in
                if let activeProfile {
                    PreSessionView(profile: activeProfile, stage: stage)
                }
            }
            .navigationDestination(for: InterviewSession.self) { session in
                ReplayDetailView(session: session)
            }
        }
        .onAppear {
            profiles.forEach { $0.ensureProfileID() }
            try? modelContext.save()
            if profiles.isEmpty {
                showOnboarding = true
            }
        }
        .task(id: poolRefillToken) {
            guard let activeProfile, activeProfile.isComplete else { return }
            poolRefillTask?.cancel()
            poolRefillTask = Task {
                await QuestionPoolManager().ensurePoolFilled(profile: activeProfile, context: modelContext)
            }
        }
        .onDisappear {
            poolRefillTask?.cancel()
        }
    }

    private var poolRefillToken: String? {
        guard let activeProfile, activeProfile.isComplete else { return nil }
        return "\(activeProfile.profileID?.uuidString ?? "")-\(ProfileFingerprint.make(for: activeProfile))"
    }

    private func handleOnboardingDismiss() {
        guard let activeProfile, activeProfile.isComplete else { return }
        poolRefillTask?.cancel()
        poolRefillTask = Task {
            await QuestionPoolManager().ensurePoolFilled(profile: activeProfile, context: modelContext)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("화상면접 연습")
                .font(.largeTitle.bold())
            Text("지원 회사별 프로필을 전환하며 단계별 면접 훈련을 진행합니다.")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("프로필이 없습니다", systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text("지원 회사, 직무, 채용공고, 이력서 정보를 입력해 주세요.")
        } actions: {
            Button("프로필 추가") {
                showOnboarding = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func profileSummary(_ profile: CandidateProfile) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("현재 프로필")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(profile.displayTitle)
                            .font(.title3.bold())
                    }
                    Spacer()
                    if profiles.count > 1 {
                        Button("전환") {
                            showProfileManagement = true
                        }
                        .buttonStyle(.bordered)
                    }
                }

                LabeledContent("회사", value: profile.company)
                LabeledContent("산업", value: profile.industry)
                LabeledContent("직무", value: profile.role)

                if profiles.count > 1 {
                    Text("등록된 프로필 \(profiles.count)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stageSelection(for profile: CandidateProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("훈련 단계")
                .font(.title2.bold())

            ForEach(SessionStage.allCases) { stage in
                StageCard(
                    stage: stage,
                    isEnabled: stage.isAvailableInMVP && profile.isComplete
                ) {
                    navigationPath.append(stage)
                }
            }

            if !profile.sessions.isEmpty {
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
                                HStack(spacing: 8) {
                                    Text(session.stage.displayName)
                                        .font(.headline)
                                    if let grade = session.overallGrade, let score = session.overallScore {
                                        Text("\(grade.displayName) · \(score)점")
                                            .font(.caption.bold())
                                            .foregroundStyle(grade.accentColor)
                                    }
                                }
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

            let scoredSessions = ProgressChartDataBuilder.scoredSessions(from: profile)
            if scoredSessions.count >= 2 {
                Divider()
                    .padding(.vertical, 8)
                ProgressChartView(sessions: scoredSessions)
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
        .environment(ActiveProfileStore())
        .modelContainer(for: [CandidateProfile.self, InterviewSession.self, QuestionRecord.self, CachedQuestion.self], inMemory: true)
}
