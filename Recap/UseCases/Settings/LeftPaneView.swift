import SwiftUI

struct LeftPaneView<GeneralViewModel: GeneralSettingsViewModelType>: View {
    @ObservedObject private var recapViewModel: RecapViewModel
    @ObservedObject private var whisperModelsViewModel: WhisperModelsViewModel
    @ObservedObject private var generalSettingsViewModel: GeneralViewModel
    private let meetingDetectionService: any MeetingDetectionServiceType
    private let userPreferencesRepository: UserPreferencesRepositoryType
    let onClose: () -> Void
    
    init(
        recapViewModel: RecapViewModel,
        whisperModelsViewModel: WhisperModelsViewModel,
        generalSettingsViewModel: GeneralViewModel,
        meetingDetectionService: any MeetingDetectionServiceType,
        userPreferencesRepository: UserPreferencesRepositoryType,
        onClose: @escaping () -> Void
    ) {
        self.recapViewModel = recapViewModel
        self.whisperModelsViewModel = whisperModelsViewModel
        self.generalSettingsViewModel = generalSettingsViewModel
        self.meetingDetectionService = meetingDetectionService
        self.userPreferencesRepository = userPreferencesRepository
        self.onClose = onClose
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                UIConstants.Gradients.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: UIConstants.Spacing.sectionSpacing) {
                    // Header
                    HStack {
                        Text("Audio Sources")
                            .foregroundColor(UIConstants.Colors.textPrimary)
                            .font(UIConstants.Typography.appTitle)
                            .padding(.leading, UIConstants.Spacing.contentPadding)
                            .padding(.top, UIConstants.Spacing.sectionSpacing)
                        
                        Spacer()
                        
                        Text("Close")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "242323"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(stops: [
                                                        .init(color: Color(hex: "979797").opacity(0.6), location: 0),
                                                        .init(color: Color(hex: "979797").opacity(0.4), location: 1)
                                                    ]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 0.8
                                            )
                                    )
                                    .opacity(0.6)
                            )
                            .onTapGesture {
                                onClose()
                            }
                            .padding(.trailing, UIConstants.Spacing.contentPadding)
                            .padding(.top, UIConstants.Spacing.sectionSpacing)
                    }
                    
                    // Source Selection Section
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.cardInternalSpacing) {
                        Text("Audio Sources")
                            .font(UIConstants.Typography.cardTitle)
                            .foregroundColor(UIConstants.Colors.textPrimary)
                            .padding(.horizontal, UIConstants.Spacing.contentPadding)
                        
                        HStack(spacing: UIConstants.Spacing.cardSpacing) {
                            HeatmapCard(
                                title: "System Audio", 
                                containerWidth: geometry.size.width,
                                isSelected: true,
                                audioLevel: recapViewModel.systemAudioHeatmapLevel,
                                isInteractionEnabled: !recapViewModel.isRecording,
                                onToggle: { }
                            )
                            HeatmapCard(
                                title: "Microphone", 
                                containerWidth: geometry.size.width,
                                isSelected: recapViewModel.isMicrophoneEnabled,
                                audioLevel: recapViewModel.microphoneHeatmapLevel,
                                isInteractionEnabled: !recapViewModel.isRecording,
                                onToggle: { 
                                    recapViewModel.toggleMicrophone()
                                }
                            )
                        }
                        .padding(.horizontal, UIConstants.Spacing.contentPadding)
                    }
                    
                    // Use the existing SettingsView content
                    SettingsView(
                        whisperModelsViewModel: whisperModelsViewModel,
                        generalSettingsViewModel: generalSettingsViewModel,
                        meetingDetectionService: meetingDetectionService,
                        userPreferencesRepository: userPreferencesRepository,
                        onClose: onClose
                    )
                }
            }
        }
        .toast(isPresenting: $whisperModelsViewModel.showingError) {
            AlertToast(
                displayMode: .banner(.slide),
                type: .error(.red),
                title: "Error",
                subTitle: whisperModelsViewModel.errorMessage
            )
        }
    }
}

#Preview {
    let coreDataManager = CoreDataManager(inMemory: true)
    let repository = WhisperModelRepository(coreDataManager: coreDataManager)
    let whisperModelsViewModel = WhisperModelsViewModel(repository: repository)
    let generalSettingsViewModel = PreviewGeneralSettingsViewModel()
    let recapViewModel = RecapViewModel.createForPreview()
    
    LeftPaneView(
        recapViewModel: recapViewModel,
        whisperModelsViewModel: whisperModelsViewModel, 
        generalSettingsViewModel: generalSettingsViewModel,
        meetingDetectionService: MeetingDetectionService(audioProcessController: AudioProcessController(), permissionsHelper: PermissionsHelper()),
        userPreferencesRepository: UserPreferencesRepository(coreDataManager: coreDataManager),
        onClose: {}
    )
    .frame(width: 550, height: 500)
}

// Just used for previews only!
private final class PreviewGeneralSettingsViewModel: GeneralSettingsViewModelType {
    var folderSettingsViewModel: FolderSettingsViewModelType
    
    init() {
        self.folderSettingsViewModel = PreviewFolderSettingsViewModel()
    }
    
    var customPromptTemplate: Binding<String> = .constant("Hello")

    var showAPIKeyAlert: Bool = false
    
    var existingAPIKey: String? = nil
    
    func saveAPIKey(_ apiKey: String) async throws {}
    
    func dismissAPIKeyAlert() {}
    
    @Published var availableModels: [LLMModelInfo] = [
        LLMModelInfo(name: "llama3.2", provider: "ollama"),
        LLMModelInfo(name: "codellama", provider: "ollama")
    ]
    @Published var selectedModel: LLMModelInfo?
    @Published var selectedProvider: LLMProvider = .ollama
    @Published var autoDetectMeetings: Bool = true
    @Published var isAutoStopRecording: Bool = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var globalShortcutKeyCode: Int32 = 15
    @Published var globalShortcutModifiers: Int32 = 1048840
    @Published var activeWarnings: [WarningItem] = [
        WarningItem(
            id: "ollama",
            title: "Ollama Not Running",
            message: "Please start Ollama to use local AI models for summarization.",
            icon: "server.rack",
            severity: .warning
        )
    ]
    
    var hasModels: Bool {
        !availableModels.isEmpty
    }
    
    var currentSelection: LLMModelInfo? {
        selectedModel
    }
    
    func loadModels() async {}
    func selectModel(_ model: LLMModelInfo) async {
        selectedModel = model
    }
    func selectProvider(_ provider: LLMProvider) async {
        selectedProvider = provider
    }
    func toggleAutoDetectMeetings(_ enabled: Bool) async {
        autoDetectMeetings = enabled
    }
    func toggleAutoStopRecording(_ enabled: Bool) async {
        isAutoStopRecording = enabled
    }
    
    func updateCustomPromptTemplate(_ template: String) async {}
    
    func resetToDefaultPrompt() async {}
    
    func updateGlobalShortcut(keyCode: Int32, modifiers: Int32) async {
        globalShortcutKeyCode = keyCode
        globalShortcutModifiers = modifiers
    }
}

// Preview implementation for FolderSettingsViewModel
private final class PreviewFolderSettingsViewModel: FolderSettingsViewModelType {
    @Published var currentFolderPath: String = "/Users/nilleb/Library/Containers/co.nilleb.Recap/Data/tmp/"
    @Published var errorMessage: String?
    
    init() {
        // Preview initializer - no setup needed
    }
    
    func updateFolderPath(_ url: URL) async {
        currentFolderPath = url.path
    }
    
    func setErrorMessage(_ message: String?) {
        errorMessage = message
    }
}
