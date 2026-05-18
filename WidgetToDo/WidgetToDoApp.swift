import SwiftUI

@main
struct WidgetToDoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            VStack(alignment: .leading, spacing: 12) {
                Text("Notion 浮窗")
                    .font(.title3.weight(.semibold))
                Text("使用菜单栏图标来显示或隐藏悬浮面板。")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(width: 320)
        }
    }
}
