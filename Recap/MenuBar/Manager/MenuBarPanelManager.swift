import SwiftUI
import AppKit

@MainActor
final class MenuBarPanelManager: MenuBarPanelManagerType, ObservableObject {
    var statusBarManager: StatusBarManagerType
    var panel: SlidingPanel?

    var settingsPanel: SlidingPanel?
    var summaryPanel: SlidingPanel?
    var previousRecapsWindowManager: RecapsWindowManager?

    var isVisible = false
    var isSettingsVisible = false
    var isSummaryVisible = false
    var isPreviousRecapsVisible = false
    
    let initialSize = CGSize(width: 485, height: 500)
    let menuBarHeight: CGFloat = 24
    let panelOffset: CGFloat = 12
    let panelSpacing: CGFloat = 8
    
    let audioProcessController: AudioProcessController
    let appSelectionViewModel: AppSelectionViewModel
    let previousRecapsViewModel: PreviousRecapsViewModel
    let whisperModelsViewModel: WhisperModelsViewModel
    let userPreferencesRepository: UserPreferencesRepositoryType
    let dependencyContainer: DependencyContainer
    
    init(
        statusBarManager: StatusBarManagerType,
        whisperModelsViewModel: WhisperModelsViewModel,
        coreDataManager: CoreDataManagerType,
        audioProcessController: AudioProcessController,
        appSelectionViewModel: AppSelectionViewModel,
        previousRecapsViewModel: PreviousRecapsViewModel,
        userPreferencesRepository: UserPreferencesRepositoryType,
        dependencyContainer: DependencyContainer
    ) {
        self.statusBarManager = statusBarManager
        self.audioProcessController = audioProcessController
        self.appSelectionViewModel = appSelectionViewModel
        self.whisperModelsViewModel = whisperModelsViewModel
        self.userPreferencesRepository = userPreferencesRepository
        self.dependencyContainer = dependencyContainer
        self.previousRecapsViewModel = previousRecapsViewModel
        setupDelegates()
    }
    
    private func setupDelegates() {
        statusBarManager.delegate = self
    }
    
    func createMainPanel() -> SlidingPanel {
        let viewModel = dependencyContainer.createRecapViewModel()
        viewModel.delegate = self
        let contentView = RecapHomeView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 12
        
        let newPanel = SlidingPanel(contentViewController: hostingController)
        newPanel.panelDelegate = self
        return newPanel
    }
    
    func positionPanel(_ panel: NSPanel, size: CGSize? = nil) {
        guard let statusButton = statusBarManager.statusButton,
              let statusWindow = statusButton.window,
              let screen = statusWindow.screen else { return }
        
        let panelSize = size ?? initialSize
        let screenFrame = screen.frame
        let finalX = screenFrame.maxX - panelSize.width - panelOffset
        let panelY = screenFrame.maxY - menuBarHeight - panelSize.height - panelSpacing
        
        panel.setFrame(
            NSRect(x: finalX, y: panelY, width: panelSize.width, height: panelSize.height),
            display: false
        )
    }
    
    private func showPanel() {
        if panel == nil {
            createAndShowNewPanel()
        } else {
            showExistingPanel()
        }
    }
    
    private func createAndShowNewPanel() {
        Task {
            do {
                let preferences = try await userPreferencesRepository.getOrCreatePreferences()
                await createPanelBasedOnOnboardingStatus(isOnboarded: preferences.onboarded)
            } catch {
                await createMainPanelAndPosition()
            }
            
            await animateAndShowPanel()
        }
    }
    
    private func createPanelBasedOnOnboardingStatus(isOnboarded: Bool) async {
        if !isOnboarded {
            panel = createOnboardingPanel()
        } else {
            panel = createMainPanel()
        }
        
        if let panel = panel {
            positionPanel(panel)
        }
    }
    
    private func createMainPanelAndPosition() async {
        panel = createMainPanel()
        if let panel = panel {
            positionPanel(panel)
        }
    }
    
    private func animateAndShowPanel() async {
        guard let panel = panel else { return }
        panel.contentView?.wantsLayer = true
        
        await withCheckedContinuation { continuation in
            PanelAnimator.slideIn(panel: panel) { [weak self] in
                self?.isVisible = true
                continuation.resume()
            }
        }
    }
    
    private func showExistingPanel() {
        guard let panel = panel else { return }
        
        positionPanel(panel)
        panel.contentView?.wantsLayer = true
        
        PanelAnimator.slideIn(panel: panel) { [weak self] in
            self?.isVisible = true
        }
    }
    
    func showMainPanel() {
        showPanel()
    }
    
    func hideMainPanel() {
        hidePanel()
    }
    
    private func hidePanel() {
        guard let panel = panel else { return }
        
        PanelAnimator.slideOut(panel: panel) { [weak self] in
            self?.isVisible = false
        }
    }
    
    private func hideAllSidePanels() {
        if isSettingsVisible { hideSettingsPanel() }
        if isSummaryVisible { hideSummaryPanel() }
        if isPreviousRecapsVisible { hidePreviousRecapsWindow() }
    }
    
    func toggleSidePanel(
        isVisible: Bool,
        show: () -> Void,
        hide: () -> Void
    ) {
        guard !isVisible else { return hide() }
        hideAllSidePanels()
        show()
    }
    
    deinit {
        panel = nil
        settingsPanel = nil
    }
}

extension MenuBarPanelManager: StatusBarDelegate {
    func statusItemClicked() {
        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }
    
    func quitRequested() {
        NSApplication.shared.terminate(nil)
    }
}

extension MenuBarPanelManager: SlidingPanelDelegate {
    func panelDidReceiveClickOutside() {
        hidePanel()
        hideAllSidePanels()
    }
}
