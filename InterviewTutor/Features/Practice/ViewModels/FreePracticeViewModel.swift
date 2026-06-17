import AVFoundation
import Foundation
import SwiftData

enum FreePracticePhase: Equatable {
    case preparing
    case questionTTS
    case pauseBeforeAnswer
    case answering
    case analyzingQuestion
    case questionFeedback
    case analyzingSession
    case completed
}

@Observable
@MainActor
final class FreePracticeViewModel {
    let profile: CandidateProfile
    private(set) var configuration: FreePracticeConfiguration

    private(set) var phase: FreePracticePhase = .preparing
    private(set) var questions: [GeneratedQuestion] = []
    private(set) var currentIndex = 0
    private(set) var timerState: SessionTimerState = .idle
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private(set) var isLoadingQuestions = false
    private(set) var needsQuestionRegeneration = false
    private(set) var isAnalyzing = false
    private(set) var analysisProgress = ""
    private(set) var errorMessage: String?
    private(set) var completedSession: InterviewSession?
    private(set) var feedbackRecord: QuestionRecord?
    private(set) var completedRecords: [QuestionRecord] = []

    private let cameraManager = CameraManager()
    private let interviewerVoice = InterviewerVoice()
    private let speechRecognizer = SpeechRecognizer()
    private let questionBuilder = FreePracticeQuestionBuilder()
    private let feedbackGenerator = FeedbackGenerator()
    private let contentScorer = ContentScorer()

    private var timerTask: Task<Void, Never>?
    private var sessionID = UUID()
    private var videoURL: URL?
    private var questionIDMap: [Int: UUID] = [:]
    private var feedbackContinuation: CheckedContinuation<Void, Never>?
    private var modelContext: ModelContext?
    private var configurationUpdateTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var preparationGeneration = 0
    private var lastPreparedConfiguration: FreePracticeConfiguration?
    private var skipsRemainingGrace = false

    init(profile: CandidateProfile, configuration: FreePracticeConfiguration? = nil) {
        self.profile = profile
        self.configuration = configuration ?? profile.freePracticeConfiguration
    }

    var currentQuestion: GeneratedQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var progressLabel: String {
        guard !questions.isEmpty else { return "" }
        return "\(min(currentIndex + 1, questions.count)) / \(questions.count)"
    }

    func clearError() {
        errorMessage = nil
    }

    func noteConfigurationChange(_ configuration: FreePracticeConfiguration) {
        guard !isLoadingQuestions else { return }

        self.configuration = configuration

        guard configuration.isValid else {
            questions = []
            lastPreparedConfiguration = nil
            needsQuestionRegeneration = false
            errorMessage = "연습 항목을 하나 이상 선택해 주세요."
            return
        }

        errorMessage = nil
        needsQuestionRegeneration = lastPreparedConfiguration == nil
            || configuration != lastPreparedConfiguration
    }

    func generateQuestions(context: ModelContext) async {
        needsQuestionRegeneration = false
        await applyConfigurationUpdate(configuration, context: context)
    }

    func persistConfiguration(context: ModelContext) {
        profile.freePracticeConfiguration = configuration
        try? context.save()
    }

    func cancelPendingUpdates() {
        configurationUpdateTask?.cancel()
        configurationUpdateTask = nil
        preparationTask?.cancel()
        preparationTask = nil
    }

    func cancelQuestionGeneration() {
        cancelPendingUpdates()
        preparationGeneration += 1
        isLoadingQuestions = false

        if questions.isEmpty || configuration != lastPreparedConfiguration {
            needsQuestionRegeneration = true
        }
    }

    func moveQuestions(from source: IndexSet, to destination: Int) {
        var updated = questions
        let movingItems = source.sorted().map { updated[$0] }
        for index in source.sorted(by: >) {
            updated.remove(at: index)
        }

        var targetIndex = destination
        for index in source where index < destination {
            targetIndex -= 1
        }

        updated.insert(contentsOf: movingItems, at: min(max(targetIndex, 0), updated.count))
        questions = updated
        rebuildQuestionIDMap()
    }

    func addCustomQuestion(topic: String, question: String, expectedAnswer: String) {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExpected = expectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else { return }

        let custom = GeneratedQuestion(
            questionText: trimmedQuestion,
            promptKeywords: trimmedExpected.isEmpty ? trimmedTopic : trimmedExpected,
            recommendedSeconds: 120,
            category: .comprehensive,
            topicLabel: trimmedTopic.isEmpty ? "추가 질문" : trimmedTopic,
            expectedAnswer: trimmedExpected.isEmpty ? nil : trimmedExpected
        )
        questions.append(custom)
        rebuildQuestionIDMap()
        errorMessage = nil
    }

    private func rebuildQuestionIDMap() {
        questionIDMap = Dictionary(uniqueKeysWithValues: questions.enumerated().map { ($0.offset, $0.element.id) })
    }

    private func applyConfigurationUpdate(_ configuration: FreePracticeConfiguration, context: ModelContext) async {
        preparationTask?.cancel()
        self.configuration = configuration
        modelContext = context

        guard configuration.isValid else {
            questions = []
            lastPreparedConfiguration = nil
            errorMessage = "연습 항목을 하나 이상 선택해 주세요."
            isLoadingQuestions = false
            return
        }

        if configuration == lastPreparedConfiguration, !questions.isEmpty {
            errorMessage = nil
            needsQuestionRegeneration = false
            return
        }

        preparationTask = Task {
            await prepareQuestions()
        }
        await preparationTask?.value
    }

    func updateConfiguration(_ configuration: FreePracticeConfiguration, context: ModelContext) async {
        await applyConfigurationUpdate(configuration, context: context)
    }

    func prepareQuestions() async {
        guard configuration.isValid else {
            errorMessage = "연습 항목을 하나 이상 선택해 주세요."
            return
        }

        preparationGeneration += 1
        let generation = preparationGeneration
        isLoadingQuestions = true
        defer {
            if generation == preparationGeneration {
                isLoadingQuestions = false
            }
        }

        guard !Task.isCancelled else { return }

        let built = await questionBuilder.buildQuestions(profile: profile, configuration: configuration)

        guard !Task.isCancelled, generation == preparationGeneration else { return }

        questions = built
        currentIndex = 0
        rebuildQuestionIDMap()
        if !questions.isEmpty {
            lastPreparedConfiguration = configuration
            needsQuestionRegeneration = false
            errorMessage = nil
        }
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startPractice(context: ModelContext) async {
        modelContext = context
        sessionID = UUID()
        videoURL = VideoStorageManager.newVideoURL(sessionID: sessionID)
        completedRecords = []
        feedbackRecord = nil

        guard let videoURL, !questions.isEmpty else {
            errorMessage = "연습 질문이 없습니다."
            return
        }

        do {
            try await cameraManager.startRecording(to: videoURL)
            await runQuestion(at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acknowledgeFeedback() {
        feedbackContinuation?.resume()
        feedbackContinuation = nil
    }

    func skipToNext() {
        skipsRemainingGrace = true
        timerTask?.cancel()
        timerState = .finished
    }

    func cleanup() async {
        timerTask?.cancel()
        interviewerVoice.stop()
        await cameraManager.stopRecording()
        await cameraManager.stopSession()
    }

    private func runQuestion(at index: Int) async {
        currentIndex = index
        guard let question = currentQuestion, let questionID = questionIDMap[index] else {
            await finishPractice()
            return
        }

        phase = .questionTTS
        await interviewerVoice.speak(question.questionText)

        phase = .pauseBeforeAnswer
        try? await Task.sleep(for: .seconds(1.5))

        phase = .answering
        await cameraManager.markSegmentStart(questionID: questionID)
        startTimer(duration: TimeInterval(question.recommendedSeconds))
        await waitForTimerCompletion(extraGrace: 3)
        _ = await cameraManager.markSegmentEnd(questionID: questionID)

        await analyzeCurrentQuestion(question: question, questionID: questionID, orderIndex: index)
    }

    private func analyzeCurrentQuestion(
        question: GeneratedQuestion,
        questionID: UUID,
        orderIndex: Int
    ) async {
        phase = .analyzingQuestion
        isAnalyzing = true
        analysisProgress = "답변 분석 중..."

        guard let videoURL else {
            isAnalyzing = false
            return
        }

        let segments = await cameraManager.segments()
        let segment = segments.first { $0.questionID == questionID }

        let record = QuestionRecord(
            questionID: questionID,
            orderIndex: orderIndex,
            category: question.category,
            questionText: question.questionText,
            promptKeywords: question.promptKeywords,
            startTimestamp: segment?.startTime ?? 0,
            endTimestamp: segment?.endTime ?? 0,
            recommendedSeconds: question.recommendedSeconds
        )

        let speechAuthorized = await speechRecognizer.requestAuthorization()
        if speechAuthorized, let segment, segment.duration > 0.3 {
            do {
                let transcript = try await speechRecognizer.transcribeSegment(
                    from: videoURL,
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )
                record.transcribedAnswer = transcript
                let fillerReport = FillerWordAnalyzer.analyze(transcript)
                record.fillerWordCount = fillerReport.totalCount
                record.aiFeedback = await feedbackGenerator.generateFeedbackForQuestion(
                    record,
                    fillerReport: fillerReport,
                    stage: .freePractice
                )
                let duration = segment.duration
                record.speechScore = SpeechScorer.score(
                    transcript: transcript,
                    fillerCount: fillerReport.totalCount,
                    duration: duration,
                    recommendedSeconds: question.recommendedSeconds
                )
                record.contentScore = await contentScorer.score(
                    question: record,
                    transcript: transcript,
                    stage: .freePractice
                )
            } catch {
                do {
                    let transcript = try await speechRecognizer.transcribeSegment(
                        from: videoURL,
                        startTime: max(0, segment.startTime - 0.5),
                        endTime: segment.endTime + 0.5,
                        locale: Locale(identifier: "ko-KR")
                    )
                    if !transcript.isEmpty {
                        record.transcribedAnswer = transcript
                        let fillerReport = FillerWordAnalyzer.analyze(transcript)
                        record.fillerWordCount = fillerReport.totalCount
                        record.aiFeedback = await feedbackGenerator.generateFeedbackForQuestion(
                            record,
                            fillerReport: fillerReport,
                            stage: .freePractice
                        )
                        let duration = segment.duration
                        record.speechScore = SpeechScorer.score(
                            transcript: transcript,
                            fillerCount: fillerReport.totalCount,
                            duration: duration,
                            recommendedSeconds: question.recommendedSeconds
                        )
                        record.contentScore = await contentScorer.score(
                            question: record,
                            transcript: transcript,
                            stage: .freePractice
                        )
                    } else {
                        record.aiFeedback = "음성 인식에 실패했습니다. 답변 음성이 너무 작거나 녹음 구간이 짧을 수 있습니다."
                    }
                } catch {
                    record.aiFeedback = "음성 인식에 실패했습니다. 답변 음성이 너무 작거나 녹음 구간이 짧을 수 있습니다."
                }
            }
        } else if !speechAuthorized {
            record.aiFeedback = "음성 인식 권한이 없어 피드백을 생성하지 못했습니다."
        }

        completedRecords.append(record)
        feedbackRecord = record
        phase = .questionFeedback
        isAnalyzing = false

        await waitForFeedbackAcknowledgement()
        feedbackRecord = nil

        let nextIndex = orderIndex + 1
        if nextIndex < questions.count {
            await runQuestion(at: nextIndex)
        } else {
            await finishPractice()
        }
    }

    private func finishPractice() async {
        phase = .analyzingSession
        isAnalyzing = true
        analysisProgress = "연습 종합 피드백 생성 중..."

        let recordedURL = await cameraManager.stopRecording()
        await cameraManager.stopSession()

        let summary = await feedbackGenerator.generatePracticeSummary(
            questions: completedRecords,
            configuration: configuration
        )

        let session = InterviewSession(
            stage: .freePractice,
            videoFilePath: recordedURL.map { VideoStorageManager.relativePath(for: $0) } ?? "",
            expectedQuestionCount: questions.count,
            expectedDurationSeconds: completedRecords.reduce(0) {
                $0 + Int($1.endTimestamp - $1.startTimestamp)
            },
            sessionIndex: profile.sessions.count + 1,
            summaryFeedback: summary,
            profile: profile,
            questions: completedRecords
        )

        if let scoringSummary = SessionScoringEngine.summarize(questions: completedRecords) {
            SessionScoringEngine.applySessionScores(to: session, summary: scoringSummary)
        }

        profile.sessions.append(session)
        completedSession = session
        isAnalyzing = false
        phase = .completed
    }

    private func waitForFeedbackAcknowledgement() async {
        await withCheckedContinuation { continuation in
            feedbackContinuation = continuation
        }
    }

    private func waitForTimerCompletion(extraGrace: TimeInterval) async {
        while timerState != .finished {
            try? await Task.sleep(for: .milliseconds(100))
        }
        if skipsRemainingGrace {
            skipsRemainingGrace = false
            return
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
}
