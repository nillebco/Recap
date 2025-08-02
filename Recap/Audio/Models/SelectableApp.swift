import Foundation
import AppKit

struct SelectableApp: Identifiable, Hashable {
    let id: pid_t
    let name: String
    let icon: NSImage
    let isMeetingApp: Bool
    let isAudioActive: Bool
    private let originalAudioProcess: AudioProcess
    
    init(from audioProcess: AudioProcess) {
        self.id = audioProcess.id
        self.name = audioProcess.name
        self.icon = audioProcess.icon
        self.isMeetingApp = audioProcess.isMeetingApp
        self.isAudioActive = audioProcess.audioActive
        self.originalAudioProcess = audioProcess
    }
    
    var audioProcess: AudioProcess {
        originalAudioProcess
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    
    static func == (lhs: SelectableApp, rhs: SelectableApp) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

enum AppSelectionState {
    case noSelection
    case selected(SelectableApp)
    case showingDropdown
}

extension AppSelectionState {
    var selectedApp: SelectableApp? {
        if case .selected(let app) = self {
            return app
        }
        return nil
    }
    
    var isShowingDropdown: Bool {
        if case .showingDropdown = self {
            return true
        }
        return false
    }
    
    var hasSelection: Bool {
        if case .selected = self {
            return true
        }
        return false
    }
}
