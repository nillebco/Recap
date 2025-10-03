import Combine
import SwiftUI

struct GeneralSettingsView<ViewModel: GeneralSettingsViewModelType>: View {
    @ObservedObject private var viewModel: ViewModel
    private var recapViewModel: RecapViewModel?

    init(viewModel: ViewModel, recapViewModel: RecapViewModel? = nil) {
        self.viewModel = viewModel
        self.recapViewModel = recapViewModel
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Audio Sources Section (moved from LeftPaneView)
                    if let recapViewModel = recapViewModel {
                        SettingsCard(title: "Audio Sources") {
                            HStack(spacing: UIConstants.Spacing.cardSpacing) {
                                HeatmapCard(
                                    title: "System Audio",
                                    containerWidth: geometry.size.width,
                                    isSelected: true,
                                    audioLevel: recapViewModel.systemAudioHeatmapLevel,
                                    isInteractionEnabled: !recapViewModel.isRecording,
                                    onToggle: {}
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
                        }
                    }

                    ForEach(viewModel.activeWarnings, id: \.id) { warning in
                        WarningCard(warning: warning, containerWidth: geometry.size.width)
                    }
                    SettingsCard(title: "Model Selection") {
                        VStack(spacing: 16) {
                            settingsRow(label: "Provider") {
                                CustomSegmentedControl(
                                    options: LLMProvider.allCases,
                                    selection: Binding(
                                        get: { viewModel.selectedProvider },
                                        set: { newProvider in
                                            Task {
                                                await viewModel.selectProvider(newProvider)
                                            }
                                        }
                                    ),
                                    displayName: { $0.providerName }
                                )
                                .frame(width: 285)
                            }

                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                    Text("Loading models...")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(UIConstants.Colors.textSecondary)
                                }
                            } else if viewModel.hasModels {
                                settingsRow(label: "Summarizer Model") {
                                    if let currentSelection = viewModel.currentSelection {
                                        CustomDropdown(
                                            title: "Model",
                                            options: viewModel.availableModels,
                                            selection: Binding(
                                                get: { currentSelection },
                                                set: { newModel in
                                                    Task {
                                                        await viewModel.selectModel(newModel)
                                                    }
                                                }
                                            ),
                                            displayName: { $0.name },
                                            showSearch: true
                                        )
                                        .frame(width: 285)
                                    } else {
                                        HStack {
                                            ProgressView()
                                                .scaleEffect(0.5)
                                            Text("Setting up...")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(UIConstants.Colors.textSecondary)
                                        }
                                    }
                                }
                            } else {
                                settingsRow(label: "Model Name") {
                                    TextField("gpt-4o", text: viewModel.manualModelName)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(UIConstants.Colors.textPrimary)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .frame(width: 285)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(stops: [
                                                            .init(
                                                                color: Color(hex: "2A2A2A").opacity(
                                                                    0.3), location: 0),
                                                            .init(
                                                                color: Color(hex: "1A1A1A").opacity(
                                                                    0.5), location: 1)
                                                        ]),
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(
                                                            LinearGradient(
                                                                gradient: Gradient(stops: [
                                                                    .init(
                                                                        color: Color(hex: "979797")
                                                                            .opacity(0.2),
                                                                        location: 0),
                                                                    .init(
                                                                        color: Color(hex: "C4C4C4")
                                                                            .opacity(0.15),
                                                                        location: 1)
                                                                ]),
                                                                startPoint: .top,
                                                                endPoint: .bottom
                                                            ),
                                                            lineWidth: 1
                                                        )
                                                )
                                        )
                                }
                            }

                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.red)
                                    .padding(.top, 4)
                            }
                        }
                    }

                    SettingsCard(title: "Custom Prompt") {
                        VStack(alignment: .leading, spacing: 12) {
                            CustomTextEditor(
                                title: "Prompt Template",
                                text: viewModel.customPromptTemplate,
                                placeholder: "Enter your custom prompt template here...",
                                height: 120
                            )

                            HStack {
                                Text("Customize how AI summarizes your meeting transcripts")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(UIConstants.Colors.textSecondary)

                                Spacer()

                                PillButton(text: "Reset to Default") {
                                    Task {
                                        await viewModel.resetToDefaultPrompt()
                                    }
                                }
                            }
                        }
                    }

                    SettingsCard(title: "Processing Options") {
                        VStack(spacing: 16) {
                            settingsRow(label: "Enable Transcription") {
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { viewModel.isAutoTranscribeEnabled },
                                        set: { newValue in
                                            Task {
                                                await viewModel.toggleAutoTranscribe(newValue)
                                            }
                                        }
                                    )
                                )
                                .toggleStyle(SwitchToggleStyle(tint: UIConstants.Colors.audioGreen))
                            }

                            Text("When disabled, transcription will be skipped")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(UIConstants.Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            settingsRow(label: "Enable Summarization") {
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { viewModel.isAutoSummarizeEnabled },
                                        set: { newValue in
                                            Task {
                                                await viewModel.toggleAutoSummarize(newValue)
                                            }
                                        }
                                    )
                                )
                                .toggleStyle(SwitchToggleStyle(tint: UIConstants.Colors.audioGreen))
                            }

                            Text(
                                "When disabled, recordings will only be transcribed without summarization"
                            )
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(UIConstants.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    SettingsCard(title: "Global Shortcut") {
                        GlobalShortcutSettingsView(viewModel: viewModel)
                    }

                    SettingsCard(title: "File Storage") {
                        FolderSettingsView(
                            viewModel: AnyFolderSettingsViewModel(viewModel.folderSettingsViewModel)
                        )
                    }

                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .toast(
            isPresenting: Binding(
                get: { viewModel.showToast },
                set: { _ in }
            )
        ) {
            AlertToast(
                displayMode: .hud,
                type: .error(.red),
                title: viewModel.toastMessage
            )
        }
        .blur(radius: viewModel.showAPIKeyAlert || viewModel.showOpenAIAlert ? 2 : 0)
        .animation(
            .easeInOut(duration: 0.3), value: viewModel.showAPIKeyAlert || viewModel.showOpenAIAlert
        )
        .overlay(
            Group {
                if viewModel.showAPIKeyAlert {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .transition(.opacity)

                        OpenRouterAPIKeyAlert(
                            isPresented: Binding(
                                get: { viewModel.showAPIKeyAlert },
                                set: { _ in viewModel.dismissAPIKeyAlert() }
                            ),
                            existingKey: viewModel.existingAPIKey,
                            onSave: { apiKey in
                                try await viewModel.saveAPIKey(apiKey)
                            }
                        )
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }

                if viewModel.showOpenAIAlert {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .transition(.opacity)

                        OpenAIAPIKeyAlert(
                            isPresented: Binding(
                                get: { viewModel.showOpenAIAlert },
                                set: { _ in viewModel.dismissOpenAIAlert() }
                            ),
                            existingKey: viewModel.existingOpenAIKey,
                            existingEndpoint: viewModel.existingOpenAIEndpoint,
                            onSave: { apiKey, endpoint in
                                try await viewModel.saveOpenAIConfiguration(
                                    apiKey: apiKey, endpoint: endpoint)
                            }
                        )
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
            }
            .animation(
                .spring(response: 0.4, dampingFraction: 0.8),
                value: viewModel.showAPIKeyAlert || viewModel.showOpenAIAlert)
        )
    }

    private func settingsRow<Content: View>(
        label: String,
        @ViewBuilder control: () -> Content
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(UIConstants.Colors.textPrimary)

            Spacer()

            control()
        }
    }
}

#Preview {
    GeneralSettingsView(viewModel: PreviewGeneralSettingsViewModel())
        .frame(width: 550, height: 500)
        .background(Color.black)
}

private final class PreviewGeneralSettingsViewModel: GeneralSettingsViewModelType {
    init() {
        // Preview initializer - no setup needed
    }

    func updateCustomPromptTemplate(_ template: String) async {}

    func resetToDefaultPrompt() async {}

    var customPromptTemplate: Binding<String> {
        .constant(UserPreferencesInfo.defaultPromptTemplate)
    }

    @Published var availableModels: [LLMModelInfo] = [
        LLMModelInfo(name: "llama3.2", provider: "ollama"),
        LLMModelInfo(name: "codellama", provider: "ollama")
    ]
    @Published var selectedModel: LLMModelInfo?
    @Published var selectedProvider: LLMProvider = .ollama
    @Published var autoDetectMeetings: Bool = true
    @Published var isAutoStopRecording: Bool = false
    @Published var isAutoSummarizeEnabled: Bool = true
    @Published var isAutoTranscribeEnabled: Bool = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var showAPIKeyAlert = false
    @Published var existingAPIKey: String?
    @Published var showOpenAIAlert = false
    @Published var existingOpenAIKey: String?
    @Published var existingOpenAIEndpoint: String?
    @Published var globalShortcutKeyCode: Int32 = 15
    @Published var globalShortcutModifiers: Int32 = 1_048_840
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

    var manualModelName: Binding<String> {
        .constant("")
    }

    // Add the missing folderSettingsViewModel property
    var folderSettingsViewModel: FolderSettingsViewModelType {
        PreviewFolderSettingsViewModel()
    }

    func loadModels() async {}
    func selectModel(_ model: LLMModelInfo) async {
        selectedModel = model
    }
    func selectManualModel(_ modelName: String) async {}
    func selectProvider(_ provider: LLMProvider) async {
        selectedProvider = provider
    }
    func toggleAutoDetectMeetings(_ enabled: Bool) async {
        autoDetectMeetings = enabled
    }
    func toggleAutoStopRecording(_ enabled: Bool) async {
        isAutoStopRecording = enabled
    }
    func toggleAutoSummarize(_ enabled: Bool) async {
        isAutoSummarizeEnabled = enabled
    }
    func toggleAutoTranscribe(_ enabled: Bool) async {
        isAutoTranscribeEnabled = enabled
    }
    func saveAPIKey(_ apiKey: String) async throws {}
    func dismissAPIKeyAlert() {
        showAPIKeyAlert = false
    }
    func saveOpenAIConfiguration(apiKey: String, endpoint: String) async throws {}
    func dismissOpenAIAlert() {
        showOpenAIAlert = false
    }
    func updateGlobalShortcut(keyCode: Int32, modifiers: Int32) async {
        globalShortcutKeyCode = keyCode
        globalShortcutModifiers = modifiers
    }
}

// Add a preview implementation for FolderSettingsViewModel
private final class PreviewFolderSettingsViewModel: FolderSettingsViewModelType {
    @Published var currentFolderPath: String =
        "/Users/nilleb/Library/Containers/co.nilleb.Recap/Data/tmp/"
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
