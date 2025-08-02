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
}