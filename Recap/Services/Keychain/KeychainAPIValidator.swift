import Foundation

final class KeychainAPIValidator: KeychainAPIValidatorType {
    private let keychainService: KeychainServiceType
    
    init(keychainService: KeychainServiceType = KeychainService()) {
        self.keychainService = keychainService
    }
    
    func validateOpenRouterAPI() -> APIValidationResult {
        do {
            guard let apiKey = try keychainService.retrieve(key: KeychainKey.openRouterApiKey.key),
                  !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .missingApiKey
            }
            
            guard isValidOpenRouterAPIKeyFormat(apiKey) else {
                return .invalidApiKey
            }
            
            return .valid
        } catch {
            return .missingApiKey
        }
    }
    
    private func isValidOpenRouterAPIKeyFormat(_ apiKey: String) -> Bool {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedKey.hasPrefix("sk-or-") && trimmedKey.count > 10
    }
}
