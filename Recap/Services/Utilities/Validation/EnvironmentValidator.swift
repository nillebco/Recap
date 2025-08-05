import Foundation

final class EnvironmentValidator: EnvironmentValidatorType {
    private let processInfo: ProcessInfo
    
    init(processInfo: ProcessInfo = .processInfo) {
        self.processInfo = processInfo
    }
    
    func validateOpenRouterEnvironment() -> ValidationResult {
        guard let apiKey = processInfo.environment["OPENROUTER_API_KEY"],
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .missingApiKey
        }
        
        return .valid
    }
}