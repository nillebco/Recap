import Foundation

protocol EnvironmentValidatorType {
    func validateOpenRouterEnvironment() -> ValidationResult
}

enum ValidationResult {
    case valid
    case missingApiKey
    
    var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .missingApiKey:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .missingApiKey:
            return "OpenRouter API key not found. Please set OPENROUTER_API_KEY environment variable."
        }
    }
}