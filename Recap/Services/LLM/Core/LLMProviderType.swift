import Foundation
import Combine

@MainActor
protocol LLMProviderType: AnyObject {
    associatedtype Model: LLMModelType
    
    var name: String { get }
    var isAvailable: Bool { get }
    var availabilityPublisher: AnyPublisher<Bool, Never> { get }
    
    func checkAvailability() async -> Bool
    func listModels() async throws -> [Model]
    func generateChatCompletion(
        modelName: String,
        messages: [LLMMessage],
        options: LLMOptions
    ) async throws -> String
    func cancelCurrentTask()
}

struct LLMMessage {
    enum Role: String {
        case system
        case user
        case assistant
    }
    
    let role: Role
    let content: String
    
    init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

