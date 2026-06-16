import AVFoundation
import AppKit
import Foundation
import SwiftData
import SwiftUI

@Observable
final class SessionViewModel {
    let profile: CandidateProfile
    let stage: SessionStage

    private(set) var phase: SessionPhase = .preSession
    private(set) var questionFlow = QuestionFlowViewModel()
    private(set) var timerState: SessionTimerState = .idle
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private(set) var isLoadingQuestions = false
    private(set) var isLoadingFromPool = false
    private(set) var isAnalyzing = false
    private(set) var analysisProgress = ""
    private(set) var errorMessage: String?
    private(set) var completedSession: InterviewSession?

    let coachMonitor = SessionCoachMonitor()
    private let hudController = PrompterHUDController()

    private let cameraManager = CameraManager()
    private let interviewerVoice = InterviewerVoice()
    private let speechRecognizer = SpeechRecognizer()
    private let questionPoolManager = QuestionPoolManager()
    private let feedbackGenerator = FeedbackGenerator()
    private let followUpGenerator = FollowUpQuestionGenerator()
    private let segmentVisionAnalyzer = SegmentVisionAnalyzer()
    private let contentScorer = ContentScorer()

    private var timerTask: Task<Void, Never>?
    private var sessionID = UUID()
    private var videoURL: URL?
    private var questionIDMap: [Int: UUID] = [:]
    private var reservedPoolQuestionIDs: [UUID] = []
    private var sessionStarted = false
    private var modelContext: ModelContext?

    init(profile: CandidateProfile, stage: SessionStage) {
        self.profile = profile
        self.stage = stage
    }

    var currentQuestion: GeneratedQuestion? {
        questionFlow.currentQuestion
    }

    var currentKeywords: [String] {
        currentQuestion?.promptKeywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }

    var isCoachEnabled: Bool {
        get { coachMonitor.isCoachEnabled }
        set { coachMonitor.setCoachEnabled(newValue) }
    }

    var isHUDEnabled: Bool {
        get { coachMonitor.isHUDEnabled }
        set { coachMonitor.setHUDEnabled(newValue) }
    }

    var activeCoachHint: CoachHint? {
        guard isCoachEnabled else { return nil }
        return coachMonitor.activeHint
    }

    var hudState: PrompterHUDState {
        PrompterHUDState(
            isVisible: coachMonitor.isHUDEnabled && stage == .beginner && phase.isAnsweringPhase,
            keywords: currentKeywords,
            fillerCount: coachMonitor.liveFillerCount,
            keywordCoveragePercent: coachMonitor.keywordCoveragePercent,
            gazePercent: coachMonitor.gazePercent
        )
    }

    func updateHUD(anchorWindow: NSWindow?) {
        hudController.update(state: hudState, anchorWindow: anchorWindow)
    }

    func hideHUD() {
        hudController.hide()
    }

    func clearError() {
        errorMessage = nil
    }

    func prepareQuestions(context: ModelContext) async {
        modelContext = context
        isLoadingQuestions = true
        isLoadingFromPool = questionPoolManager.unusedCount(for: profile, stage: stage)
            >= stage.preset.documentQuestionCount
        defer {
            isLoadingQuestions = false
            isLoadingFromPool = false
        }

        let sessionSet = await questionPoolManager.prepareSessionQuestions(
            profile: profile,
            stage: stage,
            context: context
        )
        questionFlow.setQuestions(sessionSet.questions)
        reservedPoolQuestionIDs = sessionSet.reservedDocumentQuestionIDs
        questionIDMap = Dictionary(
            uniqueKeysWithValues: sessionSet.questions.enumerated().map { ($0.offset, $0.element.id) }
        )
    }

    func releaseReservedQuestions(context: ModelContext) {
        guard !sessionStarted, !reservedPoolQuestionIDs.isEmpty else { return }
        questionPoolManager.releaseReserved(
            questionIDs: reservedPoolQuestionIDs,
            profile: profile,
            context: context
        )
        reservedPoolQuestionIDs = []
    }

    func setupCamera() async {
        let granted = await cameraManager.requestPermissions()
        guard granted else {
            errorMessage = CameraError.permissionDenied.localizedDescription
            return
        }

        do {
            try await cameraManager.configure()
            try await cameraManager.startSession()
            previewLayer = await cameraManager.makePreviewLayer()
            await configureLiveCoach()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func configureLiveCoach() async {
        let speechAuthorized = await speechRecognizer.requestAuthorization()
        coachMonitor.configure(
            speechAuthorized: speechAuthorized,
            defaultCoachEnabled: stage.coachEnabledByDefault,
            defaultHUDEnabled: stage.coachHUDEnabledByDefault
        )

        let monitor = coachMonitor
        await cameraManager.setSampleHandlers(
            onVideo: { sampleBuffer in
                monitor.processVideoSample(sampleBuffer)
            },
            onAudio: { sampleBuffer in
                monitor.processAudioSample(sampleBuffer)
            }
        )
    }

    private func beginAnswerMonitoring() async {
        await coachMonitor.startAnswering(keywords: currentKeywords)
    }

    private func endAnswerMonitoring() async {
        await coachMonitor.stopAnswering()
    }

    func startSession() async {
        sessionStarted = true
        sessionID = UUID()
        videoURL = VideoStorageManager.newVideoURL(sessionID: sessionID)

        guard let videoURL else { return }

        do {
            try await cameraManager.startRecording(to: videoURL)
            phase = .selfIntro
            await runSelfIntro()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runSelfIntro() async {
        guard let question = currentQuestion, let questionID = questionIDMap[questionFlow.currentIndex] else { return }

        phase = .questionTTS
        await interviewerVoice.speak(question.questionText)

        phase = .pauseBeforeAnswer
        try? await Task.sleep(for: .seconds(1.5))

        phase = .selfIntro
        await cameraManager.markSegmentStart(questionID: questionID)
        await beginAnswerMonitoring()
        startTimer(duration: TimeInterval(question.recommendedSeconds))
        await waitForTimerCompletion(extraGrace: 2)
        await endAnswerMonitoring()
        _ = await cameraManager.markSegmentEnd(questionID: questionID)

        if questionFlow.advance() {
            await runQuestionLoop()
        }
    }

    private func runQuestionLoop() async {
        while let question = currentQuestion, questionFlow.currentIndex < questionFlow.totalCount - 1 {
            phase = .questionTTS
            await interviewerVoice.speak(question.questionText)

            phase = .pauseBeforeAnswer
            try? await Task.sleep(for: .seconds(1.5))

            guard let questionID = questionIDMap[questionFlow.currentIndex] else { break }
            let answeredIndex = questionFlow.currentIndex

            phase = .answering
            await cameraManager.markSegmentStart(questionID: questionID)
            await beginAnswerMonitoring()
            startTimer(duration: TimeInterval(question.recommendedSeconds))
            await waitForTimerCompletion(extraGrace: 5)
            await endAnswerMonitoring()
            _ = await cameraManager.markSegmentEnd(questionID: questionID)

            await maybeInsertFollowUp(afterIndex: answeredIndex, parentQuestion: question)

            if !questionFlow.advance() { break }
        }

        await runClosing()
    }

    private func maybeInsertFollowUp(afterIndex index: Int, parentQuestion: GeneratedQuestion) async {
        guard stage.preset.generatesFollowUps,
              parentQuestion.category == .documentBased else { return }

        let transcript = coachMonitor.consumeLastTranscript()
        let followUp = await followUpGenerator.generate(
            profile: profile,
            parentQuestion: parentQuestion,
            answerTranscript: transcript
        )
        questionFlow.insertFollowUp(followUp, afterIndex: index)
        reindexQuestionIDMap()
    }

    private func reindexQuestionIDMap() {
        questionIDMap = Dictionary(
            uniqueKeysWithValues: questionFlow.questions.enumerated().map { ($0.offset, $0.element.id) }
        )
    }

    private func runClosing() async {
        guard let question = currentQuestion, let questionID = questionIDMap[questionFlow.currentIndex] else { return }

        phase = .questionTTS
        await interviewerVoice.speak(question.questionText)

        phase = .pauseBeforeAnswer
        try? await Task.sleep(for: .seconds(1.5))

        phase = .closing
        await cameraManager.markSegmentStart(questionID: questionID)
        await beginAnswerMonitoring()
        startTimer(duration: TimeInterval(question.recommendedSeconds))
        await waitForTimerCompletion(extraGrace: 10)
        await endAnswerMonitoring()
        _ = await cameraManager.markSegmentEnd(questionID: questionID)

        await finishSession()
    }

    func skipToNext() async {
        timerTask?.cancel()
        timerState = .finished
    }

    private func waitForTimerCompletion(extraGrace: TimeInterval) async {
        while timerState != .finished {
            try? await Task.sleep(for: .milliseconds(100))
        }
        try? await Task.sleep(for: .seconds(extraGrace))
    }

    private func startTimer(duration: TimeInterval) {
        timerTask?.cancel()
        timerState = .running(remaining: duration)

        timerTask = Task {
            var remaining = duration
            while remaining > 0 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
                timerState = .running(remaining: max(0, remaining))
            }
            timerState = .finished
        }
    }

    private func finishSession() async {
        await endAnswerMonitoring()
        hideHUD()
        phase = .analyzing
        isAnalyzing = true

        let recordedURL = await cameraManager.stopRecording()
        await cameraManager.stopSession()

        guard let recordedURL else {
            errorMessage = "녹화 파일을 저장하지 못했습니다."
            isAnalyzing = false
            return
        }

        let segments = await cameraManager.segments()
        let questions = buildQuestionRecords(segments: segments)

        let speechAuthorized = await speechRecognizer.requestAuthorization()

        for (index, record) in questions.enumerated() {
            analysisProgress = "답변 분석 중 (\(index + 1)/\(questions.count))..."

            guard let segment = segments.first(where: { $0.questionID == record.questionID }),
                  segment.duration > 0.5 else { continue }

            async let visionTask = segmentVisionAnalyzer.analyzeSegment(
                videoURL: recordedURL,
                startTime: segment.startTime,
                endTime: segment.endTime
            )

            var transcript = ""
            var fillerCount = 0

            if speechAuthorized {
                do {
                    transcript = try await speechRecognizer.transcribeSegment(
                        from: recordedURL,
                        startTime: segment.startTime,
                        endTime: segment.endTime
                    )
                    record.transcribedAnswer = transcript
                    let fillerReport = FillerWordAnalyzer.analyze(transcript)
                    fillerCount = fillerReport.totalCount
                    record.fillerWordCount = fillerCount
                    record.aiFeedback = await feedbackGenerator.generateFeedbackForQuestion(
                        record,
                        fillerReport: fillerReport,
                        stage: stage
                    )
                } catch {
                    record.aiFeedback = "음성 인식에 실패했습니다. 마이크 설정을 확인해 주세요."
                }
            }

            let postureMetrics = await visionTask
            let duration = segment.duration
            let speechScore = SpeechScorer.score(
                transcript: transcript,
                fillerCount: fillerCount,
                duration: duration,
                recommendedSeconds: record.recommendedSeconds
            )
            let contentScore = await contentScorer.score(question: record, transcript: transcript, stage: stage)
            let postureScore = PostureScorer.score(metrics: postureMetrics)

            SessionScoringEngine.applyQuestionScores(
                to: record,
                speechScore: speechScore,
                contentScore: contentScore,
                postureScore: postureScore,
                metrics: postureMetrics
            )
        }

        let sessionIndex = profile.sessions.count + 1
        let session = InterviewSession(
            stage: stage,
            videoFilePath: VideoStorageManager.relativePath(for: recordedURL),
            expectedQuestionCount: questionFlow.totalCount,
            expectedDurationSeconds: questionFlow.expectedDurationSeconds,
            sessionIndex: sessionIndex,
            profile: profile,
            questions: questions
        )

        if let summary = SessionScoringEngine.summarize(questions: questions) {
            SessionScoringEngine.applySessionScores(to: session, summary: summary)
        }

        profile.sessions.append(session)
        if let modelContext {
            questionPoolManager.markAnswered(
                questionIDs: reservedPoolQuestionIDs,
                profile: profile,
                context: modelContext
            )
            Task {
                await questionPoolManager.ensurePoolFilled(profile: profile, stage: stage, context: modelContext)
            }
        }
        reservedPoolQuestionIDs = []
        completedSession = session
        isAnalyzing = false
        phase = .postSession
    }

    private func buildQuestionRecords(segments: [RecordingSegment]) -> [QuestionRecord] {
        questionFlow.questions.enumerated().map { index, question in
            let questionID = questionIDMap[index] ?? question.id
            let segment = segments.first { $0.questionID == questionID }

            return QuestionRecord(
                questionID: questionID,
                orderIndex: index,
                category: questionFlow.category(for: index),
                questionText: question.questionText,
                promptKeywords: question.promptKeywords,
                startTimestamp: segment?.startTime ?? 0,
                endTimestamp: segment?.endTime ?? 0,
                recommendedSeconds: question.recommendedSeconds
            )
        }
    }

    func cleanup(context: ModelContext? = nil) async {
        if let context {
            releaseReservedQuestions(context: context)
        } else if let modelContext {
            releaseReservedQuestions(context: modelContext)
        }
        timerTask?.cancel()
        interviewerVoice.stop()
        await endAnswerMonitoring()
        hideHUD()
        await cameraManager.setSampleHandlers()
        await cameraManager.stopRecording()
        await cameraManager.stopSession()
    }
}
