import AVFoundation
import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class SessionViewModel {
    let profile: CandidateProfile
    let stage: SessionStage
    private(set) var expertConfiguration: ExpertSessionConfiguration?

    private(set) var phase: SessionPhase = .preSession
    private(set) var questionFlow = QuestionFlowViewModel()
    private(set) var timerState: SessionTimerState = .idle
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private(set) var isLoadingQuestions = false
    private(set) var isLoadingFromPool = false
    private(set) var needsQuestionRegeneration = false
    private(set) var isAnalyzing = false
    private(set) var analysisProgress = ""
    private(set) var errorMessage: String?
    private(set) var completedSession: InterviewSession?
    private(set) var isSessionPaused = false
    private(set) var currentPrompterContent: AnswerPrompterContent?
    private(set) var isGeneratingPrompter = false

    let coachMonitor = SessionCoachMonitor()

    private let cameraManager = CameraManager()
    private let interviewerVoice = InterviewerVoice()
    private let speechRecognizer = SpeechRecognizer()
    private let questionPoolManager = QuestionPoolManager()
    private let feedbackGenerator = FeedbackGenerator()
    private let followUpGenerator = FollowUpQuestionGenerator()
    private let segmentVisionAnalyzer = SegmentVisionAnalyzer()
    private let contentScorer = ContentScorer()
    private let answerPrompterGenerator = AnswerPrompterGenerator()

    private var timerTask: Task<Void, Never>?
    private var sessionID = UUID()
    private var videoURL: URL?
    private var questionIDMap: [Int: UUID] = [:]
    private var reservedPoolQuestionIDs: [UUID] = []
    private var sessionStarted = false
    private var modelContext: ModelContext?
    private var configurationUpdateTask: Task<Void, Never>?
    private var questionPreparationTask: Task<Void, Never>?
    private var preparationGeneration = 0
    private var lastPreparedExpertConfiguration: ExpertSessionConfiguration?
    private var sessionTask: Task<Void, Never>?
    private var skipsRemainingGrace = false

    init(profile: CandidateProfile, stage: SessionStage, expertConfiguration: ExpertSessionConfiguration? = nil) {
        self.profile = profile
        self.stage = stage
        self.expertConfiguration = stage == .expert ? (expertConfiguration ?? profile.expertSessionConfiguration) : nil
    }

    private var interviewerTone: InterviewerTone {
        expertConfiguration?.interviewerTone ?? .neutral
    }

    private var preAnswerPause: TimeInterval {
        stage == .expert ? interviewerTone.preAnswerPauseSeconds : 1.5
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

    var showsSessionControls: Bool {
        switch phase {
        case .preparingPrompter, .selfIntro, .questionTTS, .pauseBeforeAnswer, .answering, .closing:
            true
        default:
            false
        }
    }

    var showsCameraPrompterHUD: Bool {
        phase.isAnsweringPhase && currentPrompterContent != nil
    }

    func pauseSession() {
        guard showsSessionControls, !isSessionPaused else { return }
        isSessionPaused = true
        interviewerVoice.stop()
        if case .running(let remaining) = timerState {
            timerState = .paused(remaining: remaining)
        }
    }

    func resumeSession() {
        guard isSessionPaused else { return }
        isSessionPaused = false
        if case .paused(let remaining) = timerState {
            timerState = .running(remaining: remaining)
        }
    }

    func exitSession(context: ModelContext) async {
        sessionTask?.cancel()
        sessionTask = nil
        isSessionPaused = false
        timerTask?.cancel()
        timerState = .idle
        interviewerVoice.stop()
        await endAnswerMonitoring()

        if !reservedPoolQuestionIDs.isEmpty {
            questionPoolManager.releaseReserved(
                questionIDs: reservedPoolQuestionIDs,
                profile: profile,
                context: context
            )
            reservedPoolQuestionIDs = []
        }

        if let videoURL {
            try? FileManager.default.removeItem(at: videoURL)
            self.videoURL = nil
        }

        await cameraManager.stopRecording()
        await cameraManager.stopSession()
    }

    func updateExpertConfiguration(_ configuration: ExpertSessionConfiguration, context: ModelContext) async {
        await applyExpertConfiguration(configuration, context: context)
    }

    func scheduleExpertConfigurationUpdate(_ configuration: ExpertSessionConfiguration, context: ModelContext) {
        markExpertQuestionsStale(configuration, context: context)
    }

    func markExpertQuestionsStale(_ configuration: ExpertSessionConfiguration, context: ModelContext) {
        guard !isLoadingQuestions else { return }

        expertConfiguration = configuration
        modelContext = context

        guard lastPreparedExpertConfiguration != nil || !questionFlow.questions.isEmpty else {
            needsQuestionRegeneration = true
            return
        }

        if configuration.questionGenerationToken != lastPreparedExpertConfiguration?.questionGenerationToken {
            needsQuestionRegeneration = true
        }
    }

    func syncExpertPresentationSettings(_ configuration: ExpertSessionConfiguration) {
        expertConfiguration = configuration
    }

    func generateExpertQuestions(context: ModelContext) async {
        guard stage == .expert, let configuration = expertConfiguration else { return }
        needsQuestionRegeneration = false
        await applyExpertConfiguration(configuration, context: context)
    }

    func cancelQuestionGeneration() {
        configurationUpdateTask?.cancel()
        configurationUpdateTask = nil
        questionPreparationTask?.cancel()
        questionPreparationTask = nil
        preparationGeneration += 1
        isLoadingQuestions = false
        isLoadingFromPool = false

        if questionFlow.questions.isEmpty
            || expertConfiguration?.questionGenerationToken != lastPreparedExpertConfiguration?.questionGenerationToken {
            needsQuestionRegeneration = true
        }
    }

    func prepareExpertIfNeeded(_ configuration: ExpertSessionConfiguration, context: ModelContext) async {
        needsQuestionRegeneration = false
        await applyExpertConfiguration(configuration, context: context)
    }

    func persistExpertConfiguration(_ configuration: ExpertSessionConfiguration, context: ModelContext) {
        guard stage == .expert else { return }
        profile.expertSessionConfiguration = configuration
        try? context.save()
    }

    func cancelPendingConfigurationUpdates() {
        configurationUpdateTask?.cancel()
        configurationUpdateTask = nil
        questionPreparationTask?.cancel()
        questionPreparationTask = nil
    }

    private func applyExpertConfiguration(_ configuration: ExpertSessionConfiguration, context: ModelContext) async {
        guard stage == .expert else { return }

        questionPreparationTask?.cancel()
        expertConfiguration = configuration

        if configuration.questionGenerationToken == lastPreparedExpertConfiguration?.questionGenerationToken,
           !questionFlow.questions.isEmpty {
            needsQuestionRegeneration = false
            return
        }

        releaseReservedQuestions(context: context)

        questionPreparationTask = Task {
            await prepareQuestions(context: context)
        }
        await questionPreparationTask?.value

        if !Task.isCancelled, !questionFlow.questions.isEmpty {
            lastPreparedExpertConfiguration = configuration
            needsQuestionRegeneration = false
        }
    }

    private func speakQuestion(_ text: String) async {
        await interviewerVoice.speak(text, tone: interviewerTone)
    }

    private func answerDuration(for question: GeneratedQuestion) -> TimeInterval {
        if stage == .expert, let config = expertConfiguration {
            return TimeInterval(config.adjustedSeconds(question.recommendedSeconds, category: question.category))
        }
        return TimeInterval(question.recommendedSeconds)
    }

    func clearError() {
        errorMessage = nil
    }

    private var poolThresholdForLoadingIndicator: Int {
        switch stage {
        case .beginner, .skilled:
            stage.preset.documentQuestionCount
        case .expert:
            expertConfiguration?.documentQuestionCount ?? ExpertSessionConfiguration.default.documentQuestionCount
        case .freePractice:
            0
        }
    }

    func prepareQuestions(context: ModelContext) async {
        modelContext = context

        preparationGeneration += 1
        let generation = preparationGeneration
        isLoadingQuestions = true
        isLoadingFromPool = questionPoolManager.unusedCount(for: profile, stage: stage)
            >= poolThresholdForLoadingIndicator
        defer {
            if generation == preparationGeneration {
                isLoadingQuestions = false
                isLoadingFromPool = false
            }
        }

        guard !Task.isCancelled else { return }

        let sessionSet = await questionPoolManager.prepareSessionQuestions(
            profile: profile,
            stage: stage,
            expertConfiguration: expertConfiguration,
            context: context
        )

        guard !Task.isCancelled, generation == preparationGeneration else { return }

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
        sessionTask = Task {
            await performSession()
        }
        await sessionTask?.value
    }

    private func performSession() async {
        sessionStarted = true
        sessionID = UUID()
        videoURL = VideoStorageManager.newVideoURL(sessionID: sessionID)

        guard let videoURL else { return }

        do {
            try await cameraManager.startRecording(to: videoURL)
            guard !Task.isCancelled else { return }
            phase = .selfIntro
            await runSelfIntro()
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func runSelfIntro() async {
        guard !Task.isCancelled else { return }
        guard let question = currentQuestion, let questionID = questionIDMap[questionFlow.currentIndex] else { return }

        await preparePrompter(for: question)
        guard !Task.isCancelled else { return }

        phase = .questionTTS
        await speakQuestion(question.questionText)
        guard !Task.isCancelled else { return }

        phase = .pauseBeforeAnswer
        await sleepUnlessPaused(for: preAnswerPause)
        guard !Task.isCancelled else { return }

        phase = .selfIntro
        await cameraManager.markSegmentStart(questionID: questionID)
        await beginAnswerMonitoring()
        startTimer(duration: answerDuration(for: question))
        await waitForTimerCompletion(extraGrace: 2)
        guard !Task.isCancelled else { return }
        await endAnswerMonitoring()
        _ = await cameraManager.markSegmentEnd(questionID: questionID)

        if questionFlow.advance() {
            await runQuestionLoop()
        }
    }

    private func runQuestionLoop() async {
        while let question = currentQuestion, questionFlow.currentIndex < questionFlow.totalCount - 1 {
            guard !Task.isCancelled else { return }

            await preparePrompter(for: question)
            guard !Task.isCancelled else { return }

            phase = .questionTTS
            await speakQuestion(question.questionText)
            guard !Task.isCancelled else { return }

            phase = .pauseBeforeAnswer
            await sleepUnlessPaused(for: preAnswerPause)
            guard !Task.isCancelled else { return }

            guard let questionID = questionIDMap[questionFlow.currentIndex] else { break }
            let answeredIndex = questionFlow.currentIndex

            phase = .answering
            await cameraManager.markSegmentStart(questionID: questionID)
            await beginAnswerMonitoring()
            startTimer(duration: answerDuration(for: question))
            await waitForTimerCompletion(extraGrace: 5)
            guard !Task.isCancelled else { return }
            await endAnswerMonitoring()
            _ = await cameraManager.markSegmentEnd(questionID: questionID)

            await maybeInsertFollowUp(afterIndex: answeredIndex, parentQuestion: question)
            guard !Task.isCancelled else { return }

            if !questionFlow.advance() { break }
        }

        guard !Task.isCancelled else { return }
        await runClosing()
    }

    private func maybeInsertFollowUp(afterIndex index: Int, parentQuestion: GeneratedQuestion) async {
        let generatesFollowUps = stage == .expert
            ? (expertConfiguration?.generatesFollowUps ?? true)
            : stage.preset.generatesFollowUps
        guard generatesFollowUps else { return }

        let eligibleParent: Bool
        switch parentQuestion.category {
        case .documentBased:
            eligibleParent = true
        case .technical:
            eligibleParent = stage == .expert
        default:
            eligibleParent = false
        }
        guard eligibleParent else { return }

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
        guard !Task.isCancelled else { return }
        guard let question = currentQuestion, let questionID = questionIDMap[questionFlow.currentIndex] else { return }

        await preparePrompter(for: question)
        guard !Task.isCancelled else { return }

        phase = .questionTTS
        await speakQuestion(question.questionText)
        guard !Task.isCancelled else { return }

        phase = .pauseBeforeAnswer
        await sleepUnlessPaused(for: preAnswerPause)
        guard !Task.isCancelled else { return }

        phase = .closing
        await cameraManager.markSegmentStart(questionID: questionID)
        await beginAnswerMonitoring()
        startTimer(duration: answerDuration(for: question))
        await waitForTimerCompletion(extraGrace: 10)
        guard !Task.isCancelled else { return }
        await endAnswerMonitoring()
        _ = await cameraManager.markSegmentEnd(questionID: questionID)

        await finishSession()
    }

    func skipToNext() {
        isSessionPaused = false
        skipsRemainingGrace = true
        timerTask?.cancel()
        timerState = .finished
    }

    private func waitForTimerCompletion(extraGrace: TimeInterval) async {
        while timerState != .finished {
            guard !Task.isCancelled else { return }
            while isSessionPaused {
                try? await Task.sleep(for: .milliseconds(100))
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard !Task.isCancelled else { return }
        while isSessionPaused {
            try? await Task.sleep(for: .milliseconds(100))
        }
        if skipsRemainingGrace {
            skipsRemainingGrace = false
            return
        }
        try? await Task.sleep(for: .seconds(extraGrace))
    }

    private func preparePrompter(for question: GeneratedQuestion) async {
        phase = .preparingPrompter
        isGeneratingPrompter = true
        currentPrompterContent = await answerPrompterGenerator.generate(
            profile: profile,
            question: question,
            stage: stage
        )
        isGeneratingPrompter = false
        guard !Task.isCancelled else { return }

        while isSessionPaused {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func sleepUnlessPaused(for duration: TimeInterval) async {
        var elapsed: TimeInterval = 0
        while elapsed < duration {
            guard !Task.isCancelled else { return }
            while isSessionPaused {
                try? await Task.sleep(for: .milliseconds(100))
            }
            try? await Task.sleep(for: .milliseconds(100))
            elapsed += 0.1
        }
    }

    private func startTimer(duration: TimeInterval) {
        timerTask?.cancel()
        timerState = .running(remaining: duration)

        timerTask = Task {
            var remaining = duration
            while remaining > 0 {
                guard !Task.isCancelled else { return }
                while isSessionPaused {
                    try? await Task.sleep(for: .milliseconds(100))
                }
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
                timerState = .running(remaining: max(0, remaining))
            }
            timerState = .finished
        }
    }

    private func finishSession() async {
        await endAnswerMonitoring()
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
                    do {
                        transcript = try await speechRecognizer.transcribeSegment(
                            from: recordedURL,
                            startTime: max(0, segment.startTime - 0.5),
                            endTime: segment.endTime + 0.5
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
                        record.aiFeedback = "음성 인식에 실패했습니다. 답변 음성이 너무 작거나 녹음 구간이 짧을 수 있습니다."
                    }
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
        sessionTask?.cancel()
        sessionTask = nil
        isSessionPaused = false
        if let context {
            releaseReservedQuestions(context: context)
        } else if let modelContext {
            releaseReservedQuestions(context: modelContext)
        }
        timerTask?.cancel()
        interviewerVoice.stop()
        await endAnswerMonitoring()
        await cameraManager.setSampleHandlers()
        await cameraManager.stopRecording()
        await cameraManager.stopSession()
    }
}
