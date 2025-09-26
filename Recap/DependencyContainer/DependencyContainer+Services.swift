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

    func makeStreamingTranscriptionService() -> StreamingTranscriptionService {
        StreamingTranscriptionService(transcriptionService: transcriptionService)
    }
    
    func makeMeetingDetectionService() -> any MeetingDetectionServiceType {
        MeetingDetectionService(audioProcessController: audioProcessController, permissionsHelper: makePermissionsHelper())
    }
    
    func makeMeetingAppDetectionService() -> MeetingAppDetecting {
        MeetingAppDetectionService(processController: audioProcessController)
    }
    
    func makeRecordingSessionManager() -> RecordingSessionManaging {
        RecordingSessionManager(
            microphoneCapture: microphoneCapture,
            permissionsHelper: makePermissionsHelper(),
            streamingTranscriptionService: streamingTranscriptionService
        )
    }
    
    func makeMicrophoneCapture() -> any MicrophoneCaptureType {
        MicrophoneCapture()
    }
    
    func makeNotificationService() -> NotificationServiceType {
        NotificationService()
    }
    
    func makeKeychainService() -> KeychainServiceType {
        KeychainService()
    }
    
    func makeKeychainAPIValidator() -> KeychainAPIValidatorType {
        KeychainAPIValidator(keychainService: keychainService)
    }
}
