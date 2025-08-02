import Foundation
import Combine

@MainActor
final class OllamaProvider: LLMProviderType, LLMTaskManageable {
    typealias Model = OllamaModel
    
    let name = "Ollama"
    
    var isAvailable: Bool {
        availabilityCoordinator.isAvailable
    }
    
    var availabilityPublisher: AnyPublisher<Bool, Never> {
        availabilityCoordinator.availabilityPublisher
    }
    
    var currentTask: Task<Void, Never>?
    
    private let apiClient: OllamaAPIClient
    private let availabilityCoordinator: AvailabilityCoordinatorType
    
    init(baseURL: String = "http://localhost", port: Int = 11434) {
        self.apiClient = OllamaAPIClient(baseURL: baseURL, port: port)
        self.availabilityCoordinator = AvailabilityCoordinator(
            checkInterval: 30.0,
            availabilityCheck: { [weak apiClient] in
                await apiClient?.checkAvailability() ?? false
            }
        )
        availabilityCoordinator.startMonitoring()
    }
    
    deinit {
        cancelCurrentTask()
    }
    
    func checkAvailability() async -> Bool {
        await availabilityCoordinator.checkAvailabilityNow()
    }
    
    func listModels() async throws -> [OllamaModel] {
        guard isAvailable else {
            throw LLMError.providerNotAvailable
        }
        
        return try await executeWithTaskManagement {
            let apiModels = try await self.apiClient.listModels()
            return apiModels.map { OllamaModel(from: $0) }
        }
    }
    
    func generateChatCompletion(
        modelName: String,
        messages: [LLMMessage],
        options: LLMOptions
    ) async throws -> String {
        try validateProviderAvailable()
        try validateMessages(messages)
        
        return try await executeWithTaskManagement {
            try await self.apiClient.generateChatCompletion(
                modelName: modelName,
                messages: messages,
                options: options
            )
        }
    }
    
    private func validateProviderAvailable() throws {
        guard isAvailable else {
            throw LLMError.providerNotAvailable
        }
    }
    
    private func validateMessages(_ messages: [LLMMessage]) throws {
        guard !messages.isEmpty else {
            throw LLMError.invalidPrompt
        }
    }
    
}