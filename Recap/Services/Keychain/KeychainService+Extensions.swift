import Foundation

extension KeychainServiceType {
    func storeOpenRouterAPIKey(_ apiKey: String) throws {
        try store(key: KeychainKey.openRouterApiKey.key, value: apiKey)
    }
    
    func retrieveOpenRouterAPIKey() throws -> String? {
        try retrieve(key: KeychainKey.openRouterApiKey.key)
    }
    
    func deleteOpenRouterAPIKey() throws {
        try delete(key: KeychainKey.openRouterApiKey.key)
    }
    
    func hasOpenRouterAPIKey() -> Bool {
        exists(key: KeychainKey.openRouterApiKey.key)
    }
}
