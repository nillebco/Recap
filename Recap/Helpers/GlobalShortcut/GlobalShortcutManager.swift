import Cocoa
import Carbon
import OSLog

@MainActor
protocol GlobalShortcutDelegate: AnyObject {
    func globalShortcutActivated()
}

@MainActor
final class GlobalShortcutManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private weak var delegate: GlobalShortcutDelegate?

    // Default shortcut: Cmd+R
    private var currentShortcut: (keyCode: UInt32, modifiers: UInt32) = (keyCode: 15, modifiers: UInt32(cmdKey)) // 'R' key with Cmd
    private let logger = Logger(subsystem: AppConstants.Logging.subsystem, category: String(describing: GlobalShortcutManager.self))

    init() {
        setupEventHandling()
    }

    deinit {
        // Note: We can't use Task here as it would capture self in deinit
        // The shortcut will be cleaned up when the app terminates
    }

    func setDelegate(_ delegate: GlobalShortcutDelegate) {
        self.delegate = delegate
    }

    func registerShortcut(keyCode: UInt32, modifiers: UInt32) {
        unregisterShortcut()
        currentShortcut = (keyCode: keyCode, modifiers: modifiers)
        registerShortcut()
    }

    func registerDefaultShortcut() {
        registerShortcut(keyCode: 15, modifiers: UInt32(cmdKey)) // Cmd+R
    }

    private func registerShortcut() {
        let eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, theEvent, userData) -> OSStatus in
                guard let userData = userData, let theEvent = theEvent else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotKeyEvent(theEvent)
            },
            1,
            [eventType],
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else {
            logger.error("Failed to install event handler: \(status, privacy: .public)")
            return
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D4B4D4B), id: 1)
        let status2 = RegisterEventHotKey(
            currentShortcut.keyCode,
            currentShortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status2 == noErr else {
            logger.error("Failed to register hot key: \(status2, privacy: .public)")
            return
        }

        logger.info("Global shortcut registered: Cmd+R")
    }

    private func unregisterShortcut() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func setupEventHandling() {
        // This is handled in registerShortcut
    }

    private func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.globalShortcutActivated()
        }
        return noErr
    }

    func getCurrentShortcut() -> (keyCode: UInt32, modifiers: UInt32) {
        return currentShortcut
    }

    func getShortcutString() -> String {
        let keyString = getKeyString(for: currentShortcut.keyCode)
        let modifierString = getModifierString(for: currentShortcut.modifiers)
        return "\(modifierString)\(keyString)"
    }

    private func getKeyString(for keyCode: UInt32) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Escape"
        case 123: return "Left"
        case 124: return "Right"
        case 125: return "Down"
        case 126: return "Up"
        default: return "Key\(keyCode)"
        }
    }

    private func getModifierString(for modifiers: UInt32) -> String {
        var result = ""
        if (modifiers & UInt32(cmdKey)) != 0 {
            result += "⌘"
        }
        if (modifiers & UInt32(optionKey)) != 0 {
            result += "⌥"
        }
        if (modifiers & UInt32(controlKey)) != 0 {
            result += "⌃"
        }
        if (modifiers & UInt32(shiftKey)) != 0 {
            result += "⇧"
        }
        return result
    }
}
