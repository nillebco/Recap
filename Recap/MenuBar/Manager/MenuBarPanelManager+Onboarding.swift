import SwiftUI
import AppKit

extension MenuBarPanelManager {
    @MainActor
    func createOnboardingPanel() -> SlidingPanel {
        let onboardingViewModel = dependencyContainer.makeOnboardingViewModel()
        onboardingViewModel.delegate = self
        let contentView = OnboardingView<OnboardingViewModel>(viewModel: onboardingViewModel)
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 12
        
        let newPanel = SlidingPanel(contentViewController: hostingController)
        newPanel.panelDelegate = self
        return newPanel
    }
}