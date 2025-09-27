import Foundation
import CoreData

struct UserPreferencesInfo: Identifiable {
    let id: String
    let selectedLLMModelID: String?
    let selectedProvider: LLMProvider
    let autoSummarizeEnabled: Bool
    let autoDetectMeetings: Bool
    let autoStopRecording: Bool
    let onboarded: Bool
    let summaryPromptTemplate: String?
    let microphoneEnabled: Bool
    let globalShortcutKeyCode: Int32
    let globalShortcutModifiers: Int32
    let createdAt: Date
    let modifiedAt: Date

    init(from managedObject: UserPreferences) {
        self.id = managedObject.id ?? UUID().uuidString
        self.selectedLLMModelID = managedObject.selectedLLMModelID
        self.selectedProvider = LLMProvider(rawValue: managedObject.selectedProvider ?? LLMProvider.default.rawValue) ?? LLMProvider.default
        self.autoSummarizeEnabled = managedObject.autoSummarizeEnabled
        self.autoDetectMeetings = managedObject.autoDetectMeetings
        self.autoStopRecording = managedObject.autoStopRecording
        self.onboarded = managedObject.onboarded
        self.summaryPromptTemplate = managedObject.summaryPromptTemplate
        self.microphoneEnabled = managedObject.microphoneEnabled
        self.globalShortcutKeyCode = managedObject.globalShortcutKeyCode
        self.globalShortcutModifiers = managedObject.globalShortcutModifiers
        self.createdAt = managedObject.createdAt ?? Date()
        self.modifiedAt = managedObject.modifiedAt ?? Date()
    }

    
    init(
        id: String = UUID().uuidString,
        selectedLLMModelID: String? = nil,
        selectedProvider: LLMProvider = .default,
        autoSummarizeEnabled: Bool = true,
        autoDetectMeetings: Bool = false,
        autoStopRecording: Bool = false,
        onboarded: Bool = false,
        summaryPromptTemplate: String? = nil,
        microphoneEnabled: Bool = false,
        globalShortcutKeyCode: Int32 = 15, // 'R' key
        globalShortcutModifiers: Int32 = 1048840, // Cmd key
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.selectedLLMModelID = selectedLLMModelID
        self.selectedProvider = selectedProvider
        self.autoSummarizeEnabled = autoSummarizeEnabled
        self.autoDetectMeetings = autoDetectMeetings
        self.autoStopRecording = autoStopRecording
        self.onboarded = onboarded
        self.summaryPromptTemplate = summaryPromptTemplate
        self.microphoneEnabled = microphoneEnabled
        self.globalShortcutKeyCode = globalShortcutKeyCode
        self.globalShortcutModifiers = globalShortcutModifiers
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    static var defaultPromptTemplate: String {
        """
        Please provide a concise summary of the following meeting transcript. \
        Focus on key points, decisions made, and action items. \
        Format the summary with clear sections for Main Topics, Decisions, and Action Items.
        """
    }
}
