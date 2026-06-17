import SwiftUI

struct InterviewScheduleCard: View {
    let profile: CandidateProfile
    let onEdit: () -> Void

    var body: some View {
        GroupBox {
            if let interviewDate = profile.interviewDate,
               let countdown = profile.interviewCountdown,
               countdown.isActive {
                activeCountdown(interviewDate: interviewDate, countdown: countdown)
            } else if profile.interviewDate != nil {
                expiredSchedule
            } else {
                emptySchedule
            }
        }
    }

    private func activeCountdown(interviewDate: Date, countdown: InterviewCountdown) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("면접 일정", systemImage: "calendar.badge.clock")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(countdown.headline)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(InterviewCountdownStyle.accentColor(for: countdown))
                    Text(countdown.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(InterviewScheduleFormatting.dateTime(interviewDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("수정", action: onEdit)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var expiredSchedule: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("면접 일정")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("지난 일정입니다")
                    .font(.headline)
                Text("새 면접 일정을 등록해 주세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("다시 설정", action: onEdit)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var emptySchedule: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("면접 일정")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("일정이 등록되지 않았습니다")
                    .font(.headline)
                Text("D-Day 카운트다운과 준비 알림을 받을 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("등록", action: onEdit)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
