import Foundation

enum LLMProvider: String, CaseIterable, Identifiable {
    case ollama = "ollama"
    case openRouter = "openrouter"
    
    var id: String { rawValue }
    
    var providerName: String {
        switch self {
        case .ollama:
            return "Ollama"
        case .openRouter:
            return "OpenRouter"
        }
    }
    
    static var `default`: LLMProvider {
        .ollama
    }
}
