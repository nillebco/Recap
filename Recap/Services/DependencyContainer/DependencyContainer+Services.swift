import Foundation

extension DependencyContainer {
    
    func makeLLMService() -> LLMServiceType {
        LLMService(
            llmModelRepository: llmModelRepository,
            userPreferencesRepository: userPreferencesRepository
        )
    }
    
    func makeSummarizationService() -> SummarizationServiceType {
        SummarizationService(llmService: llmService)
    }
    
    func makeTranscriptionService() -> TranscriptionServiceType {
        TranscriptionService(whisperModelRepository: whisperModelRepository)
    }
    
    func makeMeetingDetectionService() -> MeetingDetectionServiceType {
        MeetingDetectionService(audioProcessController: audioProcessController)
    }
    
    func makeMeetingAppDetectionService() -> MeetingAppDetecting {
        MeetingAppDetectionService(processController: audioProcessController)
    }
    
    func makeRecordingSessionManager() -> RecordingSessionManaging {
        guard let micCapture = microphoneCapture as? MicrophoneCapture else {
            fatalError("microphoneCapture is not of type MicrophoneCapture")
        }
        return RecordingSessionManager(microphoneCapture: micCapture)
    }
    
    func makeMicrophoneCapture() -> MicrophoneCaptureType {
        MicrophoneCapture()
    }
    
    func makeNotificationService() -> NotificationServiceType {
        NotificationService()
    }
}