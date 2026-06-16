import AVFoundation
import Foundation

enum CoachThresholds {
    static let silenceSeconds: TimeInterval = 4
    static let gazeAwaySeconds: TimeInterval = 2
    static let hintCooldown: TimeInterval = 20
    static let keywordCheckDelay: TimeInterval = 15
    static let keywordCoverageMinimum: Double = 0.4
    static let fillerBurstDelta = 2
    static let audioRMSThreshold: Float = 0.015
}

@MainActor
@Observable
final class SessionCoachMonitor {
    var isCoachEnabled = true
    var isHUDEnabled = false
    private(set) var activeHint: CoachHint?
    private(set) var liveFillerCount = 0
    private(set) var keywordCoveragePercent = 0
    private(set) var gazePercent = 100
    private(set) var isMonitoring = false

    private let streamingRecognizer = StreamingSpeechRecognizer()
    private var keywords: [String] = []
    private var partialTranscript = ""
    private var answerStartedAt: Date?
    private var lastSpeechAt: Date?
    private var gazeAwayStartedAt: Date?
    private var lastGazeSampleAt: Date?
    private var gazeHits = 0
    private var gazeSamples = 0
    private var previousFillerCount = 0
    private var lastHintShownAt: [CoachHintKind: Date] = [:]
    private var speechAuthorized = false
    private var capturedTranscript = ""

    func configure(speechAuthorized: Bool, defaultCoachEnabled: Bool = true, defaultHUDEnabled: Bool) {
        self.speechAuthorized = speechAuthorized
        isCoachEnabled = defaultCoachEnabled
        isHUDEnabled = defaultHUDEnabled
    }

    func setCoachEnabled(_ enabled: Bool) {
        isCoachEnabled = enabled
        if !enabled {
            activeHint = nil
        }
    }

    func setHUDEnabled(_ enabled: Bool) {
        isHUDEnabled = enabled
    }

    func startAnswering(keywords: [String]) async {
        resetMonitoringMetrics()
        self.keywords = keywords
        isMonitoring = true
        answerStartedAt = .now
        lastSpeechAt = .now
        capturedTranscript = ""

        guard speechAuthorized else { return }

        do {
            try await streamingRecognizer.start { [weak self] transcript in
                Task { @MainActor in
                    self?.handlePartialTranscript(transcript)
                }
            }
        } catch {
            // Streaming unavailable — silence/gaze hints still work.
        }
    }

    func stopAnswering() async {
        capturedTranscript = await streamingRecognizer.stop()
        isMonitoring = false
        activeHint = nil
        resetMonitoringMetrics()
    }

    func consumeLastTranscript() -> String {
        let transcript = capturedTranscript
        capturedTranscript = ""
        return transcript
    }

    nonisolated func processVideoSample(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = LiveGazeMonitor.pixelBuffer(from: sampleBuffer) else { return }

        Task { @MainActor in
            guard self.isMonitoring else { return }

            let result = LiveGazeMonitor.sampleIfNeeded(
                pixelBuffer: pixelBuffer,
                lastSampleTime: self.lastGazeSampleAt
            )
            guard let snapshot = result.snapshot else { return }

            self.lastGazeSampleAt = result.nextSampleTime
            self.handleGazeSample(snapshot)
        }
    }

    nonisolated func processAudioSample(_ sampleBuffer: CMSampleBuffer) {
        let level = AudioLevelMonitor.rms(from: sampleBuffer)
        streamingRecognizer.append(sampleBuffer)

        Task { @MainActor in
            guard self.isMonitoring else { return }
            self.handleAudioLevel(level)
        }
    }

    private func handlePartialTranscript(_ transcript: String) {
        partialTranscript = transcript
        capturedTranscript = transcript
        let report = FillerWordAnalyzer.analyze(transcript)
        liveFillerCount = report.totalCount

        let coverage = KeywordCoverageTracker.coverage(keywords: keywords, transcript: transcript)
        keywordCoveragePercent = Int((coverage * 100).rounded())

        if liveFillerCount - previousFillerCount >= CoachThresholds.fillerBurstDelta {
            presentHint(.filler)
        }
        previousFillerCount = liveFillerCount

        if let answerStartedAt,
           Date().timeIntervalSince(answerStartedAt) >= CoachThresholds.keywordCheckDelay,
           coverage < CoachThresholds.keywordCoverageMinimum,
           !keywords.isEmpty {
            presentHint(.keywords)
        }
    }

    private func handleAudioLevel(_ level: Float) {
        let now = Date()
        if level >= CoachThresholds.audioRMSThreshold {
            lastSpeechAt = now
            return
        }

        guard let lastSpeechAt else {
            self.lastSpeechAt = now
            return
        }

        if now.timeIntervalSince(lastSpeechAt) >= CoachThresholds.silenceSeconds {
            presentHint(.silence)
        }
    }

    private func handleGazeSample(_ snapshot: LiveGazeSnapshot) {
        gazeSamples += 1
        if snapshot.isGazing == true {
            gazeHits += 1
            gazeAwayStartedAt = nil
        } else if snapshot.isGazing == false {
            if gazeAwayStartedAt == nil {
                gazeAwayStartedAt = snapshot.sampledAt
            } else if let gazeAwayStartedAt,
                      snapshot.sampledAt.timeIntervalSince(gazeAwayStartedAt) >= CoachThresholds.gazeAwaySeconds {
                presentHint(.gaze)
            }
        }

        if gazeSamples > 0 {
            gazePercent = Int((Double(gazeHits) / Double(gazeSamples) * 100).rounded())
        }
    }

    private func presentHint(_ kind: CoachHintKind) {
        guard isCoachEnabled else { return }

        let now = Date()
        if let lastShown = lastHintShownAt[kind],
           now.timeIntervalSince(lastShown) < CoachThresholds.hintCooldown {
            return
        }

        lastHintShownAt[kind] = now
        activeHint = CoachHint(kind: kind)

        Task {
            try? await Task.sleep(for: .seconds(5))
            if activeHint?.kind == kind {
                activeHint = nil
            }
        }
    }

    private func resetMonitoringMetrics() {
        keywords = []
        partialTranscript = ""
        answerStartedAt = nil
        lastSpeechAt = nil
        gazeAwayStartedAt = nil
        lastGazeSampleAt = nil
        gazeHits = 0
        gazeSamples = 0
        previousFillerCount = 0
        liveFillerCount = 0
        keywordCoveragePercent = 0
        gazePercent = 100
    }
}
