import Foundation
import Combine
import SwiftUI

@MainActor
final class GeneralSettingsViewModel: GeneralSettingsViewModelType {
    @Published private(set) var availableModels: [LLMModelInfo] = []
    @Published private(set) var selectedModel: LLMModelInfo?
    @Published private(set) var selectedProvider: LLMProvider = .default
    @Published private(set) var autoDetectMeetings: Bool = false
    @Published private(set) var isAutoStopRecording: Bool = false
    @Published private(set) var isAutoSummarizeEnabled: Bool = true
    @Published private(set) var isAutoTranscribeEnabled: Bool = true
    @Published private var customPromptTemplateValue: String = ""
    @Published private var manualModelNameValue: String = ""
    @Published private(set) var globalShortcutKeyCode: Int32 = 15 // 'R' key
    @Published private(set) var globalShortcutModifiers: Int32 = 1048840 // Cmd key

    var customPromptTemplate: Binding<String> {
        Binding(
            get: { self.customPromptTemplateValue },
            set: { newValue in
                Task {
                    await self.updateCustomPromptTemplate(newValue)
                }
            }
        )
    }

    var manualModelName: Binding<String> {
        Binding(
            get: { self.manualModelNameValue },
            set: { newValue in
                Task {
                    await self.selectManualModel(newValue)
                }
            }
        )
    }

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var showToast = false
    @Published private(set) var toastMessage = ""
    @Published private(set) var activeWarnings: [WarningItem] = []
    @Published private(set) var showAPIKeyAlert = false
    @Published private(set) var existingAPIKey: String?
    @Published private(set) var showOpenAIAlert = false
    @Published private(set) var existingOpenAIKey: String?
    @Published private(set) var existingOpenAIEndpoint: String?

    var hasModels: Bool {
        !availableModels.isEmpty
    }

    var currentSelection: LLMModelInfo? {
        selectedModel
    }

    private let llmService: LLMServiceType
    private let userPreferencesRepository: UserPreferencesRepositoryType
    private let keychainAPIValidator: KeychainAPIValidatorType
    private let keychainService: KeychainServiceType
    private let warningManager: any WarningManagerType
    private let fileManagerHelper: RecordingFileManagerHelperType
    private var cancellables = Set<AnyCancellable>()

    lazy var folderSettingsViewModel: FolderSettingsViewModelType = {
        FolderSettingsViewModel(
            userPreferencesRepository: userPreferencesRepository,
            fileManagerHelper: fileManagerHelper
        )
    }()

    init(
        llmService: LLMServiceType,
        userPreferencesRepository: UserPreferencesRepositoryType,
        keychainAPIValidator: KeychainAPIValidatorType,
        keychainService: KeychainServiceType,
        warningManager: any WarningManagerType,
        fileManagerHelper: RecordingFileManagerHelperType
    ) {
        self.llmService = llmService
        self.userPreferencesRepository = userPreferencesRepository
        self.keychainAPIValidator = keychainAPIValidator
        self.keychainService = keychainService
        self.warningManager = warningManager
        self.fileManagerHelper = fileManagerHelper

        setupWarningObserver()

        Task {
            await loadInitialState()
        }
    }

    private func setupWarningObserver() {
        warningManager.activeWarningsPublisher
            .assign(to: \.activeWarnings, on: self)
            .store(in: &cancellables)
    }

    private func loadInitialState() async {
        do {
            let preferences = try await llmService.getUserPreferences()
            selectedProvider = preferences.selectedProvider
            autoDetectMeetings = preferences.autoDetectMeetings
            isAutoStopRecording = preferences.autoStopRecording
            isAutoSummarizeEnabled = preferences.autoSummarizeEnabled
            isAutoTranscribeEnabled = preferences.autoTranscribeEnabled
            customPromptTemplateValue = preferences.summaryPromptTemplate ?? UserPreferencesInfo.defaultPromptTemplate
            globalShortcutKeyCode = preferences.globalShortcutKeyCode
            globalShortcutModifiers = preferences.globalShortcutModifiers
        } catch {
            selectedProvider = .default
            autoDetectMeetings = false
            isAutoStopRecording = false
            isAutoSummarizeEnabled = true
            isAutoTranscribeEnabled = true
            customPromptTemplateValue = UserPreferencesInfo.defaultPromptTemplate
            globalShortcutKeyCode = 15 // 'R' key
            globalShortcutModifiers = 1048840 // Cmd key
        }
        await loadModels()
    }

    func loadModels() async {
        isLoading = true
        errorMessage = nil

        do {
            availableModels = try await llmService.getAvailableModels()
            selectedModel = try await llmService.getSelectedModel()

            if selectedModel == nil, let firstModel = availableModels.first {
                await selectModel(firstModel)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func selectModel(_ model: LLMModelInfo) async {
        errorMessage = nil
        selectedModel = model

        do {
            try await llmService.selectModel(id: model.id)
        } catch {
            errorMessage = error.localizedDescription
            selectedModel = nil
        }
    }

    func selectManualModel(_ modelName: String) async {
        guard !modelName.isEmpty else {
            return
        }

        errorMessage = nil
        manualModelNameValue = modelName

        let manualModel = LLMModelInfo(name: modelName, provider: selectedProvider.rawValue)
        selectedModel = manualModel

        do {
            try await llmService.selectModel(id: manualModel.id)
        } catch {
            errorMessage = error.localizedDescription
            selectedModel = nil
        }
    }

    func selectProvider(_ provider: LLMProvider) async {
        errorMessage = nil

        if provider == .openRouter {
            let validation = keychainAPIValidator.validateOpenRouterAPI()

            if !validation.isValid {
                do {
                    existingAPIKey = try keychainService.retrieveOpenRouterAPIKey()
                } catch {
                    existingAPIKey = nil
                }
                showAPIKeyAlert = true
                return
            }
        }

        if provider == .openAI {
            let validation = keychainAPIValidator.validateOpenAIAPI()

            if !validation.isValid {
                do {
                    existingOpenAIKey = try keychainService.retrieveOpenAIAPIKey()
                    existingOpenAIEndpoint = try keychainService.retrieveOpenAIEndpoint()
                } catch {
                    existingOpenAIKey = nil
                    existingOpenAIEndpoint = nil
                }
                showOpenAIAlert = true
                return
            }
        }

        selectedProvider = provider

        do {
            try await llmService.selectProvider(provider)

            let newModels = try await llmService.getAvailableModels()
            availableModels = newModels

            let currentSelection = try await llmService.getSelectedModel()
            let isCurrentModelAvailable = newModels.contains { $0.id == currentSelection?.id }

            if !isCurrentModelAvailable, let firstModel = newModels.first {
                await selectModel(firstModel)
            } else {
                selectedModel = currentSelection
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func showValidationToast(_ message: String) {
        toastMessage = message
        showToast = true

        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showToast = false
        }
    }

    func toggleAutoDetectMeetings(_ enabled: Bool) async {
        errorMessage = nil
        autoDetectMeetings = enabled

        do {
            try await userPreferencesRepository.updateAutoDetectMeetings(enabled)
        } catch {
            errorMessage = error.localizedDescription
            autoDetectMeetings = !enabled
        }
    }

    func updateCustomPromptTemplate(_ template: String) async {
        customPromptTemplateValue = template

        do {
            let templateToSave = template.isEmpty ? nil : template
            try await userPreferencesRepository.updateSummaryPromptTemplate(templateToSave)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetToDefaultPrompt() async {
        await updateCustomPromptTemplate(UserPreferencesInfo.defaultPromptTemplate)
    }

    func toggleAutoStopRecording(_ enabled: Bool) async {
        errorMessage = nil
        isAutoStopRecording = enabled

        do {
            try await userPreferencesRepository.updateAutoStopRecording(enabled)
        } catch {
            errorMessage = error.localizedDescription
            isAutoStopRecording = !enabled
        }
    }

    func toggleAutoSummarize(_ enabled: Bool) async {
        errorMessage = nil
        isAutoSummarizeEnabled = enabled

        do {
            try await userPreferencesRepository.updateAutoSummarize(enabled)
        } catch {
            errorMessage = error.localizedDescription
            isAutoSummarizeEnabled = !enabled
        }
    }

    func toggleAutoTranscribe(_ enabled: Bool) async {
        errorMessage = nil
        isAutoTranscribeEnabled = enabled

        do {
            try await userPreferencesRepository.updateAutoTranscribe(enabled)
        } catch {
            errorMessage = error.localizedDescription
            isAutoTranscribeEnabled = !enabled
        }
    }

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

    func updateGlobalShortcut(keyCode: Int32, modifiers: Int32) async {
        errorMessage = nil
        globalShortcutKeyCode = keyCode
        globalShortcutModifiers = modifiers

        do {
            try await userPreferencesRepository.updateGlobalShortcut(keyCode: keyCode, modifiers: modifiers)
        } catch {
            errorMessage = error.localizedDescription
            // Revert on error - we'd need to reload from preferences
            let preferences = try? await userPreferencesRepository.getOrCreatePreferences()
            globalShortcutKeyCode = preferences?.globalShortcutKeyCode ?? 15
            globalShortcutModifiers = preferences?.globalShortcutModifiers ?? 1048840
        }
    }

}
