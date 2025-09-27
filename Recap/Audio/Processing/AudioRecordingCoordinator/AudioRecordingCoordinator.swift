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
        if let microphoneCapture = microphoneCapture as? MicrophoneCapture {
            return microphoneCapture.isVADEnabled
        }
        return false
    }

    @MainActor
    var currentSpeechProbability: Float {
        if let microphoneCapture = microphoneCapture as? MicrophoneCapture {
            return microphoneCapture.currentSpeechProbability
        }
        return 0.0
    }

    @MainActor
    var isSpeaking: Bool {
        if let microphoneCapture = microphoneCapture as? MicrophoneCapture {
            return microphoneCapture.isSpeaking
        }
        return false
    }

    // MARK: - VAD Methods

    @MainActor
    func enableVAD(configuration: VADConfiguration? = nil, delegate: VADTranscriptionCoordinatorDelegate? = nil) async {
        guard let microphoneCapture = microphoneCapture as? MicrophoneCapture else {
            logger.warning("Cannot enable VAD: MicrophoneCapture not available")
            return
        }

        // Create streaming transcription service if needed
        if streamingTranscriptionService == nil {
            // We need access to the transcription service - this will need to be injected
            logger.warning("StreamingTranscriptionService not initialized - VAD transcription will not work")
        }

        // Create VAD transcription coordinator
        if let streamingService = streamingTranscriptionService {
            vadTranscriptionCoordinator = VADTranscriptionCoordinator(streamingTranscriptionService: streamingService)
            vadTranscriptionCoordinator?.delegate = delegate
        }

        // Setup VAD on microphone capture
        await microphoneCapture.setupVAD(
            configuration: configuration ?? .default,
            delegate: vadTranscriptionCoordinator
        )

        await microphoneCapture.enableVAD()

        vadTranscriptionCoordinator?.startVADTranscription()

        logger.info("VAD enabled for audio recording coordinator")
    }

    @MainActor
    func disableVAD() async {
        guard let microphoneCapture = microphoneCapture as? MicrophoneCapture else { return }

        microphoneCapture.disableVAD()
        vadTranscriptionCoordinator?.stopVADTranscription()
        vadTranscriptionCoordinator = nil

        logger.info("VAD disabled for audio recording coordinator")
    }

    @MainActor
    func pauseVAD() async {
        guard let microphoneCapture = microphoneCapture as? MicrophoneCapture else { return }

        microphoneCapture.pauseVAD()
    }

    @MainActor
    func resumeVAD() async {
        guard let microphoneCapture = microphoneCapture as? MicrophoneCapture else { return }

        microphoneCapture.resumeVAD()
    }

    // MARK: - Dependency Injection for VAD

    @MainActor
    func setStreamingTranscriptionService(_ service: StreamingTranscriptionService) {
        self.streamingTranscriptionService = service
        logger.info("StreamingTranscriptionService configured for VAD")
    }
}
