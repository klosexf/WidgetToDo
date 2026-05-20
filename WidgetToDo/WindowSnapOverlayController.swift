import AppKit

@MainActor
final class WindowSnapOverlayController {
    private let window: NSWindow
    private let overlayView: OverlayView

    init(screenFrame: CGRect) {
        overlayView = OverlayView(frame: screenFrame)
        window = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = overlayView
    }

    func show(on screen: NSScreen) {
        window.setFrame(screen.frame, display: false)
        overlayView.frame = screen.frame
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    func update(slots: [WindowSnapLayoutEngine.Slot], activeSlotID: String?, previewFrame: CGRect?) {
        overlayView.slots = slots
        overlayView.activeSlotID = activeSlotID
        overlayView.previewFrame = previewFrame
        overlayView.needsDisplay = true
    }
}

private final class OverlayView: NSView {
    var slots: [WindowSnapLayoutEngine.Slot] = []
    var activeSlotID: String?
    var previewFrame: CGRect?

    override var isFlipped: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        for slot in slots where slot.isValid {
            let isActive = slot.id == activeSlotID
            let path = NSBezierPath(roundedRect: slot.panelFrame, xRadius: 36, yRadius: 36)
            (isActive ? NSColor.white.withAlphaComponent(0.18) : NSColor.white.withAlphaComponent(0.08)).setFill()
            path.fill()
            path.lineWidth = isActive ? 3 : 1.5
            (isActive ? NSColor.white.withAlphaComponent(0.58) : NSColor.white.withAlphaComponent(0.28)).setStroke()
            path.stroke()
        }

        if let previewFrame {
            let previewPath = NSBezierPath(roundedRect: previewFrame, xRadius: 36, yRadius: 36)
            previewPath.setLineDash([10, 8], count: 2, phase: 0)
            previewPath.lineWidth = 2
            NSColor.white.withAlphaComponent(0.72).setStroke()
            previewPath.stroke()
        }
    }
}
