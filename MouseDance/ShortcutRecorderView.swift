import AppKit
import SwiftUI

struct ShortcutKey: Codable, Hashable {
    var modifiers: ModifierMask
    var keyCode: UInt16
    var keyString: String

    var displayName: String {
        let mods = modifiers.displayName
        if mods.isEmpty {
            return keyString
        }
        return "\(mods) + \(keyString)"
    }

    func matches(_ flags: CGEventFlags, keyCode: CGKeyCode) -> Bool {
        return modifiers.matches(flags) && self.keyCode == keyCode
    }
}

extension ModifierMask {
    var symbols: [String] {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option { parts.append("⌥") }
        if shift { parts.append("⇧") }
        if command { parts.append("⌘") }
        return parts
    }
}

extension ShortcutKey {
    var keySymbols: [String] {
        var parts = modifiers.symbols
        let mappedKey: String
        switch keyString.uppercased() {
        case "ENTER": mappedKey = "↩"
        case "SPACE": mappedKey = "␣"
        case "TAB": mappedKey = "⇥"
        case "ESC": mappedKey = "⎋"
        case "DELETE", "BACKSPACE": mappedKey = "⌫"
        case "←": mappedKey = "←"
        case "→": mappedKey = "→"
        case "↑": mappedKey = "↑"
        case "↓": mappedKey = "↓"
        default: mappedKey = keyString.uppercased()
        }
        parts.append(mappedKey)
        return parts
    }
}

final class ShortcutEventView: NSView {
    var onShortcutChanged: ((ShortcutKey?) -> Void)?
    var onRecordingStateChanged: ((Bool) -> Void)?
    var onModifiersChanged: ((ModifierMask?) -> Void)?
    
    var isRecording = false {
        didSet {
            onRecordingStateChanged?(isRecording)
            if !isRecording {
                onModifiersChanged?(nil)
            }
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        isRecording = true
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 { // Esc
            isRecording = false
            window?.makeFirstResponder(nil)
            return
        }
        
        if event.keyCode == 51 { // Backspace
            onShortcutChanged?(nil)
            isRecording = false
            window?.makeFirstResponder(nil)
            return
        }

        let mask = ModifierMask(
            command: event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
            option: event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.option),
            control: event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.control),
            shift: event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)
        )

        let keyStr = keyString(for: event)
        let newShortcut = ShortcutKey(modifiers: mask, keyCode: event.keyCode, keyString: keyStr)

        onShortcutChanged?(newShortcut)
        isRecording = false
        window?.makeFirstResponder(nil)
    }
    
    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { return }

        let mask = ModifierMask(
            command: event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
            option: event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.option),
            control: event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.control),
            shift: event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)
        )

        onModifiersChanged?(mask.isEmpty ? nil : mask)
    }
    
    private func keyString(for event: NSEvent) -> String {
        switch event.keyCode {
        case 36: return "Enter"
        case 49: return "Space"
        case 48: return "Tab"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            return event.charactersIgnoringModifiers?.uppercased() ?? ""
        }
    }
}

struct ShortcutEventRepresentable: NSViewRepresentable {
    @Binding var shortcut: ShortcutKey?
    @Binding var isRecording: Bool
    @Binding var currentModifiers: ModifierMask?

    func makeNSView(context: Context) -> ShortcutEventView {
        let view = ShortcutEventView()
        view.onShortcutChanged = { newShortcut in
            DispatchQueue.main.async {
                self.shortcut = newShortcut
            }
        }
        view.onRecordingStateChanged = { recording in
            DispatchQueue.main.async {
                self.isRecording = recording
            }
        }
        view.onModifiersChanged = { mods in
            DispatchQueue.main.async {
                self.currentModifiers = mods
            }
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutEventView, context: Context) {
        if nsView.isRecording != isRecording {
            if isRecording {
                nsView.window?.makeFirstResponder(nsView)
            } else {
                if nsView.window?.firstResponder == nsView {
                    nsView.window?.makeFirstResponder(nil)
                }
            }
        }
    }
}

struct KeyCapView: View {
    let text: String
    let isActive: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(isActive ? .accentColor : .primary)
            .frame(minWidth: 26, minHeight: 26)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isActive ? Color.accentColor.opacity(0.5) : Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isActive ? 0 : 0.05), radius: 1, x: 0, y: 1)
    }
}

struct ShortcutRecorderView: View {
    @Binding var shortcut: ShortcutKey?
    @Binding var isRecording: Bool
    
    @State private var currentModifiers: ModifierMask? = nil
    @State private var isHovered = false

    var body: some View {
        ZStack {
            // Invisible event handler covering the whole area
            ShortcutEventRepresentable(
                shortcut: $shortcut,
                isRecording: $isRecording,
                currentModifiers: $currentModifiers
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Visual overlay
            HStack(spacing: 4) {
                if isRecording {
                    if let mods = currentModifiers, !mods.isEmpty {
                        ForEach(Array(mods.symbols.enumerated()), id: \.offset) { _, symbol in
                            KeyCapView(text: symbol, isActive: true)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    Text("按下按键...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 4)
                        .opacity(0.8)
                } else if let shortcut = shortcut {
                    ForEach(Array(shortcut.keySymbols.enumerated()), id: \.offset) { _, symbol in
                        KeyCapView(text: symbol, isActive: false)
                            .transition(.scale.combined(with: .opacity))
                    }
                } else {
                    Text("点击录制")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isRecording ? Color.accentColor.opacity(0.1) : Color(NSColor.windowBackgroundColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isRecording ? Color.accentColor.opacity(0.8) : Color(NSColor.separatorColor).opacity(0.5), lineWidth: isRecording ? 2 : 1)
            )
            .shadow(color: isRecording ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.05), radius: isRecording ? 4 : 2, x: 0, y: 1)
            .scaleEffect(isHovered && !isRecording ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            .animation(.easeInOut(duration: 0.2), value: isRecording)
            .animation(.easeInOut(duration: 0.2), value: currentModifiers)
            .animation(.easeInOut(duration: 0.2), value: shortcut)
            .allowsHitTesting(false) // Let clicks pass through to ShortcutEventRepresentable
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
