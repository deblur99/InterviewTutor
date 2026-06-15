import Foundation

enum SessionPhase: Equatable {
    case preSession
    case selfIntro
    case questionTTS
    case pauseBeforeAnswer
    case answering
    case closing
    case analyzing
    case postSession
}

enum SessionTimerState: Equatable {
    case idle
    case running(remaining: TimeInterval)
    case finished
}
