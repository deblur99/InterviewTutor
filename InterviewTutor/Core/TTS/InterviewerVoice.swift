import AVFoundation
import Foundation

@MainActor
final class InterviewerVoice {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    func speak(_ text: String, language: String = "ko-KR") async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation

            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: language)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
            utterance.pitchMultiplier = 1.0

            synthesizer.delegate = SpeechDelegate(owner: self)
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        resumeContinuation()
    }

    fileprivate func resumeContinuation() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    weak var owner: InterviewerVoice?

    init(owner: InterviewerVoice) {
        self.owner = owner
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            owner?.resumeContinuation()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            owner?.resumeContinuation()
        }
    }
}
