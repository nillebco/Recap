import Foundation
import OSLog

extension RecapViewModel {
    func startRecording() async {
        syncRecordingStateWithCoordinator()
        guard !isRecording else { return }
        guard let selectedApp = selectedApp else { return }
        
        do {
            errorMessage = nil
            
            let recordingID = generateRecordingID()
            currentRecordingID = recordingID
            
            let configuration = try await createRecordingConfiguration(
                recordingID: recordingID,
                audioProcess: selectedApp
            )
            
            let recordedFiles = try await recordingCoordinator.startRecording(configuration: configuration)

            // Enable VAD for real-time transcription if microphone is enabled
            if isMicrophoneEnabled {
                await recordingCoordinator.getCurrentRecordingCoordinator()?.enableVAD(configuration: nil, delegate: nil, recordingID: recordingID)
                
                // Connect VAD coordinator to processing coordinator
                if let audioCoordinator = recordingCoordinator.getCurrentRecordingCoordinator() {
                    await connectVADToProcessing(audioCoordinator: audioCoordinator)
                }
            }

            try await createRecordingEntity(
                recordingID: recordingID,
                recordedFiles: recordedFiles
            )
            
            updateRecordingUIState(started: true)
            
            logger.info("Recording started successfully - System: \(recordedFiles.systemAudioURL?.path ?? "none"), Microphone: \(recordedFiles.microphoneURL?.path ?? "none")")
        } catch {
            handleRecordingStartError(error)
        }
    }
    
    private func generateRecordingID() -> String {
        UUID().uuidString
    }
    
    private func connectVADToProcessing(audioCoordinator: AudioRecordingCoordinatorType) async {
        if let vadCoordinator = audioCoordinator.getVADTranscriptionCoordinator() {
            processingCoordinator.setVADTranscriptionCoordinator(vadCoordinator)
            logger.info("Connected VAD coordinator to processing coordinator")
        } else {
            logger.warning("No VAD coordinator available to connect to processing coordinator")
        }
    }
    
    private func createRecordingConfiguration(
        recordingID: String,
        audioProcess: AudioProcess
    ) async throws -> RecordingConfiguration {
        try fileManager.ensureRecordingsDirectoryExists()
        
        let baseURL = fileManager.createRecordingBaseURL(for: recordingID)
        
        return RecordingConfiguration(
            id: recordingID,
            audioProcess: audioProcess,
            enableMicrophone: isMicrophoneEnabled,
            baseURL: baseURL
        )
    }
    
    private func createRecordingEntity(
        recordingID: String,
        recordedFiles: RecordedFiles
    ) async throws {
        let recordingInfo = try await recordingRepository.createRecording(
            id: recordingID,
            startDate: Date(),
            recordingURL: recordedFiles.systemAudioURL ?? fileManager.createRecordingBaseURL(for: recordingID),
            microphoneURL: recordedFiles.microphoneURL,
            hasMicrophoneAudio: isMicrophoneEnabled,
            applicationName: recordedFiles.applicationName ?? selectedApp?.name
        )
        currentRecordings.insert(recordingInfo, at: 0)
    }
    
    private func handleRecordingStartError(_ error: Error) {
        errorMessage = error.localizedDescription
        logger.error("Failed to start recording: \(error)")
        currentRecordingID = nil
        updateRecordingUIState(started: false)
        showErrorToast = true
    }
}