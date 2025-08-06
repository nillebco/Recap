import AppKit

@MainActor
protocol StatusBarDelegate: AnyObject {
    func statusItemClicked()
    func quitRequested()
}

final class StatusBarManager: StatusBarManagerType {
    private var statusItem: NSStatusItem?
    weak var delegate: StatusBarDelegate?
    
    init() {
        setupStatusItem()
    }
    
    var statusButton: NSStatusBarButton? {
        statusItem?.button
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(named: "barIcon")
            button.target = self
            button.action = #selector(handleButtonClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
        statusItem = nil
    }
}
