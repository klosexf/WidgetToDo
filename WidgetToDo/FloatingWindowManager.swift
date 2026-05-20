import AppKit
import SwiftUI

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

@MainActor
final class FloatingWindowManager: NSObject {
    private let panel: NSPanel
    private var pendingSnapTask: Task<Void, Never>?
    private var isDragging = false
    private var isSnappingToSlot = false
    private var overlayController: WindowSnapOverlayController?
    private var activeScreen: NSScreen?
    private var slotLayout: WindowSnapLayoutEngine.SlotLayout?
    private var activeSlotID: String?
    private let snapConfiguration = WindowSnapLayoutEngine.Configuration(
        horizontalGap: 32,
        verticalGap: 32,
        softSnapRadius: 90,
        hardSnapRadius: 160,
        reanchorDistance: 120
    )

    init(rootView: ContentView) {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 240, y: 240, width: 340, height: 560),
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
    }

    deinit {
        pendingSnapTask?.cancel()
    }

    func show() {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    private func beginDragging() {
        guard !isDragging else { return }
        isDragging = true
        pendingSnapTask?.cancel()
        activeScreen = screenForCurrentPanelFrame()
        refreshSlotLayout(force: true)
        updateOverlaySelection()
    }

    private func scheduleFinishDragging() {
        pendingSnapTask?.cancel()
        pendingSnapTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            self?.finishDragging()
        }
    }

    private func updateDragging() {
        guard isDragging, !isSnappingToSlot else { return }
        refreshSlotLayout(force: false)
        updateOverlaySelection()
        scheduleFinishDragging()
    }

    private func finishDragging() {
        guard isDragging else { return }
        pendingSnapTask?.cancel()

        guard
            let screen = activeScreen ?? screenForCurrentPanelFrame(),
            let slotLayout
        else {
            cleanupDragState()
            return
        }

        let selection = WindowSnapLayoutEngine.selectNearestSlot(
            for: panel.frame,
            from: slotLayout.slots,
            configuration: snapConfiguration
        )

        let targetOrigin: CGPoint
        if let slot = selection.slot, selection.isWithinHardRadius {
            targetOrigin = WindowSnapLayoutEngine.clampPanelOrigin(
                slot.origin,
                panelSize: panel.frame.size,
                visibleFrame: screen.visibleFrame
            )
        } else {
            targetOrigin = WindowSnapLayoutEngine.clampPanelOrigin(
                panel.frame.origin,
                panelSize: panel.frame.size,
                visibleFrame: screen.visibleFrame
            )
        }

        guard targetOrigin != panel.frame.origin else {
            cleanupDragState()
            return
        }

        isSnappingToSlot = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(targetOrigin)
        } completionHandler: { [weak self] in
            self?.isSnappingToSlot = false
            self?.cleanupDragState()
        }
    }

    private func refreshSlotLayout(force: Bool) {
        guard let screen = screenForCurrentPanelFrame() else { return }
        activeScreen = screen

        if overlayController == nil {
            overlayController = WindowSnapOverlayController(screenFrame: screen.frame)
        }

        if force || shouldReanchorLayout(for: panel.frame) {
            slotLayout = WindowSnapLayoutEngine.generateSlots(
                around: panel.frame,
                visibleFrame: screen.visibleFrame,
                configuration: snapConfiguration
            )
        }

        overlayController?.show(on: screen)
    }

    private func shouldReanchorLayout(for frame: CGRect) -> Bool {
        guard let slotLayout else { return true }
        return WindowSnapLayoutEngine.shouldReanchor(
            from: slotLayout.anchorOrigin,
            to: frame,
            configuration: snapConfiguration
        )
    }

    private func updateOverlaySelection() {
        guard let slotLayout else { return }
        let selection = WindowSnapLayoutEngine.selectNearestSlot(
            for: panel.frame,
            from: slotLayout.slots,
            configuration: snapConfiguration
        )
        activeSlotID = selection.slot?.id
        let previewFrame = selection.isWithinHardRadius ? selection.slot?.panelFrame : nil
        overlayController?.update(
            slots: slotLayout.slots,
            activeSlotID: activeSlotID,
            previewFrame: previewFrame
        )
    }

    private func cleanupDragState() {
        isDragging = false
        activeSlotID = nil
        slotLayout = nil
        overlayController?.hide()
    }

    private func screenForCurrentPanelFrame() -> NSScreen? {
        panel.screen
            ?? NSScreen.screens.max(by: { lhs, rhs in
                lhs.frame.intersection(panel.frame).area < rhs.frame.intersection(panel.frame).area
            })
            ?? NSScreen.main
    }
}

extension FloatingWindowManager: NSWindowDelegate {
    func windowWillMove(_ notification: Notification) {
        pendingSnapTask?.cancel()
        beginDragging()
    }

    func windowDidMove(_ notification: Notification) {
        updateDragging()
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull else { return 0 }
        return width * height
    }
}
