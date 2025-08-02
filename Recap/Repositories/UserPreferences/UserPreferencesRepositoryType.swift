import Foundation

@MainActor
protocol UserPreferencesRepositoryType {
    func getOrCreatePreferences() async throws -> UserPreferencesInfo
    func updateSelectedLLMModel(id: String?) async throws
    func updateSelectedProvider(_ provider: LLMProvider) async throws
    func updateAutoDetectMeetings(_ enabled: Bool) async throws
    func updateAutoStopRecording(_ enabled: Bool) async throws
    func updateSummaryPromptTemplate(_ template: String?) async throws
}