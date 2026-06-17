import AVFoundation
import Foundation

@MainActor
final class InterviewerVoice {
    private let synthesizer = AVSpeechSynthesizer()
    private let speechDelegate: SpeechDelegate
    private var continuation: CheckedContinuation<Void, Never>?

    init() {
        let delegate = SpeechDelegate()
        speechDelegate = delegate
        delegate.owner = self
        synthesizer.delegate = delegate
    }

    func speak(_ text: String, tone: InterviewerTone = .neutral, language: String = "ko-KR") async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation

            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: language)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * tone.speechRateMultiplier
            utterance.pitchMultiplier = tone.pitchMultiplier

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
