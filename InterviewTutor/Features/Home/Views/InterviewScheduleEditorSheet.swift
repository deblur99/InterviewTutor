import SwiftData
import SwiftUI

struct InterviewScheduleEditorSheet: View {
    @Bindable var profile: CandidateProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var interviewDate: Date
    @State private var hasSchedule: Bool
    @State private var notificationDenied = false

    private var previewCountdown: InterviewCountdown {
        InterviewCountdown.from(interviewDate: interviewDate)
    }

    private var isDateInvalid: Bool {
        hasSchedule && interviewDate <= .now
    }

    init(profile: CandidateProfile) {
        self.profile = profile
        let existing = profile.interviewDate ?? Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        _interviewDate = State(initialValue: existing)
        _hasSchedule = State(initialValue: profile.interviewDate != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileHeader
                    scheduleToggleSection

                    if hasSchedule {
                        datePickerSection
                        countdownPreviewSection
                        notificationSection

                        if isDateInvalid {
                            validationBanner
                        }
                    } else {
                        disabledHintSection
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("면접 일정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task { await save() }
                    }
                    .disabled(isDateInvalid)
                }
            }
            .alert("알림 권한 필요", isPresented: $notificationDenied) {
                Button("확인") { dismiss() }
            } message: {
                Text("면접 준비 알림을 받으려면 시스템 설정에서 면접도우미 알림을 허용해 주세요.")
            }
        }
        .frame(minWidth: 480, minHeight: 420)
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(profile.displayTitle)
                .font(.title2.bold())
            Text("\(profile.company) · \(profile.role)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var scheduleToggleSection: some View {
        GroupBox {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("면접 일정 사용")
                        .font(.headline)
                    Text("D-Day 카운트다운과 준비 알림을 받습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $hasSchedule)
                    .toggleStyle(.switch)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    private var datePickerSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("면접 일시")
                    .font(.headline)

                DatePicker(
                    "면접 일시",
                    selection: $interviewDate,
                    in: Date.now...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.field)
                .labelsHidden()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private var countdownPreviewSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("카운트다운 미리보기")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(previewCountdown.headline)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(InterviewCountdownStyle.accentColor(for: previewCountdown))

                    Text(previewCountdown.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(InterviewScheduleFormatting.dateTime(interviewDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private var notificationSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("알림 일정", systemImage: "bell.badge")
                    .font(.subheadline.bold())

                notificationRow(
                    period: "D-7 ~ D-1",
                    time: "매일 오전 9시",
                    detail: "한 문장 준비 메시지"
                )
                notificationRow(
                    period: "D-Day",
                    time: "오전 6시",
                    detail: "면접 응원 메시지"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private func notificationRow(period: String, time: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(period)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(time)
                    .font(.subheadline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var disabledHintSection: some View {
        GroupBox {
            Label {
                Text("면접 일정을 켜면 홈 화면에 D-Day가 표시되고, 준비 알림을 예약할 수 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private var validationBanner: some View {
        Label("면접 일시는 현재 시각 이후로 설정해 주세요.", systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private func save() async {
        profile.ensureProfileID()

        if hasSchedule {
            profile.interviewDate = interviewDate
        } else {
            profile.interviewDate = nil
            if let profileID = profile.profileID {
                InterviewNotificationScheduler.shared.cancelAll(for: profileID)
            }
        }

        try? modelContext.save()

        if hasSchedule {
            await InterviewNotificationScheduler.shared.reschedule(for: profile)
            let authorized = await InterviewNotificationScheduler.shared.requestAuthorizationIfNeeded()
            if !authorized {
                notificationDenied = true
                return
            }
        }

        dismiss()
    }
}

enum InterviewCountdownStyle {
    static func accentColor(for countdown: InterviewCountdown) -> Color {
        switch countdown.status {
        case .today:
            .orange
        case .upcoming(let days, _) where days <= 3:
            .orange
        case .upcoming:
            .accentColor
        case .past:
            .secondary
        }
    }
}
