import Foundation
import OSLog

protocol RecordingSessionManaging {
    func startSession(configuration: RecordingConfiguration) async throws -> AudioRecordingCoordinatorType
}

final class RecordingSessionManager: RecordingSessionManaging {
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: RecordingSessionManager.self))
    private let microphoneCapture: MicrophoneCapture
    
    init(microphoneCapture: MicrophoneCapture) {
        self.microphoneCapture = microphoneCapture
    }
    
    func startSession(configuration: RecordingConfiguration) async throws -> AudioRecordingCoordinatorType {
        let processTap = ProcessTap(process: configuration.audioProcess)
        await MainActor.run {
            processTap.activate()
        }
        
        if let errorMessage = processTap.errorMessage {
            logger.error("Process tap failed: \(errorMessage)")
            throw AudioCaptureError.coreAudioError("Failed to tap system audio: \(errorMessage)")
        }
        
        let microphoneCaptureToUse = configuration.enableMicrophone ? microphoneCapture : nil
        
        if configuration.enableMicrophone {
            let hasPermission = await microphoneCapture.requestPermission()
            guard hasPermission else {
                throw AudioCaptureError.microphonePermissionDenied
            }
        }
        
        let coordinator = AudioRecordingCoordinator(
            configuration: configuration,
            microphoneCapture: microphoneCaptureToUse,
            processTap: processTap
        )
        
        try await coordinator.start()
        
        logger.info("Recording session started for \(configuration.audioProcess.name) with microphone: \(configuration.enableMicrophone)")
        return coordinator
    }
}
