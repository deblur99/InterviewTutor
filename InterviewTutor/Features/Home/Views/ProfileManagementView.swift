import SwiftData
import SwiftUI

struct ProfileManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ActiveProfileStore.self) private var activeProfileStore

    @Query(sort: \CandidateProfile.updatedAt, order: .reverse) private var profiles: [CandidateProfile]

    @State private var showAddProfile = false
    @State private var profileToEdit: CandidateProfile?
    @State private var profileToDelete: CandidateProfile?
    @State private var poolRefillTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if profiles.isEmpty {
                    emptyState
                } else {
                    profileList
                }
            }
            .navigationTitle("프로필 관리")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem {
                    Button {
                        showAddProfile = true
                    } label: {
                        Label("프로필 추가", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddProfile, onDismiss: refillPoolForActiveProfile) {
                OnboardingFlowView(mode: .create) { savedProfile in
                    activeProfileStore.select(savedProfile)
                }
            }
            .sheet(item: $profileToEdit, onDismiss: refillPoolForActiveProfile) { profile in
                OnboardingFlowView(profile: profile, mode: .edit) { savedProfile in
                    activeProfileStore.select(savedProfile)
                }
            }
            .alert("프로필 삭제", isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            )) {
                Button("삭제", role: .destructive) {
                    if let profileToDelete {
                        deleteProfile(profileToDelete)
                    }
                }
                Button("취소", role: .cancel) {
                    profileToDelete = nil
                }
            } message: {
                if let profileToDelete {
                    Text("'\(profileToDelete.displayTitle)' 프로필과 연결된 세션·질문 풀 데이터가 모두 삭제됩니다.")
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("등록된 프로필 없음", systemImage: "person.2")
        } description: {
            Text("지원 회사별 프로필을 추가해 면접 연습을 관리하세요.")
        } actions: {
            Button("프로필 추가") {
                showAddProfile = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var profileList: some View {
        List {
            Section {
                ForEach(profiles) { profile in
                    ProfileRow(
                        profile: profile,
                        isActive: activeProfileStore.isActive(profile),
                        onSelect: {
                            switchToProfile(profile)
                        },
                        onEdit: {
                            profileToEdit = profile
                        }
                    )
                    .contextMenu {
                        Button("이 프로필로 전환") {
                            switchToProfile(profile)
                        }
                        Button("수정") {
                            profileToEdit = profile
                        }
                        Divider()
                        Button("삭제", role: .destructive) {
                            profileToDelete = profile
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("삭제", role: .destructive) {
                            profileToDelete = profile
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button("전환") {
                            switchToProfile(profile)
                        }
                        .tint(.accentColor)
                    }
                }
            } header: {
                Text("등록된 프로필 \(profiles.count)개")
            } footer: {
                Text("프로필을 선택하면 홈 화면과 면접 세션이 해당 지원 정보 기준으로 전환됩니다.")
            }
        }
    }

    private func switchToProfile(_ profile: CandidateProfile) {
        activeProfileStore.select(profile)
        refillPoolForActiveProfile()
    }

    private func deleteProfile(_ profile: CandidateProfile) {
        activeProfileStore.clearSelectionIfDeleted(profile)
        modelContext.delete(profile)
        try? modelContext.save()
        profileToDelete = nil
    }

    private func refillPoolForActiveProfile() {
        guard let profile = activeProfileStore.activeProfile(in: profiles), profile.isComplete else { return }
        poolRefillTask?.cancel()
        poolRefillTask = Task {
            await QuestionPoolManager().ensurePoolFilled(profile: profile, context: modelContext)
        }
    }
}

private struct ProfileRow: View {
    let profile: CandidateProfile
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            Text(profile.displaySubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let countdown = profile.interviewCountdown, countdown.isActive {
                                Text("·")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(countdown.headline)
                                    .font(.caption.bold())
                                    .foregroundStyle(InterviewCountdownStyle.accentColor(for: countdown))
                            }
                        }
                        HStack(spacing: 8) {
                            Label("\(profile.sessions.count)회 연습", systemImage: "video")
                            if profile.isComplete {
                                Label("완료", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Label("미완료", systemImage: "exclamationmark.circle")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isActive {
                        Label("사용 중", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("프로필 수정")
        }
    }
}

#Preview {
    ProfileManagementView()
        .environment(ActiveProfileStore())
        .modelContainer(for: [CandidateProfile.self, InterviewSession.self, QuestionRecord.self, CachedQuestion.self], inMemory: true)
}
