import AVFoundation
import AudioToolbox
import OSLog

final class AudioRecordingCoordinator: AudioRecordingCoordinatorType {
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: AudioRecordingCoordinator.self))

    private let configuration: RecordingConfiguration
    private let microphoneCapture: (any MicrophoneCaptureType)?
    private let processTap: ProcessTap?
    private let systemWideTap: SystemWideTap?

    private var isRunning = false
    private var tapRecorder: (any AudioTapRecorderType)?

    // VAD components
    @MainActor private var vadTranscriptionCoordinator: VADTranscriptionCoordinator?
    @MainActor private var streamingTranscriptionService: StreamingTranscriptionService?
    @MainActor private var systemVADManager: VADManager?
    
    init(
        configuration: RecordingConfiguration,
        microphoneCapture: (any MicrophoneCaptureType)?,
        processTap: ProcessTap? = nil,
        systemWideTap: SystemWideTap? = nil
    ) {
        self.configuration = configuration
        self.microphoneCapture = microphoneCapture
        self.processTap = processTap
        self.systemWideTap = systemWideTap
    }
    
    func start() async throws {
        guard !isRunning else { return }
        
        let expectedFiles = configuration.expectedFiles
        
        if let systemAudioURL = expectedFiles.systemAudioURL {
            if let systemWideTap = systemWideTap {
                let recorder = SystemWideTapRecorder(fileURL: systemAudioURL, tap: systemWideTap)
                self.tapRecorder = recorder

                try await MainActor.run {
                    try recorder.start()
                }
                logger.info("System-wide audio recording started: \(systemAudioURL.lastPathComponent)")
            } else if let processTap = processTap {
                let recorder = ProcessTapRecorder(fileURL: systemAudioURL, tap: processTap)
                self.tapRecorder = recorder

                try await MainActor.run {
                    try recorder.start()
                }
                logger.info("Process-specific audio recording started: \(systemAudioURL.lastPathComponent)")
            }
        }
        
        if let microphoneURL = expectedFiles.microphoneURL,
           let microphoneCapture = microphoneCapture {

            let tapStreamDescription: AudioStreamBasicDescription
            if let systemWideTap = systemWideTap {
                await MainActor.run {
                    systemWideTap.activate()
                }
                guard let streamDesc = systemWideTap.tapStreamDescription else {
                    throw AudioCaptureError.coreAudioError("System-wide tap stream description not available")
                }
                tapStreamDescription = streamDesc
            } else if let processTap = processTap {
                await MainActor.run {
                    processTap.activate()
                }
                guard let streamDesc = processTap.tapStreamDescription else {
                    throw AudioCaptureError.coreAudioError("Process tap stream description not available")
                }
                tapStreamDescription = streamDesc
            } else {
                throw AudioCaptureError.coreAudioError("No audio tap available")
            }
            
            try microphoneCapture.start(outputURL: microphoneURL, targetFormat: tapStreamDescription)
            logger.info("Microphone recording started: \(microphoneURL.lastPathComponent)")
        }
        
        isRunning = true
        logger.info("Recording started with configuration: \(self.configuration.id)")
    }
    
    func stop() {
        guard isRunning else { return }
        
        microphoneCapture?.stop()
        tapRecorder?.stop()

        if let systemWideTap = systemWideTap {
            systemWideTap.invalidate()
        } else if let processTap = processTap {
            processTap.invalidate()
        }

        isRunning = false
        tapRecorder = nil
        
        logger.info("Recording stopped for configuration: \(self.configuration.id)")
    }
    
    var currentMicrophoneLevel: Float {
        microphoneCapture?.audioLevel ?? 0.0
    }
    
    var currentSystemAudioLevel: Float {
        if let systemWideTap = systemWideTap {
            return systemWideTap.audioLevel
        } else if let processTap = processTap {
            return processTap.audioLevel
        }
        return 0.0
    }
    
    var hasDualAudio: Bool {
        configuration.enableMicrophone && microphoneCapture != nil
    }
    
    var recordedFiles: RecordedFiles {
        configuration.expectedFiles
    }

    // MARK: - VAD Properties

    @MainActor
    var isVADEnabled: Bool {
        var enabled = false

        if let microphoneCapture = microphoneCapture as? MicrophoneCapture {
            enabled = enabled || microphoneCapture.isVADEnabled
        }

        if let systemVADManager = systemVADManager {
            enabled = enabled || systemVADManager.isVADEnabled
        }

        return enabled
    }

    @MainActor
    var currentSpeechProbability: Float {
        var probabilities: [Float] = []

        if let microphoneCapture = microphoneCapture as? MicrophoneCapture {
            probabilities.append(microphoneCapture.currentSpeechProbability)
        }

        if let systemVADManager = systemVADManager {
            probabilities.append(systemVADManager.speechProbability)
        }

        return probabilities.max() ?? 0.0
    }

    @MainActor
    var isSpeaking: Bool {
        var speaking = false

        if let microphoneCapture = microphoneCapture as? MicrophoneCapture {
            speaking = speaking || microphoneCapture.isSpeaking
        }

        if let systemVADManager = systemVADManager {
            speaking = speaking || systemVADManager.isSpeaking
        }

        return speaking
    }

    // MARK: - VAD Methods

    @MainActor
    func enableVAD(configuration: VADConfiguration? = nil, delegate: VADTranscriptionCoordinatorDelegate? = nil, recordingID: String? = nil) async {
        let vadConfig = configuration ?? .default

        if streamingTranscriptionService == nil {
            logger.warning("StreamingTranscriptionService not initialized - VAD transcription will not work")
        }

        if let streamingService = streamingTranscriptionService {
            if vadTranscriptionCoordinator == nil {
                vadTranscriptionCoordinator = VADTranscriptionCoordinator(streamingTranscriptionService: streamingService)
            }
        }

        guard let coordinator = vadTranscriptionCoordinator else {
            logger.warning("Cannot enable VAD: streaming transcription service unavailable")
            return
        }

        coordinator.delegate = delegate

        if let microphoneCapture = microphoneCapture as? MicrophoneCapture {
            await microphoneCapture.setupVAD(
                configuration: vadConfig,
                delegate: coordinator
            )

            await microphoneCapture.enableVAD()
        }

        await setupSystemAudioVAD(with: vadConfig, coordinator: coordinator)

        // Start VAD with recording ID if provided
        if let recordingID = recordingID {
            coordinator.startVADTranscription(for: recordingID)
        } else {
            coordinator.startVADTranscription()
        }

        logger.info("VAD enabled for audio recording coordinator")
    }

    @MainActor
    func disableVAD() async {
        if let microphoneCapture = microphoneCapture as? MicrophoneCapture {
            microphoneCapture.disableVAD()
        }

        systemVADManager?.disable()
        detachSystemAudioVAD()
        systemVADManager = nil

        vadTranscriptionCoordinator?.stopVADTranscription()
        vadTranscriptionCoordinator = nil

        logger.info("VAD disabled for audio recording coordinator")
    }

    @MainActor
    func pauseVAD() async {
        if let microphoneCapture = microphoneCapture as? MicrophoneCapture {
            microphoneCapture.pauseVAD()
        }

        systemVADManager?.pause()
    }

    @MainActor
    func resumeVAD() async {
        if let microphoneCapture = microphoneCapture as? MicrophoneCapture {
            microphoneCapture.resumeVAD()
        }

        systemVADManager?.resume()
    }
    
    @MainActor
    func getVADTranscriptions() async -> [StreamingTranscriptionSegment] {
        return vadTranscriptionCoordinator?.realtimeTranscriptions ?? []
    }
    
    @MainActor
    func getVADSegments(for recordingID: String) async -> [VADAudioSegment] {
        return vadTranscriptionCoordinator?.getAccumulatedSegments(for: recordingID) ?? []
    }
    
    @MainActor
    func getVADTranscriptionCoordinator() -> VADTranscriptionCoordinator? {
        return vadTranscriptionCoordinator
    }

    // MARK: - Dependency Injection for VAD

    @MainActor
    func setStreamingTranscriptionService(_ service: StreamingTranscriptionService) {
        self.streamingTranscriptionService = service
        logger.info("StreamingTranscriptionService configured for VAD")
    }

    @MainActor
    private func setupSystemAudioVAD(with configuration: VADConfiguration, coordinator: VADTranscriptionCoordinator) async {
        guard tapRecorder != nil else {
            logger.debug("No system audio recorder available for VAD")
            return
        }

        if systemVADManager == nil {
            let manager = VADManager(configuration: configuration, source: .system)
            manager.delegate = coordinator
            systemVADManager = manager
        } else {
            systemVADManager?.delegate = coordinator
        }

        if let manager = systemVADManager {
            await manager.enable()
        }

        attachSystemAudioVADHandler()
    }

    @MainActor
    private func attachSystemAudioVADHandler() {
        guard systemVADManager != nil else { return }

        let handler: (AVAudioPCMBuffer) -> Void = { [weak self] buffer in
            Task { @MainActor in
                guard let self else { return }
                self.systemVADManager?.processAudioBuffer(buffer)
            }
        }

        if let recorder = tapRecorder as? SystemWideTapRecorder {
            recorder.vadBufferHandler = handler
            logger.info("Attached VAD handler to system-wide tap recorder")
        } else if let recorder = tapRecorder as? ProcessTapRecorder {
            recorder.vadBufferHandler = handler
            logger.info("Attached VAD handler to process tap recorder")
        } else {
            logger.warning("Unable to attach VAD handler: unsupported tap recorder type")
        }
    }

    @MainActor
    private func detachSystemAudioVAD() {
        if let recorder = tapRecorder as? SystemWideTapRecorder {
            recorder.vadBufferHandler = nil
        } else if let recorder = tapRecorder as? ProcessTapRecorder {
            recorder.vadBufferHandler = nil
        }

        logger.info("Detached VAD handler from system audio recorder")
    }
}
