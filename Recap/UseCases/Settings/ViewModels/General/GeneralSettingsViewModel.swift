import Foundation
import Combine

@MainActor
final class GeneralSettingsViewModel: ObservableObject, GeneralSettingsViewModelType {
    @Published private(set) var availableModels: [LLMModelInfo] = []
    @Published private(set) var selectedModel: LLMModelInfo?
    @Published private(set) var selectedProvider: LLMProvider = .default
    @Published private(set) var autoDetectMeetings: Bool = false
    @Published private(set) var isAutoStopRecording: Bool = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var showToast = false
    @Published private(set) var toastMessage = ""
    @Published private(set) var activeWarnings: [WarningItem] = []
    
    var hasModels: Bool {
        !availableModels.isEmpty
    }
    
    var currentSelection: LLMModelInfo? {
        selectedModel
    }
    
    private let llmService: LLMServiceType
    private let userPreferencesRepository: UserPreferencesRepositoryType
    private let environmentValidator: EnvironmentValidatorType
    private let warningManager: WarningManagerType
    private var cancellables = Set<AnyCancellable>()
    
    init(
        llmService: LLMServiceType,
        userPreferencesRepository: UserPreferencesRepositoryType,
        environmentValidator: EnvironmentValidatorType = EnvironmentValidator(),
        warningManager: WarningManagerType
    ) {
        self.llmService = llmService
        self.userPreferencesRepository = userPreferencesRepository
        self.environmentValidator = environmentValidator
        self.warningManager = warningManager
        
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
        } catch {
            selectedProvider = .default
            autoDetectMeetings = false
            isAutoStopRecording = false
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
    
    func selectProvider(_ provider: LLMProvider) async {
        errorMessage = nil
        
        if provider == .openRouter {
            let validation = environmentValidator.validateOpenRouterEnvironment()
            
            if !validation.isValid {
                if let message = validation.errorMessage {
                    showValidationToast(message)
                }
                selectedProvider = .ollama
                try? await llmService.selectProvider(.ollama)
                await loadModels()
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
}