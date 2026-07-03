import AppKit
import StandupKit
import SwiftUI

@MainActor
final class OverlayPanel: OverlayPresenting {
    private var controlPanels: [NSPanel] = []
    private var originalFrames: [NSRect] = []

    /// Builds the SwiftUI content rendered inside the overlay. Set by the app
    /// once the manager exists, so the panel stays decoupled from the core.
    var content: (() -> AnyView)?

    /// Transparent margin baked around the content so the ribbon's drop shadow
    /// renders in full instead of being clipped by the (otherwise content-tight)
    /// window frame. Must cover the largest shadow extent (radius + |y offset|)
    /// of any overlay mode — see the shadows in `OverlayView`.
    private static let shadowRoom: CGFloat = 28

    func show(position: BannerPosition = .topCenter) {
        close()
        guard let content else { return }
        for screen in NSScreen.screens {
            placeControl(controlContent: content(), on: screen, position: position)
        }
    }

    func close() {
        for panel in controlPanels { panel.close() }
        controlPanels.removeAll()
        originalFrames.removeAll()
    }

    func resetPosition() {
        for (i, panel) in controlPanels.enumerated() where i < originalFrames.count {
            panel.setFrame(originalFrames[i], display: true)
        }
    }

    var isVisible: Bool {
        !controlPanels.isEmpty
    }

    // MARK: - Private

    private func placeControl(controlContent: some View, on screen: NSScreen, position: BannerPosition) {
        let control = makePanel()
        control.ignoresMouseEvents = false
        control.level = .screenSaver + 1
        control.isMovableByWindowBackground = true

        // The overlay content changes size across the standup lifecycle (count-in
        // circle → drain banner → ring → finished panel) and at the banner⇄ring
        // toggle. A one-shot `fittingSize` at creation can't follow that, so we
        // MEASURE the live content and resize + re-anchor the panel on every
        // change. The padding gives the drop shadow room to render uncliped.
        let measured = controlContent
            .padding(Self.shadowRoom)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: OverlaySizeKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(OverlaySizeKey.self) { [weak self, weak control] size in
                guard let self, let control else { return }
                Task { @MainActor in
                    self.fit(control, to: size, on: screen, position: position)
                }
            }

        let controlHost = NSHostingView(rootView: measured)
        control.contentView = controlHost

        // Give it the full visible frame to start so the content lays out at its
        // ideal size; the first size measurement immediately shrinks + anchors it.
        // Stay INVISIBLE until that first `fit` lands it at the anchored spot —
        // otherwise the ribbon is briefly drawn full-width and appears to jump
        // from the left to the centre when the standup starts.
        control.alphaValue = 0
        control.setFrame(screen.visibleFrame, display: false)
        control.orderFrontRegardless()
        controlPanels.append(control)
        originalFrames.append(screen.visibleFrame)
    }

    /// Resize the panel to the measured content size and pin it to the requested
    /// corner of the screen's visible frame. Keeps `originalFrames` in sync so a
    /// post-drag `resetPosition()` returns to the anchored spot.
    private func fit(_ panel: NSPanel, to size: CGSize, on screen: NSScreen, position: BannerPosition) {
        guard size.width > 1, size.height > 1 else { return }
        let v = screen.visibleFrame
        let margin: CGFloat = 8
        let w = size.width
        let h = size.height

        let x: CGFloat
        switch position {
        case .topLeft, .bottomLeft: x = v.minX + margin
        case .topRight, .bottomRight: x = v.maxX - w - margin
        case .topCenter, .bottomCenter: x = v.midX - w / 2
        }

        let y: CGFloat
        switch position {
        case .topCenter, .topLeft, .topRight: y = v.maxY - h - margin
        case .bottomCenter, .bottomLeft, .bottomRight: y = v.minY + margin
        }

        let frame = NSRect(x: x, y: y, width: w, height: h)
        guard panel.frame != frame else {
            // Already anchored — just make sure the (initially hidden) panel is
            // now visible.
            if panel.alphaValue < 1 { panel.alphaValue = 1 }
            return
        }
        panel.setFrame(frame, display: true)
        // Reveal on the first successful anchor, once it is at the right spot.
        if panel.alphaValue < 1 { panel.alphaValue = 1 }
        if let i = controlPanels.firstIndex(of: panel), i < originalFrames.count {
            originalFrames[i] = frame
        }
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

/// Carries the live size of the overlay content out of SwiftUI so the AppKit
/// panel can resize + re-anchor to it.
private struct OverlaySizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
