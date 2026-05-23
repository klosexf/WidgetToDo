import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onToggle: () -> Void
    private let onNewTask: () -> Void
    private let onSettings: () -> Void
    private let onQuit: () -> Void
    private var menu: NSMenu?
    private var rightClickMonitor: Any?

    init(
        onToggle: @escaping () -> Void,
        onNewTask: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onToggle = onToggle
        self.onNewTask = onNewTask
        self.onSettings = onSettings
        self.onQuit = onQuit
    }

    func install() {
        item.length = NSStatusItem.variableLength
        if let button = item.button {
            button.image = nil
            button.attributedTitle = NSAttributedString(
                string: " N ",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                    .foregroundColor: NSColor.white
                ]
            )
            button.title = " N "
            button.wantsLayer = true
            button.layer?.backgroundColor = NSColor.black.cgColor
            button.layer?.cornerRadius = 5
            button.layer?.borderWidth = 1
            button.layer?.borderColor = NSColor.white.withAlphaComponent(0.9).cgColor
            button.toolTip = "Notion 浮窗"
            button.target = self
            button.action = #selector(handleLeftClick(_:))
            button.sendAction(on: .leftMouseUp)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示 / 隐藏 Notion 浮窗", action: #selector(togglePanel), keyEquivalent: "\\"))
        menu.addItem(NSMenuItem(title: "新建任务", action: #selector(newTask), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach {
            $0.target = self
        }
        self.menu = menu
        item.menu = nil

        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { [weak self] event in
            self?.handleRightMouseUp(event)
            return event
        }
    }

    @objc
    private func handleLeftClick(_ sender: Any?) {
        guard let button = item.button, let menu, let event = NSApp.currentEvent else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    private func handleRightMouseUp(_ event: NSEvent) {
        guard let button = item.button,
              let buttonWindow = button.window,
              event.window === buttonWindow else { return }

        let clickPoint = button.convert(event.locationInWindow, from: nil)
        guard button.bounds.contains(clickPoint), let menu else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    @objc
    private func togglePanel() {
        onToggle()
    }

    @objc
    private func newTask() {
        onNewTask()
    }

    @objc
    private func openSettings() {
        onSettings()
    }

    @objc
    private func quit() {
        onQuit()
    }
}
