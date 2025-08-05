import Foundation

extension DependencyContainer {
    
    func makeWhisperModelsViewModel() -> WhisperModelsViewModel {
        WhisperModelsViewModel(repository: whisperModelRepository)
    }
    
    func makeAppSelectionViewModel() -> AppSelectionViewModel {
        AppSelectionViewModel(audioProcessController: audioProcessController)
    }
    
    func makePreviousRecapsViewModel() -> PreviousRecapsViewModel {
        PreviousRecapsViewModel(recordingRepository: recordingRepository)
    }
    
    func makeGeneralSettingsViewModel() -> GeneralSettingsViewModel {
        GeneralSettingsViewModel(
            llmService: llmService,
            userPreferencesRepository: userPreferencesRepository,
            environmentValidator: EnvironmentValidator(),
            warningManager: warningManager
        )
    }
    
    func makeMeetingDetectionSettingsViewModel() -> MeetingDetectionSettingsViewModel {
        MeetingDetectionSettingsViewModel(
            detectionService: meetingDetectionService,
            userPreferencesRepository: userPreferencesRepository
        )
    }
    
    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            permissionsHelper: PermissionsHelper(),
            userPreferencesRepository: userPreferencesRepository
        )
    }
}