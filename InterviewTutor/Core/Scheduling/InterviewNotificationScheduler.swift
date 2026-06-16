import Foundation
import UserNotifications

@MainActor
final class InterviewNotificationScheduler {
    static let shared = InterviewNotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let dailyHour = 9
    private let dDayHour = 6

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    func reschedule(for profile: CandidateProfile) async {
        guard let profileID = profile.profileID else { return }
        cancelAll(for: profileID)

        guard let interviewDate = profile.interviewDate else { return }
        let countdown = InterviewCountdown.from(interviewDate: interviewDate)
        guard countdown.isActive else { return }

        guard await requestAuthorizationIfNeeded() else { return }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)

        for daysRemaining in 1...7 {
            guard let tip = InterviewPrepGuide.tip(for: daysRemaining) else { continue }
            guard let notifyDay = calendar.date(byAdding: .day, value: -daysRemaining, to: calendar.startOfDay(for: interviewDate)) else {
                continue
            }
            guard notifyDay >= startOfToday else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: notifyDay)
            components.hour = dailyHour
            components.minute = 0

            await schedule(
                identifier: Self.dailyID(profileID: profileID, daysRemaining: daysRemaining),
                title: "면접 준비 D-\(daysRemaining)",
                body: tip.notificationMessage,
                components: components
            )
        }

        var dDayComponents = calendar.dateComponents([.year, .month, .day], from: interviewDate)
        dDayComponents.hour = dDayHour
        dDayComponents.minute = 0

        if let dDayDate = calendar.date(from: dDayComponents), dDayDate > .now {
            await schedule(
                identifier: Self.dDayID(profileID: profileID),
                title: "오늘 면접 응원",
                body: InterviewPrepGuide.dDayEncouragement,
                components: dDayComponents
            )
        }
    }

    func cancelAll(for profileID: UUID) {
        let identifiers = (1...7).map { Self.dailyID(profileID: profileID, daysRemaining: $0) }
            + [Self.dDayID(profileID: profileID)]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func schedule(
        identifier: String,
        title: String,
        body: String,
        components: DateComponents
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try? await center.add(request)
    }

    private static func dailyID(profileID: UUID, daysRemaining: Int) -> String {
        "interview.\(profileID.uuidString).daily.\(daysRemaining)"
    }

    private static func dDayID(profileID: UUID) -> String {
        "interview.\(profileID.uuidString).dday"
    }
}
