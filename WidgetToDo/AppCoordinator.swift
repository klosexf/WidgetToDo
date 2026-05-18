import AppKit
import SwiftUI

@MainActor
final class AppCoordinator {
    private let rootViewModel: RootViewModel
    private let floatingWindowManager: FloatingWindowManager
    private let statusBarController: StatusBarController

    init() throws {
        let tokenStore = KeychainTokenStore()
        let settingsStore = try SettingsStore()
        let cache = try SQLiteCache()
        let client = NotionClient()
        let repository = NotionRepository(
            tokenStore: tokenStore,
            settingsStore: settingsStore,
            cache: cache,
            notionClient: client
        )

        rootViewModel = RootViewModel(repository: repository) { url in
            Self.openInNotion(url)
        }
        floatingWindowManager = FloatingWindowManager(rootView: ContentView(rootViewModel: rootViewModel))
        statusBarController = StatusBarController(
            onToggle: { [weak floatingWindowManager] in
                floatingWindowManager?.toggle()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }

    func start() {
        floatingWindowManager.show()
        statusBarController.install()
    }

    private static func openInNotion(_ url: URL) {
        let workspace = NSWorkspace.shared
        if url.host?.contains("notion.so") == true, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.scheme = "notion"
            if let appURL = components.url, workspace.urlForApplication(toOpen: appURL) != nil {
                workspace.open(appURL)
                return
            }
        }
        workspace.open(url)
    }
}
