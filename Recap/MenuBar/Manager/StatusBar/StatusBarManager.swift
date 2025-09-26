import AppKit

@MainActor
protocol StatusBarDelegate: AnyObject {
    func statusItemClicked()
    func quitRequested()
    func startRecordingRequested()
    func stopRecordingRequested()
    func settingsRequested()
}

final class StatusBarManager: StatusBarManagerType {
    private var statusItem: NSStatusItem?
    weak var delegate: StatusBarDelegate?
    private var themeObserver: NSObjectProtocol?
    private var isRecording = false
    
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

            // Apply red tint if recording
            if isRecording {
                button.contentTintColor = .systemRed
            } else {
                button.contentTintColor = nil
            }
        } else if let fallback = NSImage(named: "barIcon") {
            fallback.isTemplate = false
            button.image = fallback
            button.image?.isTemplate = false

            // Apply red tint if recording
            if isRecording {
                button.contentTintColor = .systemRed
            } else {
                button.contentTintColor = nil
            }
        }
    }

    func setRecordingState(_ recording: Bool) {
        isRecording = recording
        updateIconForCurrentTheme()
    }
    
    @objc private func handleButtonClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            showMainMenu()
        }
    }
    
    private func showMainMenu() {
        let mainMenu = NSMenu()

        // Recording menu item (toggles between Start/Stop)
        let recordingTitle = isRecording ? "Stop recording" : "Start recording"
        let recordingItem = NSMenuItem(title: recordingTitle, action: #selector(recordingMenuItemClicked), keyEquivalent: "")
        recordingItem.target = self

        // Settings menu item
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(settingsMenuItemClicked), keyEquivalent: "")
        settingsItem.target = self

        // Quit menu item
        let quitItem = NSMenuItem(title: "Quit Recap", action: #selector(quitMenuItemClicked), keyEquivalent: "q")
        quitItem.target = self

        mainMenu.addItem(recordingItem)
        mainMenu.addItem(settingsItem)
        mainMenu.addItem(NSMenuItem.separator())
        mainMenu.addItem(quitItem)

        if let button = statusItem?.button {
            mainMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY), in: button)
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
    
    @objc private func recordingMenuItemClicked() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isRecording {
                self.delegate?.stopRecordingRequested()
            } else {
                self.delegate?.startRecordingRequested()
            }
        }
    }

    @objc private func settingsMenuItemClicked() {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.settingsRequested()
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
