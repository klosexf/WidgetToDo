import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onToggle: () -> Void
    private let onNewTask: () -> Void
    private let onQuit: () -> Void

    init(onToggle: @escaping () -> Void, onNewTask: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onNewTask = onNewTask
        self.onQuit = onQuit
    }

    func install() {
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Notion 浮窗")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示 / 隐藏 Notion 浮窗", action: #selector(togglePanel), keyEquivalent: "\\"))
        menu.addItem(NSMenuItem(title: "新建任务", action: #selector(newTask), keyEquivalent: "n"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach {
            $0.target = self
        }
        item.menu = menu
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
    private func quit() {
        onQuit()
    }
}
