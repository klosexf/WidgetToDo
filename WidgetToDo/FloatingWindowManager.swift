import AppKit
import SwiftUI

private final class FloatingPanel: NSPanel {
    private var dragStartMouseLocation: NSPoint?
    private var dragStartFrameOrigin: NSPoint?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }

            if !isKeyWindow {
                makeKeyAndOrderFront(nil)
            }

            dragStartMouseLocation = NSEvent.mouseLocation
            dragStartFrameOrigin = frame.origin
        } else if event.type == .leftMouseDragged,
            let dragStartMouseLocation,
            let dragStartFrameOrigin
        {
            let currentMouseLocation = NSEvent.mouseLocation
            let delta = NSPoint(
                x: currentMouseLocation.x - dragStartMouseLocation.x,
                y: currentMouseLocation.y - dragStartMouseLocation.y
            )
            setFrameOrigin(
                NSPoint(
                    x: dragStartFrameOrigin.x + delta.x,
                    y: dragStartFrameOrigin.y + delta.y
                )
            )
            return
        }
        super.sendEvent(event)

        if event.type == .leftMouseUp {
            dragStartMouseLocation = nil
            dragStartFrameOrigin = nil
        }
    }
}

private final class WindowDragHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private final class WindowDragHostingController<Content: View>: NSHostingController<Content> {
    override func loadView() {
        view = WindowDragHostingView(rootView: rootView)
    }
}

@MainActor
final class FloatingWindowManager: NSObject {
    private let panel: FloatingPanel

    init(rootView: ContentView) {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 240, y: 240, width: 340, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.hasShadow = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.contentViewController = WindowDragHostingController(rootView: rootView)
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        self.panel = panel
        super.init()
    }

    func show() {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        closeUnexpectedWindows()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    private func closeUnexpectedWindows() {
        for window in NSApp.windows where window !== panel {
            window.close()
        }
    }
}
