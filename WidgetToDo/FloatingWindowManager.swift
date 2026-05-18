import AppKit
import SwiftUI

@MainActor
final class FloatingWindowManager: NSObject {
    private let panel: NSPanel
    private var isDragging = false
    private let gridSize: CGFloat = 20
    private var localEventMonitor: Any?

    init(rootView: ContentView) {
        let panel = NSPanel(
            contentRect: NSRect(x: 240, y: 240, width: 420, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hasShadow = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.contentViewController = NSHostingController(rootView: rootView)
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        self.panel = panel
        super.init()
        panel.delegate = self

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.snapToGrid()
            return event
        }
    }

    deinit {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func show() {
        panel.center()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    private func snapToGrid() {
        guard isDragging else { return }
        isDragging = false

        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let frame = panel.frame

        var newOrigin = NSPoint(
            x: round(frame.origin.x / gridSize) * gridSize,
            y: round(frame.origin.y / gridSize) * gridSize
        )

        if newOrigin.x < visibleFrame.minX {
            newOrigin.x = visibleFrame.minX
        }
        if newOrigin.y < visibleFrame.minY {
            newOrigin.y = visibleFrame.minY
        }
        if newOrigin.x + frame.width > visibleFrame.maxX {
            newOrigin.x = visibleFrame.maxX - frame.width
        }
        if newOrigin.y + frame.height > visibleFrame.maxY {
            newOrigin.y = visibleFrame.maxY - frame.height
        }

        if newOrigin != frame.origin {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrameOrigin(newOrigin)
            }
        }
    }
}

extension FloatingWindowManager: NSWindowDelegate {
    func windowWillMove(_ notification: Notification) {
        isDragging = true
    }
}
