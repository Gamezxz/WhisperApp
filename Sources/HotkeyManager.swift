import Foundation
import AppKit
import Carbon.HIToolbox

/// Known modifier key codes (for modifier-only hotkeys like Fn alone)
private let kVK_Function: UInt32 = 63
private let modifierKeyCodes: Set<UInt32> = [
    63,  // Fn
    55,  // Command (left)
    54,  // Command (right)
    56,  // Shift (left)
    60,  // Shift (right)
    58,  // Option (left)
    61,  // Option (right)
    59,  // Control (left)
    62,  // Control (right)
    57,  // Caps Lock
]

/// Hotkey configuration: keyCode + modifiers + mode (toggle or hold)
struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt
    var isHoldMode: Bool
    var isModifierOnly: Bool  // true if the hotkey IS a modifier key (e.g., Fn alone)

    /// Human-readable shortcut string (e.g., "⌃⌥Space" or "Fn")
    var displayString: String {
        if isModifierOnly {
            let flags = NSEvent.ModifierFlags(rawValue: modifiers)
            if flags.contains(.function) { return "Fn" }
            if flags.contains(.control) { return "⌃" }
            if flags.contains(.option) { return "⌥" }
            if flags.contains(.shift) { return "⇧" }
            if flags.contains(.command) { return "⌘" }
            return "Modifier"
        }

        var parts: [String] = []
        if modifiers & UInt(NSEvent.ModifierFlags.control.rawValue) != 0 { parts.append("⌃") }
        if modifiers & UInt(NSEvent.ModifierFlags.option.rawValue) != 0 { parts.append("⌥") }
        if modifiers & UInt(NSEvent.ModifierFlags.shift.rawValue) != 0 { parts.append("⇧") }
        if modifiers & UInt(NSEvent.ModifierFlags.command.rawValue) != 0 { parts.append("⌘") }

        let keyNames: [UInt32: String] = [
            UInt32(kVK_Space): "Space",
            UInt32(kVK_Return): "Return",
            UInt32(kVK_Escape): "Esc",
            UInt32(kVK_Tab): "Tab",
            UInt32(kVK_Delete): "Delete",
            UInt32(kVK_ForwardDelete): "Fwd Delete",
        ]
        let keyStr = keyNames[keyCode] ?? "Key\(keyCode)"
        return parts.joined() + keyStr
    }

    static let `default` = HotkeyConfig(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt(NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue),
        isHoldMode: false,
        isModifierOnly: false
    )
}

/// Manages global hotkey monitoring — supports toggle/hold modes and modifier-only keys (e.g., Fn)
/// Uses both local AND global NSEvent monitors for reliable detection everywhere
class HotkeyManager {
    static let shared = HotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var config: HotkeyConfig
    private var isHolding = false
    private var modifierKeyDown = false  // for modifier-only hotkeys

    /// Called on activation (toggle: flip recording; hold: start recording)
    var onKeyDown: (() -> Void)?
    /// Called on deactivation (hold mode: stop recording; modifier-only: key released)
    var onKeyUp: (() -> Void)?

    private let defaultsKey = "hotkey.config"

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            self.config = saved
        } else {
            self.config = .default
        }
    }

    var currentConfig: HotkeyConfig { config }

    func updateConfig(_ newConfig: HotkeyConfig) {
        config = newConfig
        if let data = try? JSONEncoder().encode(newConfig) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        restartMonitors()
    }

    func start() {
        restartMonitors()
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    private func restartMonitors() {
        stop()

        let eventTypes: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]

        // Global monitor: catches events sent to OTHER apps
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventTypes) { [weak self] event in
            self?.handleEvent(event)
        }

        // Local monitor: catches events when THIS app is focused (Settings window, etc.)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventTypes) { [weak self] event in
            self?.handleEvent(event)
            return event  // pass through to the app
        }
    }

    private func handleEvent(_ event: NSEvent) {
        if config.isModifierOnly {
            handleModifierEvent(event)
        } else {
            handleKeyEvent(event)
        }
    }

    /// Handle regular key+modifier hotkeys (e.g., ⌃⌥Space)
    private func handleKeyEvent(_ event: NSEvent) {
        guard event.type == .keyDown || event.type == .keyUp else { return }

        let eventFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let configFlags = NSEvent.ModifierFlags(rawValue: config.modifiers)
            .intersection(.deviceIndependentFlagsMask)

        guard UInt32(event.keyCode) == config.keyCode,
              eventFlags == configFlags else {
            return
        }

        if event.type == .keyDown {
            if config.isHoldMode {
                guard !isHolding else { return }
                isHolding = true
                onKeyDown?()
            } else {
                onKeyDown?()
            }
        } else if event.type == .keyUp {
            if config.isHoldMode && isHolding {
                isHolding = false
                onKeyUp?()
            }
        }
    }

    /// Handle modifier-only hotkeys (e.g., Fn alone)
    /// Modifier keys generate flagsChanged events, not keyDown/keyUp
    private func handleModifierEvent(_ event: NSEvent) {
        guard event.type == .flagsChanged else { return }

        let configFlags = NSEvent.ModifierFlags(rawValue: config.modifiers)
        let isDown = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(configFlags)

        if isDown && !modifierKeyDown {
            // Modifier key pressed
            modifierKeyDown = true
            onKeyDown?()
        } else if !isDown && modifierKeyDown {
            // Modifier key released — only matters for hold mode
            modifierKeyDown = false
            if config.isHoldMode {
                onKeyUp?()
            }
        }
    }
}
