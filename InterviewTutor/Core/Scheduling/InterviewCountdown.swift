import Foundation

enum InterviewCountdownStatus: Equatable {
    case upcoming(days: Int, hours: Int)
    case today(hours: Int)
    case past
}

struct InterviewCountdown: Equatable {
    let interviewDate: Date
    let status: InterviewCountdownStatus

    var isActive: Bool {
        status != .past
    }

    var showsPrepTips: Bool {
        switch status {
        case .upcoming(let days, _):
            (1...7).contains(days)
        case .today:
            false
        case .past:
            false
        }
    }

    var daysRemainingForTips: Int? {
        switch status {
        case .upcoming(let days, _) where (1...7).contains(days):
            days
        default:
            nil
        }
    }

    var headline: String {
        switch status {
        case .upcoming(let days, _):
            "D-\(days)"
        case .today:
            "D-Day"
        case .past:
            "면접 일자 지남"
        }
    }

    var detail: String {
        switch status {
        case .upcoming(let days, let hours):
            if hours > 0 {
                "\(days)일 \(hours)시간 남음"
            } else {
                "\(days)일 남음"
            }
        case .today(let hours):
            if hours > 0 {
                "오늘 · \(hours)시간 남음"
            } else {
                "오늘 면접입니다"
            }
        case .past:
            "일정을 업데이트해 주세요"
        }
    }

    static func from(interviewDate: Date, now: Date = .now) -> InterviewCountdown {
        let interval = interviewDate.timeIntervalSince(now)
        guard interval > 0 else {
            return InterviewCountdown(interviewDate: interviewDate, status: .past)
        }

        let totalHours = Int(interval / 3600)
        let days = totalHours / 24
        let hours = totalHours % 24

        if days == 0 {
            return InterviewCountdown(interviewDate: interviewDate, status: .today(hours: hours))
        }

        return InterviewCountdown(
            interviewDate: interviewDate,
            status: .upcoming(days: days, hours: hours)
        )
    }
}

extension CandidateProfile {
    var interviewCountdown: InterviewCountdown? {
        guard let interviewDate else { return nil }
        return InterviewCountdown.from(interviewDate: interviewDate)
    }
}
