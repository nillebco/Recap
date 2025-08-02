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
        RecordingSessionManager(microphoneCapture: microphoneCapture as! MicrophoneCapture)
    }
    
    func makeMicrophoneCapture() -> MicrophoneCaptureType {
        MicrophoneCapture()
    }
    
    func makeNotificationService() -> NotificationServiceType {
        NotificationService()
    }
}