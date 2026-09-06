import AppKit
import Network
import SwiftUI

@MainActor
final class AppCoordinator {
    private let rootViewModel: RootViewModel
    private let floatingWindowManager: FloatingWindowManager
    private let statusBarController: StatusBarController
    private let repository: NotionRepository
    private let mutationSyncScheduler: MutationSyncScheduler
    private let networkPathMonitor = NWPathMonitor()

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

        // 待定变更自动重试：启动与网络恢复时触发；成功后刷新列表与日记同步状态。
        let viewModel = rootViewModel
        mutationSyncScheduler = MutationSyncScheduler {
            let result = await repository.drainPendingMutations()
            guard result.replayed > 0 else { return }
            // 只刷新任务列表与日记同步状态，不做整页 reload，避免打断正在输入的日记。
            Task { @MainActor in
                await viewModel.todoListViewModel.load()
                await viewModel.journalViewModel.refreshSyncStatus()
            }
        }
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
            // 启动时重放上次会话遗留的待定变更；失败（离线等）等网络恢复再触发。
            await mutationSyncScheduler.requestDrain()
        }

        // 网络恢复时自动重试待定变更。
        networkPathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { await self?.mutationSyncScheduler.requestDrain() }
        }
        networkPathMonitor.start(queue: DispatchQueue(label: "com.notionfloat.network-path-monitor", qos: .utility))
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
