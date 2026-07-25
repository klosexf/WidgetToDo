import SwiftUI

@main
struct WidgetToDoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var languageStore = LanguageStore.shared

    var body: some Scene {
        Settings {
            VStack(alignment: .leading, spacing: 12) {
                Text(languageStore.text(.appTitle))
                    .font(.title3.weight(.semibold))
                Text(languageStore.text(.settingsSceneHint))
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(width: 320)
        }
    }
}
