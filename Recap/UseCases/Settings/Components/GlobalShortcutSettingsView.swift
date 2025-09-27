import SwiftUI
import Combine

struct GlobalShortcutSettingsView<ViewModel: GeneralSettingsViewModelType>: View {
    @ObservedObject private var viewModel: ViewModel
    @State private var isRecordingShortcut = false
    @State private var currentKeyCode: Int32 = 15
    @State private var currentModifiers: Int32 = 1048840
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Global Shortcut")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(UIConstants.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Press the key combination you want to use for starting/stopping recording:")
                    .font(.system(size: 12))
                    .foregroundColor(UIConstants.Colors.textSecondary)
                
                HStack {
                    Button(action: {
                        isRecordingShortcut = true
                    }) {
                        HStack {
                            Text(shortcutDisplayString)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(UIConstants.Colors.textPrimary)
                            
                            Spacer()
                            
                            Image(systemName: "keyboard")
                                .font(.system(size: 12))
                                .foregroundColor(UIConstants.Colors.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isRecordingShortcut ? 
                                    Color.blue.opacity(0.2) : 
                                    Color.gray.opacity(0.1)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    isRecordingShortcut ? 
                                        Color.blue : 
                                        Color.gray.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 200)
                    
                    if isRecordingShortcut {
                        Button("Cancel") {
                            isRecordingShortcut = false
                        }
                        .font(.system(size: 12))
                        .foregroundColor(UIConstants.Colors.textSecondary)
                    }
                }
                
                if isRecordingShortcut {
                    Text("Press any key combination...")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            currentKeyCode = viewModel.globalShortcutKeyCode
            currentModifiers = viewModel.globalShortcutModifiers
        }
        .onChange(of: viewModel.globalShortcutKeyCode) { _, newValue in
            currentKeyCode = newValue
        }
        .onChange(of: viewModel.globalShortcutModifiers) { _, newValue in
            currentModifiers = newValue
        }
        .onKeyPress { keyPress in
            if isRecordingShortcut {
                // Convert KeyEquivalent to key code (simplified mapping)
                let keyCode = getKeyCodeFromKeyEquivalent(keyPress.key)
                let modifiers = Int32(keyPress.modifiers.rawValue)
                
                Task {
                    await viewModel.updateGlobalShortcut(keyCode: keyCode, modifiers: modifiers)
                }
                
                isRecordingShortcut = false
                return .handled
            }
            return .ignored
        }
    }
    
    private var shortcutDisplayString: String {
        let keyString = getKeyString(for: currentKeyCode)
        let modifierString = getModifierString(for: currentModifiers)
        return "\(modifierString)\(keyString)"
    }
    
    private func getKeyString(for keyCode: Int32) -> String {
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
    
    private func getKeyCodeFromKeyEquivalent(_ key: KeyEquivalent) -> Int32 {
        // Simplified mapping for common keys
        switch key {
        case KeyEquivalent("a"): return 0
        case KeyEquivalent("b"): return 11
        case KeyEquivalent("c"): return 8
        case KeyEquivalent("d"): return 2
        case KeyEquivalent("e"): return 14
        case KeyEquivalent("f"): return 3
        case KeyEquivalent("g"): return 5
        case KeyEquivalent("h"): return 4
        case KeyEquivalent("i"): return 34
        case KeyEquivalent("j"): return 38
        case KeyEquivalent("k"): return 40
        case KeyEquivalent("l"): return 37
        case KeyEquivalent("m"): return 46
        case KeyEquivalent("n"): return 45
        case KeyEquivalent("o"): return 31
        case KeyEquivalent("p"): return 35
        case KeyEquivalent("q"): return 12
        case KeyEquivalent("r"): return 15
        case KeyEquivalent("s"): return 1
        case KeyEquivalent("t"): return 17
        case KeyEquivalent("u"): return 32
        case KeyEquivalent("v"): return 9
        case KeyEquivalent("w"): return 13
        case KeyEquivalent("x"): return 7
        case KeyEquivalent("y"): return 16
        case KeyEquivalent("z"): return 6
        case .space: return 49
        case .tab: return 48
        case .return: return 36
        case .escape: return 53
        case .delete: return 51
        default: return 15 // Default to 'R'
        }
    }
    
    private func getModifierString(for modifiers: Int32) -> String {
        var result = ""
        if (modifiers & Int32(NSEvent.ModifierFlags.command.rawValue)) != 0 {
            result += "⌘"
        }
        if (modifiers & Int32(NSEvent.ModifierFlags.option.rawValue)) != 0 {
            result += "⌥"
        }
        if (modifiers & Int32(NSEvent.ModifierFlags.control.rawValue)) != 0 {
            result += "⌃"
        }
        if (modifiers & Int32(NSEvent.ModifierFlags.shift.rawValue)) != 0 {
            result += "⇧"
        }
        return result
    }
}

// Note: Preview removed due to complex mock requirements
