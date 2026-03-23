import AppKit
import SwiftUI

@MainActor
final class OverlayPanel {
    private var ribbonPanels: [NSPanel] = []
    private var controlPanels: [NSPanel] = []

    func show(ribbonContent: some View, controlContent: some View, showRibbon: Bool = true) {
        close()

        guard showRibbon else { return showControlOnly(controlContent: controlContent) }

        for screen in NSScreen.screens {
            // --- Ribbon: full-screen, click-through border ---
            let ribbon = makePanel()
            ribbon.ignoresMouseEvents = true
            ribbon.level = .screenSaver
            ribbon.setFrame(screen.frame, display: true)

            let ribbonHost = NSHostingView(rootView: ribbonContent.ignoresSafeArea())
            ribbon.contentView = ribbonHost
            ribbon.orderFrontRegardless()
            ribbonPanels.append(ribbon)

            // --- Control: interactive bar, top-center of each screen ---
            let control = makePanel()
            control.ignoresMouseEvents = false
            control.level = .screenSaver + 1
            control.isMovableByWindowBackground = true

            let controlHost = NSHostingView(rootView: controlContent)
            control.contentView = controlHost

            let size = controlHost.fittingSize
            control.setContentSize(size)

            let visible = screen.visibleFrame
            let x = visible.midX - (size.width / 2)
            let y = visible.maxY - size.height - 8
            control.setFrameOrigin(NSPoint(x: x, y: y))

            control.orderFrontRegardless()
            controlPanels.append(control)
        }
    }

    func close() {
        for panel in ribbonPanels { panel.close() }
        ribbonPanels.removeAll()
        for panel in controlPanels { panel.close() }
        controlPanels.removeAll()
    }

    var isVisible: Bool {
        !ribbonPanels.isEmpty || !controlPanels.isEmpty
    }

    // MARK: - Private

    private func showControlOnly(controlContent: some View) {
        for screen in NSScreen.screens {
            let control = makePanel()
            control.ignoresMouseEvents = false
            control.level = .screenSaver + 1
            control.isMovableByWindowBackground = true

            let controlHost = NSHostingView(rootView: controlContent)
            control.contentView = controlHost

            let size = controlHost.fittingSize
            control.setContentSize(size)

            let visible = screen.visibleFrame
            let x = visible.midX - (size.width / 2)
            let y = visible.maxY - size.height - 8
            control.setFrameOrigin(NSPoint(x: x, y: y))

            control.orderFrontRegardless()
            controlPanels.append(control)
        }
    }

    private func activeScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first!
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        return panel
    }
}
