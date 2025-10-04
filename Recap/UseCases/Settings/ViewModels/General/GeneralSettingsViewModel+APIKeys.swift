import Foundation

@MainActor
extension GeneralSettingsViewModel {
  func saveAPIKey(_ apiKey: String) async throws {
    try keychainService.storeOpenRouterAPIKey(apiKey)

    existingAPIKey = apiKey
    showAPIKeyAlert = false

    await selectProvider(.openRouter)
  }

  func dismissAPIKeyAlert() {
    showAPIKeyAlert = false
    existingAPIKey = nil
  }

  func saveOpenAIConfiguration(apiKey: String, endpoint: String) async throws {
    try keychainService.storeOpenAIAPIKey(apiKey)
    try keychainService.storeOpenAIEndpoint(endpoint)

    existingOpenAIKey = apiKey
    existingOpenAIEndpoint = endpoint
    showOpenAIAlert = false

    await selectProvider(.openAI)
  }

  func dismissOpenAIAlert() {
    showOpenAIAlert = false
    existingOpenAIKey = nil
    existingOpenAIEndpoint = nil
  }
}
