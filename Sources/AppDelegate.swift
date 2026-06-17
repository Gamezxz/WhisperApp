import AppKit
import SwiftUI
import Combine
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    let controller = DictationController()

    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var cancellables = Set<AnyCancellable>()

    private var settingsWindow: NSWindow?

    private var toggleItem: NSMenuItem!
    private var cloudItem: NSMenuItem!
    private var correctionItem: NSMenuItem!
    private var thItem: NSMenuItem!
    private var enItem: NSMenuItem!
    private var autoItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        KeyStore.prewarm()
        setupStatusItem()
        setupPanel()
        setupHotkey()

        // Update icon / panel based on processing stage
        controller.$stage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stage in
                guard let self = self else { return }
                self.statusItem.button?.image = NSImage(
                    systemSymbolName: Self.iconName(for: stage),
                    accessibilityDescription: "Whisper"
                )
                let hk = HotkeyManager.shared.currentConfig.displayString
                if stage == .recording {
                    self.toggleItem.title = "Stop Speaking (\(hk))"
                } else if stage == .idle {
                    self.toggleItem.title = "Start Speaking (\(hk))"
                }
                if stage == .idle { self.hidePanel() } else { self.showPanel() }
            }
            .store(in: &cancellables)

        controller.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] s in self?.statusItem.button?.toolTip = s }
            .store(in: &cancellables)

        // Request Accessibility permission once (required for auto ⌘V paste)
        Paster.promptAccessibilityOnce()
    }

    // MARK: - Status bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Whisper")

        let menu = NSMenu()
        let hk = HotkeyManager.shared.currentConfig.displayString
        toggleItem = NSMenuItem(title: "Start Speaking (\(hk))", action: #selector(toggleAction), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        cloudItem = NSMenuItem(title: "STT: Cloud", action: #selector(toggleCloud), keyEquivalent: "")
        cloudItem.target = self
        correctionItem = NSMenuItem(title: "AI Correction", action: #selector(toggleCorrection), keyEquivalent: "")
        correctionItem.target = self
        menu.addItem(cloudItem)
        menu.addItem(correctionItem)
        menu.addItem(.separator())

        let langMenu = NSMenu()
        thItem = NSMenuItem(title: "Thai", action: #selector(setThai), keyEquivalent: "")
        autoItem = NSMenuItem(title: "Auto", action: #selector(setAuto), keyEquivalent: "")
        enItem = NSMenuItem(title: "English", action: #selector(setEnglish), keyEquivalent: "")
        [thItem, autoItem, enItem].forEach { $0?.target = self; langMenu.addItem($0!) }
        let langParent = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        langParent.submenu = langMenu
        menu.addItem(langParent)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        menu.delegate = self
        statusItem.menu = menu
        updateStates()
    }

    func menuWillOpen(_ menu: NSMenu) { updateStates() }

    private func updateStates() {
        cloudItem.state = controller.useCloudSTT ? .on : .off
        cloudItem.title = "STT: Cloud (\(STTSettings.current.name))"
        correctionItem.state = controller.useCorrection ? .on : .off
        correctionItem.title = "AI Correction (\(LLMSettings.current.name))"
        let hk = HotkeyManager.shared.currentConfig.displayString
        toggleItem.title = controller.isRecording ? "Stop Speaking (\(hk))" : "Start Speaking (\(hk))"
        thItem.state = controller.language == "th" ? .on : .off
        autoItem.state = controller.language == "auto" ? .on : .off
        enItem.state = controller.language == "en" ? .on : .off
    }

    @objc private func toggleAction() { controller.toggle() }
    @objc private func toggleCloud() { controller.useCloudSTT.toggle(); updateStates() }
    @objc private func toggleCorrection() { controller.useCorrection.toggle(); updateStates() }
    @objc private func setThai() { controller.language = "th"; updateStates() }
    @objc private func setAuto() { controller.language = "auto"; updateStates() }
    @objc private func setEnglish() { controller.language = "en"; updateStates() }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 760),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "WhisperApp Settings"
            w.contentView = NSHostingView(rootView: SettingsView())
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            settingsWindow = w
        }
        // Menu-bar app (.accessory) can't receive keyboard focus
        // → Switch to .regular temporarily so the key fields accept input
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // Return to menu-bar mode when settings window closes (hide from Dock)
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Floating status panel

    private static func iconName(for stage: Stage) -> String {
        switch stage {
        case .recording: return "mic.fill"
        case .transcribing: return "waveform.circle"
        case .correcting: return "sparkles"
        case .done: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .idle: return "mic"
        }
    }

    private func setupPanel() {
        let hosting = NSHostingView(rootView: FloatingStatusView(controller: controller))
        let rect = NSRect(x: 0, y: 0, width: 300, height: 98)
        panel = NSPanel(contentRect: rect,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = hosting
    }

    private func showPanel() {
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.midX - panel.frame.width / 2,
                                         y: f.minY + 130))
        }
        panel.orderFrontRegardless()
    }

    private func hidePanel() {
        // Slight delay so waveform fades out smoothly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if !self.controller.isRecording { self.panel.orderOut(nil) }
        }
    }

    // MARK: - Global hotkey

    private func setupHotkey() {
        let mgr = HotkeyManager.shared

        // Toggle mode: press to start, press again to stop
        mgr.onKeyDown = { [weak self] in
            DispatchQueue.main.async { self?.controller.toggle() }
        }

        // Hold mode: keyDown → start, keyUp → stop (handled inside toggle via holdMode flag)
        // For hold mode, we need separate start/stop callbacks
        mgr.onKeyDown = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if HotkeyManager.shared.currentConfig.isHoldMode {
                    self.controller.start()
                } else {
                    self.controller.toggle()
                }
            }
        }

        mgr.onKeyUp = { [weak self] in
            DispatchQueue.main.async {
                self?.controller.stop()
            }
        }

        mgr.start()
    }
}
