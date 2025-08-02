import SwiftUI

enum SettingsTab: CaseIterable {
    case general
    case whisperModels
    
    var title: String {
        switch self {
        case .general:
            return "General"
        case .whisperModels:
            return "Whisper Models"
        }
    }
}

struct SettingsView<GeneralViewModel: GeneralSettingsViewModelType>: View {
    @State private var selectedTab: SettingsTab = .general
    @ObservedObject var whisperModelsViewModel: WhisperModelsViewModel
    @ObservedObject var generalSettingsViewModel: GeneralViewModel
    let onClose: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                UIConstants.Gradients.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: UIConstants.Spacing.sectionSpacing) {
                    HStack {
                        Text("Settings")
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
                    
                    HStack(spacing: 8) {
                        ForEach(SettingsTab.allCases, id: \.self) { tab in
                            TabButton(
                                text: tab.title,
                                isSelected: selectedTab == tab
                            ) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedTab = tab
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, UIConstants.Spacing.contentPadding)
                    
                    Group {
                        switch selectedTab {
                        case .general:
                            GeneralSettingsView<GeneralViewModel>(viewModel: generalSettingsViewModel)
                        case .whisperModels:
                            WhisperModelsView(viewModel: whisperModelsViewModel)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                    .id(selectedTab)
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
    
    SettingsView(
        whisperModelsViewModel: whisperModelsViewModel, 
        generalSettingsViewModel: generalSettingsViewModel,
        onClose: {}
    )
    .frame(width: 550, height: 500)
}

private final class PreviewGeneralSettingsViewModel: ObservableObject, GeneralSettingsViewModelType {
    var activeWarnings: [WarningItem] = []
    
    @Published var availableModels: [LLMModelInfo] = [
        LLMModelInfo(name: "llama3.2", provider: "ollama"),
        LLMModelInfo(name: "codellama", provider: "ollama")
    ]
    @Published var selectedModel: LLMModelInfo?
    @Published var selectedProvider: LLMProvider = .ollama
    @Published var isAutoDetectMeetings: Bool = true
    @Published var isAutoStopRecording: Bool = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showToast = false
    @Published var toastMessage = ""
    
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
        isAutoDetectMeetings = enabled
    }
    func toggleAutoStopRecording(_ enabled: Bool) async {
        isAutoStopRecording = enabled
    }
}
