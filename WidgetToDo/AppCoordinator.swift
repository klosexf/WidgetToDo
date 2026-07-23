import AppKit
import SwiftUI

@MainActor
final class AppCoordinator {
    private let rootViewModel: RootViewModel
    private let floatingWindowManager: FloatingWindowManager
    private let statusBarController: StatusBarController
    private let repository: NotionRepository

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
        self.repository = repository

        rootViewModel = RootViewModel(repository: repository) { url in
            Self.openInNotion(url)
        }
        floatingWindowManager = FloatingWindowManager(rootView: ContentView(rootViewModel: rootViewModel))
        rootViewModel.windowManager = floatingWindowManager
        floatingWindowManager.onFrameChanged = { [weak rootViewModel] _ in
            Task { @MainActor [weak rootViewModel] in
                await rootViewModel?.persistMiniModeState()
            }
        }
        statusBarController = StatusBarController(
            onToggle: { [weak floatingWindowManager] in
                floatingWindowManager?.toggle()
            },
            onSettings: { [weak rootViewModel, weak floatingWindowManager] in
                floatingWindowManager?.show()
                rootViewModel?.openSettings()
            },
            onQuit: {
                NSApp.terminate(nil)
            },
            languageStore: rootViewModel.languageStore
        )
    }

    func start() {
        Task {
            let miniState = (try? await repository.loadMiniModeState()) ?? .default
            await rootViewModel.bootstrap()
            let hasValidConfiguration = rootViewModel.screen == .widget
            let effectiveState = MiniModeState(
                isMiniMode: hasValidConfiguration && miniState.isMiniMode,
                activeTab: miniState.activeTab,
                normalFrame: miniState.normalFrame
            )
            await MainActor.run {
                rootViewModel.applyMiniModeState(effectiveState)
                floatingWindowManager.show()
                statusBarController.install()
            }
        }
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
