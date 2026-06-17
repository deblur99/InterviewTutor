import AVFoundation
import Foundation

enum CameraError: Error, LocalizedError {
    case permissionDenied
    case deviceUnavailable
    case configurationFailed
    case microphoneUnavailable
    case writerFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "카메라 또는 마이크 권한이 필요합니다."
        case .deviceUnavailable: "카메라를 찾을 수 없습니다."
        case .configurationFailed: "카메라 설정에 실패했습니다."
        case .microphoneUnavailable: "마이크를 사용할 수 없습니다. 시스템 설정에서 마이크 접근을 확인해 주세요."
        case .writerFailed: "녹화 파일 생성에 실패했습니다."
        }
    }
}

nonisolated final class CameraManager: NSObject, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.interviewtutor.camera.session")
    private nonisolated(unsafe) var captureSession: AVCaptureSession?
    private nonisolated(unsafe) var videoInput: AVCaptureDeviceInput?
    private nonisolated(unsafe) var audioInput: AVCaptureDeviceInput?
    private nonisolated(unsafe) var videoOutput: AVCaptureVideoDataOutput?
    private nonisolated(unsafe) var audioOutput: AVCaptureAudioDataOutput?
    private nonisolated(unsafe) var previewLayer: AVCaptureVideoPreviewLayer?
    private nonisolated(unsafe) var recorder: VideoRecorder?
    private nonisolated(unsafe) var lastRecordingSegments: [RecordingSegment] = []
    private nonisolated(unsafe) var videoSampleHandler: (@Sendable (CMSampleBuffer) -> Void)?
    private nonisolated(unsafe) var audioSampleHandler: (@Sendable (CMSampleBuffer) -> Void)?

    private var isConfigured = false

    func requestPermissions() async -> Bool {
        let cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        let micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        return cameraGranted && micGranted
    }

    func configure() async throws {
        try await QueueConfined.run(on: queue) {
            try self.configureOnQueue()
        }
    }

    func startSession() async throws {
        try await QueueConfined.run(on: queue) {
            guard let session = self.captureSession else { throw CameraError.configurationFailed }
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stopSession() async {
        await QueueConfined.run(on: queue) {
            self.captureSession?.stopRunning()
        }
    }

    func makePreviewLayer() async -> AVCaptureVideoPreviewLayer? {
        await QueueConfined.run(on: queue) {
            guard let session = self.captureSession else { return nil }
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            self.previewLayer = layer
            return layer
        }
    }

    func startRecording(to url: URL) async throws {
        try await QueueConfined.run(on: queue) {
            guard let session = self.captureSession else { throw CameraError.configurationFailed }
            let recorder = VideoRecorder(outputURL: url)
            try recorder.prepare(with: session)
            self.recorder = recorder
            self.lastRecordingSegments = []
            recorder.start(at: CMClockGetTime(CMClockGetHostTimeClock()))
        }
    }

    func stopRecording() async -> URL? {
        await QueueConfined.run(on: queue) {
            guard let recorder = self.recorder else { return nil }
            self.lastRecordingSegments = recorder.segments
            let url = recorder.stop()
            self.recorder = nil
            return url
        }
    }

    func markSegmentStart(questionID: UUID) async {
        await QueueConfined.run(on: queue) {
            self.recorder?.markSegmentStart(questionID: questionID)
        }
    }

    func markSegmentEnd(questionID: UUID) async -> RecordingSegment? {
        await QueueConfined.run(on: queue) {
            self.recorder?.markSegmentEnd(questionID: questionID)
        }
    }

    func currentRecordingTime() async -> TimeInterval {
        await QueueConfined.run(on: queue) {
            self.recorder?.currentTime ?? 0
        }
    }

    func segments() async -> [RecordingSegment] {
        await QueueConfined.run(on: queue) {
            self.recorder?.segments ?? self.lastRecordingSegments
        }
    }

    func setSampleHandlers(
        onVideo: (@Sendable (CMSampleBuffer) -> Void)? = nil,
        onAudio: (@Sendable (CMSampleBuffer) -> Void)? = nil
    ) async {
        await QueueConfined.run(on: queue) {
            self.videoSampleHandler = onVideo
            self.audioSampleHandler = onAudio
        }
    }

    private func configureOnQueue() throws {
        guard !isConfigured else { return }

        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video) else {
            throw CameraError.deviceUnavailable
        }

        let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        guard session.canAddInput(videoDeviceInput) else { throw CameraError.configurationFailed }
        session.addInput(videoDeviceInput)
        videoInput = videoDeviceInput

        if let audioDevice = Self.defaultAudioCaptureDevice() {
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            guard session.canAddInput(audioDeviceInput) else {
                throw CameraError.microphoneUnavailable
            }
            session.addInput(audioDeviceInput)
            audioInput = audioDeviceInput
        } else if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            throw CameraError.microphoneUnavailable
        }

        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(videoDataOutput) else { throw CameraError.configurationFailed }
        session.addOutput(videoDataOutput)
        videoOutput = videoDataOutput

        if audioInput != nil {
            let audioDataOutput = AVCaptureAudioDataOutput()
            audioDataOutput.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(audioDataOutput) else {
                throw CameraError.microphoneUnavailable
            }
            session.addOutput(audioDataOutput)
            audioOutput = audioDataOutput
        }

        session.commitConfiguration()
        captureSession = session
        isConfigured = true
    }

    private static func defaultAudioCaptureDevice() -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(for: .audio) {
            return device
        }

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return discoverySession.devices.first
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        recorder?.append(sampleBuffer: sampleBuffer, from: output)

        if output is AVCaptureVideoDataOutput {
            videoSampleHandler?(sampleBuffer)
        } else if output is AVCaptureAudioDataOutput {
            audioSampleHandler?(sampleBuffer)
        }
    }
}
