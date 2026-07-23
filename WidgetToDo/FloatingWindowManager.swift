import AppKit
import SwiftUI

private final class FloatingPanel: NSPanel {
    private var dragStartMouseLocation: NSPoint?
    private var dragStartFrameOrigin: NSPoint?
    weak var frameChangeHandler: FloatingWindowManager?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
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
            frameChangeHandler?.notifyFrameChanged()
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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
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
    private var savedNormalFrame: CGRect?
    private(set) var isMiniMode: Bool = false
    private var hasInitialFrame: Bool = false

    init(rootView: ContentView) {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 240, y: 240, width: 340, height: 460),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        panel.contentViewController = WindowDragHostingController(rootView: rootView)
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        self.panel = panel
        super.init()
        panel.frameChangeHandler = self
    }

    var onFrameChanged: ((CodableRect?) -> Void)?

    func notifyFrameChanged() {
        onFrameChanged?(currentFrameForPersistence())
    }

    func setInitialState(isMiniMode: Bool, normalFrame: CodableRect?) {
        self.isMiniMode = isMiniMode
        self.savedNormalFrame = normalFrame?.cgRect
        self.hasInitialFrame = true

        let frame: CGRect
        if isMiniMode {
            let baseFrame = savedNormalFrame ?? panel.frame
            frame = MiniModeLayoutEngine.miniFrame(fromNormalFrame: baseFrame)
        } else if let savedNormalFrame {
            frame = savedNormalFrame
        } else {
            frame = panel.frame
        }
        panel.setFrame(frame, display: false)
    }

    func show() {
        let wasVisible = panel.isVisible
        if !wasVisible, !hasInitialFrame {
            panel.center()
        }
        panel.makeKeyAndOrderFront(nil)
        closeUnexpectedWindows()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func collapse(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard !isMiniMode else {
            completion?()
            return
        }
        savedNormalFrame = panel.frame
        let miniFrame = MiniModeLayoutEngine.miniFrame(fromNormalFrame: panel.frame)
        isMiniMode = true
        applyFrame(miniFrame, transition: .collapse, animated: animated, completion: completion)
    }

    func expand(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard isMiniMode else {
            completion?()
            return
        }
        let visibleFrame = currentScreenVisibleFrame()
        let expandedFrame = MiniModeLayoutEngine.expandedFrame(
            fromMiniFrame: panel.frame,
            savedNormalFrame: savedNormalFrame.map(CodableRect.init),
            visibleFrame: visibleFrame
        )
        isMiniMode = false
        applyFrame(expandedFrame, transition: .expand, animated: animated, completion: completion)
    }

    func currentFrameForPersistence() -> CodableRect? {
        isMiniMode ? savedNormalFrame.map(CodableRect.init) : CodableRect(panel.frame)
    }

    private func applyFrame(
        _ frame: CGRect,
        transition: Transition,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard shouldAnimate else {
            panel.setFrame(frame, display: true)
            completion?()
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = transition.duration
            context.timingFunction = transition.timingFunction
            panel.animator().setFrame(frame, display: true)
        }, completionHandler: {
            Task { @MainActor in
                completion?()
            }
        })
    }

    private enum Transition {
        case collapse
        case expand

        var duration: TimeInterval {
            switch self {
            case .collapse: return 0.25
            case .expand: return 0.28
            }
        }

        var timingFunction: CAMediaTimingFunction {
            // easeOut：起始速度较快，能显著降低「点了没反应」的延迟感，结束阶段自然减速
            CAMediaTimingFunction(name: .easeOut)
        }
    }

    private func currentScreenVisibleFrame() -> CGRect {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(panel.frame.origin) })
                ?? NSScreen.main
                ?? NSScreen.screens.first else {
            return NSScreen.main?.visibleFrame ?? .zero
        }
        return screen.visibleFrame
    }

    private func closeUnexpectedWindows() {
        for window in NSApp.windows where window !== panel {
            window.close()
        }
    }
}
