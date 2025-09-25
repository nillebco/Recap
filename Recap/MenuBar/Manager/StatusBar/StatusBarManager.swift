import AppKit

@MainActor
protocol StatusBarDelegate: AnyObject {
    func statusItemClicked()
    func quitRequested()
}

final class StatusBarManager: StatusBarManagerType {
    private var statusItem: NSStatusItem?
    weak var delegate: StatusBarDelegate?
    private var themeObserver: NSObjectProtocol?
    
    init() {
        setupStatusItem()
        setupThemeObserver()
    }
    
    var statusButton: NSStatusBarButton? {
        statusItem?.button
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateIconForCurrentTheme()
            button.target = self
            button.action = #selector(handleButtonClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func setupThemeObserver() {
        themeObserver = nil
    }
    
    private func updateIconForCurrentTheme() {
        guard let button = statusItem?.button else { return }
        // Always use the black icon, regardless of theme
        if let image = NSImage(named: "barIcon-dark") {
            image.isTemplate = false
            button.image = image
            button.image?.isTemplate = false
            button.contentTintColor = nil
        } else if let fallback = NSImage(named: "barIcon") {
            fallback.isTemplate = false
            button.image = fallback
            button.image?.isTemplate = false
            button.contentTintColor = nil
        }
    }
    
    @objc private func handleButtonClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.statusItemClicked()
            }
        }
    }
    
    private func showContextMenu() {
        let contextMenu = NSMenu()
        
        let quitItem = NSMenuItem(title: "Quit Recap", action: #selector(quitMenuItemClicked), keyEquivalent: "q")
        quitItem.target = self
        
        contextMenu.addItem(quitItem)
        
        if let button = statusItem?.button {
            contextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY), in: button)
        }
    }
    
    @objc private func quitMenuItemClicked() {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.quitRequested()
        }
    }
    
    deinit {
        if let observer = themeObserver {
            DistributedNotificationCenter.default.removeObserver(observer)
        }
        statusItem = nil
    }
}
