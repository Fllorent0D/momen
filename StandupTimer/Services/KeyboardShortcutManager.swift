import AppKit

@Observable
@MainActor
final class KeyboardShortcutManager {
    private var localMonitor: Any?
    private var globalMonitor: Any?

    var onNext: (@MainActor () -> Void)?
    var onPause: (@MainActor () -> Void)?
    var onCancel: (@MainActor () -> Void)?

    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    func start() {
        stop()

        // Local monitor — works when app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // consume event
            }
            return event
        }

        // Global monitor — works when app is in background (requires Accessibility)
        if AXIsProcessTrusted() {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyEvent(event)
            }
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    func requestAccessibility() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Only handle plain key presses (no modifiers except shift)
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
            return false
        }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "n":
            onNext?()
            return true
        case "p":
            onPause?()
            return true
        case "c":
            onCancel?()
            return true
        default:
            return false
        }
    }
}
