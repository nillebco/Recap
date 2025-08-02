import AVFoundation
import AudioToolbox
import OSLog

final class AudioRecordingCoordinator: AudioRecordingCoordinatorType {
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: AudioRecordingCoordinator.self))
    
    private let configuration: RecordingConfiguration
    private let microphoneCapture: MicrophoneCapture?
    private let processTap: ProcessTap
    
    private var isRunning = false
    private var tapRecorder: ProcessTapRecorder?
    
    init(
        configuration: RecordingConfiguration,
        microphoneCapture: MicrophoneCapture?,
        processTap: ProcessTap
    ) {
        self.configuration = configuration
        self.microphoneCapture = microphoneCapture
        self.processTap = processTap
    }
    
    func start() async throws {
        guard !isRunning else { return }
        
        let expectedFiles = configuration.expectedFiles
        
        if let systemAudioURL = expectedFiles.systemAudioURL {
            let recorder = ProcessTapRecorder(fileURL: systemAudioURL, tap: processTap)
            self.tapRecorder = recorder
            
            try await MainActor.run {
                try recorder.start()
            }
            logger.info("System audio recording started: \(systemAudioURL.lastPathComponent)")
        }
        
        if let microphoneURL = expectedFiles.microphoneURL, 
           let microphoneCapture = microphoneCapture {
            await MainActor.run {
                processTap.activate()
            }
            
            guard let tapStreamDescription = processTap.tapStreamDescription else {
                throw AudioCaptureError.coreAudioError("Tap stream description not available")
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
        processTap.invalidate()

        isRunning = false
        tapRecorder = nil
        
        logger.info("Recording stopped for configuration: \(self.configuration.id)")
    }
    
    var currentMicrophoneLevel: Float {
        microphoneCapture?.audioLevel ?? 0.0
    }
    
    var currentSystemAudioLevel: Float {
        processTap.audioLevel
    }
    
    var hasDualAudio: Bool {
        configuration.enableMicrophone && microphoneCapture != nil
    }
    
    var recordedFiles: RecordedFiles {
        configuration.expectedFiles
    }
}
