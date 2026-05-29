import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onToggle: () -> Void
    private let onSettings: () -> Void
    private let onQuit: () -> Void
    private var menu: NSMenu?
    private var rightClickMonitor: Any?

    init(
        onToggle: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onToggle = onToggle
        self.onSettings = onSettings
        self.onQuit = onQuit
    }

    func install() {
        item.length = NSStatusItem.squareLength
        if let button = item.button {
            button.image = nil

            button.wantsLayer = true
            button.layer?.backgroundColor = NSColor.clear.cgColor

            button.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }

            let iconSize: CGFloat = 18
            let offsetX = max(0, (button.bounds.width - iconSize) / 2)
            let offsetY = max(0, (button.bounds.height - iconSize) / 2)

            let docLayer = CAShapeLayer()
            docLayer.frame = NSRect(x: offsetX, y: offsetY, width: iconSize, height: iconSize)
            docLayer.path = Self.makeDocOutlinePath(size: 18)
            docLayer.strokeColor = NSColor.white.cgColor
            docLayer.fillColor = NSColor.clear.cgColor
            docLayer.lineWidth = 1.4
            docLayer.lineCap = .round
            docLayer.lineJoin = .round
            button.layer?.addSublayer(docLayer)

            let checkLayer = CAShapeLayer()
            checkLayer.frame = NSRect(x: offsetX, y: offsetY, width: iconSize, height: iconSize)
            checkLayer.path = Self.makeCheckPath(size: 18)
            checkLayer.strokeColor = NSColor.white.cgColor
            checkLayer.fillColor = NSColor.clear.cgColor
            checkLayer.lineWidth = 1.7
            checkLayer.lineCap = .round
            checkLayer.lineJoin = .round
            button.layer?.addSublayer(checkLayer)

            button.attributedTitle = NSAttributedString(
                string: "     ",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 1),
                    .foregroundColor: NSColor.clear
                ]
            )
            button.title = "     "

            button.toolTip = "Notion 浮窗"
        }

        let menu = makeMenu()
        self.menu = menu
        item.menu = menu

        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { [weak self] event in
            self?.handleRightMouseUp(event) ?? event
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示 / 隐藏 Notion 浮窗", action: #selector(togglePanel), keyEquivalent: "\\"))
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach {
            $0.target = self
        }
        return menu
    }

    private func handleRightMouseUp(_ event: NSEvent) -> NSEvent? {
        guard let button = item.button,
              let buttonWindow = button.window,
              event.window === buttonWindow else { return event }

        let clickPoint = button.convert(event.locationInWindow, from: nil)
        guard button.bounds.contains(clickPoint), let menu else { return event }
        NSMenu.popUpContextMenu(menu, with: event, for: button)
        return nil
    }

    @objc
    private func togglePanel() {
        onToggle()
    }

    @objc
    private func openSettings() {
        onSettings()
    }

    @objc
    private func quit() {
        onQuit()
    }

    private static func makeDocOutlinePath(size: CGFloat) -> CGPath {
        let s = size / 16.0
        let path = CGMutablePath()
        // Y 坐标已翻转：lockFocus(原点左上角) → CAShapeLayer(原点左下角)
        path.move(to: CGPoint(x: 3.5 * s, y: 14.5 * s))
        path.addLine(to: CGPoint(x: 3.5 * s, y: 1.5 * s))
        path.addLine(to: CGPoint(x: 9.0 * s, y: 1.5 * s))
        path.addLine(to: CGPoint(x: 12.5 * s, y: 5.0 * s))
        path.addLine(to: CGPoint(x: 12.5 * s, y: 14.5 * s))
        path.closeSubpath()
        path.move(to: CGPoint(x: 9.0 * s, y: 1.5 * s))
        path.addLine(to: CGPoint(x: 9.0 * s, y: 5.0 * s))
        path.addLine(to: CGPoint(x: 12.5 * s, y: 5.0 * s))
        return path
    }

    private static func makeCheckPath(size: CGFloat) -> CGPath {
        let s = size / 16.0
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 5.8 * s, y: 9.5 * s))
        path.addLine(to: CGPoint(x: 7.2 * s, y: 11.0 * s))
        path.addLine(to: CGPoint(x: 10.5 * s, y: 7.5 * s))
        return path
    }
}
