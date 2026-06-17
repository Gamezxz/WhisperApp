import SwiftUI
import AppKit
import Carbon.HIToolbox

/// SwiftUI view that captures a key combination and displays it
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var hotkey: HotkeyConfig
    var isRecording: Binding<Bool>

    func makeNSView(context: Context) -> HotkeyCaptureView {
        let view = HotkeyCaptureView()
        view.onKeyCapture = { keyCode, modifiers, isModOnly in
            hotkey.keyCode = keyCode
            hotkey.modifiers = modifiers
            hotkey.isModifierOnly = isModOnly
            isRecording.wrappedValue = false
        }
        view.isRecording = isRecording
        return view
    }

    func updateNSView(_ nsView: HotkeyCaptureView, context: Context) {
        nsView.currentDisplay = hotkey.displayString
        nsView.isRecording = isRecording
        nsView.needsDisplay = true
    }
}

class HotkeyCaptureView: NSView {
    var onKeyCapture: ((UInt32, UInt, Bool) -> Void)?
    var isRecording: Binding<Bool> = .constant(false)
    var currentDisplay: String = ""

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bgColor: NSColor = isRecording.wrappedValue
            ? .systemBlue.withAlphaComponent(0.15)
            : .controlBackgroundColor
        let borderColor: NSColor = isRecording.wrappedValue ? .systemBlue : .separatorColor

        bgColor.setFill()
        borderColor.setStroke()

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        path.fill()
        path.lineWidth = isRecording.wrappedValue ? 2 : 1
        path.stroke()

        let text = isRecording.wrappedValue ? "Press keys…" : currentDisplay
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: {
                let p = NSMutableParagraphStyle()
                p.alignment = .center
                return p
            }()
        ]
        let nsText = text as NSString
        let textSize = nsText.size(withAttributes: attrs)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        nsText.draw(in: textRect, withAttributes: attrs)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording.wrappedValue else {
            super.keyDown(with: event)
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Escape alone cancels recording
        if event.keyCode == UInt16(kVK_Escape) && flags.isEmpty {
            isRecording.wrappedValue = false
            needsDisplay = true
            return
        }

        // Accept key + optional modifiers
        onKeyCapture?(UInt32(event.keyCode), flags.rawValue, false)
    }

    /// Capture modifier-only keys (Fn, Ctrl, Option, etc.)
    override func flagsChanged(with event: NSEvent) {
        guard isRecording.wrappedValue else {
            needsDisplay = true
            return
        }

        let keyCode = UInt32(event.keyCode)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Modifier key codes: Fn=63, Cmd=55/54, Shift=56/60, Opt=58/61, Ctrl=59/62, CapsLock=57
        let modifierKeyCodes: Set<UInt32> = [63, 55, 54, 56, 60, 58, 61, 59, 62, 57]
        guard modifierKeyCodes.contains(keyCode) else {
            needsDisplay = true
            return
        }

        // Check if this is a key-down (flag added) rather than key-up (flag removed)
        let isDown: Bool
        if keyCode == 63 {  // Fn
            isDown = flags.contains(.function)
        } else if keyCode == 55 || keyCode == 54 {  // Command
            isDown = flags.contains(.command)
        } else if keyCode == 56 || keyCode == 60 {  // Shift
            isDown = flags.contains(.shift)
        } else if keyCode == 58 || keyCode == 61 {  // Option
            isDown = flags.contains(.option)
        } else if keyCode == 59 || keyCode == 62 {  // Control
            isDown = flags.contains(.control)
        } else {
            isDown = !flags.isEmpty
        }

        guard isDown else {
            needsDisplay = true
            return
        }

        // Capture as modifier-only hotkey
        let modFlags: NSEvent.ModifierFlags
        if keyCode == 63 { modFlags = .function }
        else if keyCode == 55 || keyCode == 54 { modFlags = .command }
        else if keyCode == 56 || keyCode == 60 { modFlags = .shift }
        else if keyCode == 58 || keyCode == 61 { modFlags = .option }
        else if keyCode == 59 || keyCode == 62 { modFlags = .control }
        else { modFlags = flags }

        onKeyCapture?(keyCode, modFlags.rawValue, true)
    }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }
}
