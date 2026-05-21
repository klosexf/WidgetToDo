import Combine
import SwiftUI

struct ContentView: View {
    @ObservedObject var rootViewModel: RootViewModel

    var body: some View {
        Group {
            switch rootViewModel.screen {
            case .loading:
                ProgressView("正在加载 Notion Float...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .onboarding:
                OnboardingView(viewModel: rootViewModel.onboardingViewModel)
            case .widget:
                FloatingWidgetView(
                    todoViewModel: rootViewModel.todoListViewModel,
                    journalViewModel: rootViewModel.journalViewModel,
                    refreshAction: rootViewModel.refreshWorkspace,
                    bannerMessage: rootViewModel.bannerMessage
                )
            }
        }
        .frame(width: 340, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if rootViewModel.screen == .loading {
                await rootViewModel.bootstrap()
            }
        }
    }
}

@MainActor
final class RootViewModel: ObservableObject {
    enum Screen {
        case loading
        case onboarding
        case widget
    }

    @Published var screen: Screen = .loading
    @Published var bannerMessage: String?

    let onboardingViewModel: OnboardingViewModel
    let todoListViewModel: TodoListViewModel
    let journalViewModel: JournalViewModel

    init(repository: NotionRepository, openURL: @escaping @MainActor (URL) -> Void) {
        todoListViewModel = TodoListViewModel(repository: repository, hasPriorityField: true, openURL: openURL)
        journalViewModel = JournalViewModel(repository: repository, openURL: openURL)
        onboardingViewModel = OnboardingViewModel(repository: repository)
        onboardingViewModel.didFinishSetup = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.refreshWorkspace()
            }
        }
    }

    func bootstrap() async {
        do {
            let snapshot = try await onboardingViewModel.loadSnapshot()
            todoListViewModel.newTaskViewModel.hasPriorityField = snapshot.hasPriorityField
            if snapshot.hasToken, snapshot.tasksDatabaseID != nil, snapshot.journalDatabaseID != nil {
                screen = .widget
                await refreshWorkspace()
            } else {
                screen = .onboarding
            }
        } catch {
            screen = .onboarding
            bannerMessage = "启动失败：\(error.localizedDescription)"
        }
    }

    func refreshWorkspace() async {
        screen = .widget
        await todoListViewModel.load()
        await journalViewModel.load()
        if todoListViewModel.errorMessage == nil, journalViewModel.errorMessage == nil {
            bannerMessage = "刚刚同步完成"
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.bannerMessage = nil
            }
        } else if let message = todoListViewModel.errorMessage ?? journalViewModel.errorMessage {
            bannerMessage = message
        }
    }
}

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("连接 Notion")
                .font(.title2.weight(.semibold))

            Text("这个版本需要一个 Notion 集成令牌，以及一个任务数据库和一个日记数据库。")
                .foregroundStyle(.secondary)

            SecureField("内部集成令牌 / PAT", text: $viewModel.token)
                .textFieldStyle(.roundedBorder)

            TextField("任务数据库 URL 或 ID", text: $viewModel.tasksDatabaseInput)
                .textFieldStyle(.roundedBorder)

            TextField("日记数据库 URL 或 ID", text: $viewModel.journalDatabaseInput)
                .textFieldStyle(.roundedBorder)

            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(viewModel.isErrorState ? .red : .secondary)
            }

            Button {
                Task {
                    await viewModel.validateAndSave()
                }
            } label: {
                if viewModel.isWorking {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("验证并继续")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isWorking || viewModel.token.isEmpty || viewModel.tasksDatabaseInput.isEmpty || viewModel.journalDatabaseInput.isEmpty)

            Spacer()
        }
        .padding(24)
    }
}

struct FloatingWidgetView: View {
    @ObservedObject var todoViewModel: TodoListViewModel
    @ObservedObject var journalViewModel: JournalViewModel
    let refreshAction: @MainActor () async -> Void
    var bannerMessage: String?

    var body: some View {
        TabView {
            todoTab
                .tabItem {
                    Label("待办", systemImage: "checklist")
                }

            journalTab
                .tabItem {
                    Label("日记", systemImage: "book.pages")
                }
        }
    }

    private var todoTab: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("今天")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button {
                        todoViewModel.openNewTaskForm()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .help("新建任务")

                    Button {
                        Task { await refreshAction() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("刷新")

                    if let firstTaskWithUrl = todoViewModel.tasks.first(where: { $0.url != nil }) {
                        Button {
                            todoViewModel.openInNotion(firstTaskWithUrl.url!)
                        } label: {
                            Image(systemName: "arrow.up.forward.square")
                        }
                        .buttonStyle(.plain)
                        .help("在 Notion 中打开")
                    }
                }

                if let banner = bannerMessage {
                    Text(banner)
                        .font(.caption)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                if todoViewModel.isLoading {
                    ProgressView("正在加载任务...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if todoViewModel.tasks.isEmpty && todoViewModel.pendingTask == nil {
                    emptyTasksView
                } else {
                    List {
                        if let pending = todoViewModel.pendingTask {
                            PendingTodoRowView(item: pending, showFailure: todoViewModel.showFailureHighlight)
                        }
                        ForEach(todoViewModel.tasks) { task in
                            HStack(alignment: .top, spacing: 12) {
                                Button {
                                    Task {
                                        await todoViewModel.toggleTask(task)
                                    }
                                } label: {
                                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.isDone ? .green : .secondary)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .overlay(alignment: .center) {
                                            if task.isDone {
                                                Rectangle()
                                                    .fill(Color.primary)
                                                    .frame(height: 1)
                                            }
                                        }
                                    HStack(spacing: 8) {
                                        if let priority = task.priority {
                                            Text(priority)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                        }

                                        Text(syncText(for: task.syncStatus))
                                            .font(.caption)
                                            .foregroundStyle(syncColor(for: task.syncStatus))
                                    }
                                }

                                Spacer()

                                if let url = task.url {
                                    Button {
                                        todoViewModel.openInNotion(url)
                                    } label: {
                                        Image(systemName: "arrow.up.forward.square")
                                    }
                                    .buttonStyle(.plain)
                                }

                                if task.syncStatus == .failed {
                                    Button("重试") {
                                        Task {
                                            await todoViewModel.retry(task)
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }

                if let message = todoViewModel.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)

            if todoViewModel.newTaskViewModel.showForm {
                Color.black.opacity(0.3)
                    .onTapGesture {
                        todoViewModel.newTaskViewModel.dismissForm()
                    }
                NewTaskFormCard(viewModel: todoViewModel.newTaskViewModel)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ToastHostView(toast: todoViewModel.toast)
                }
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
        }
    }

    private var journalTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("日记")
                    .font(.title3.weight(.semibold))
                Spacer()
                if let url = journalViewModel.entry?.url {
                    Button {
                        journalViewModel.openInNotion(url)
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(.plain)
                }
            }

            if let entry = journalViewModel.entry {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if journalViewModel.isLoading {
                ProgressView("正在加载日记...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TextEditor(text: $journalViewModel.editorText)
                    .font(.body)
                    .padding(8)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.2))
                    }
                    .onChange(of: journalViewModel.editorText) { newValue in
                        journalViewModel.scheduleAutosave(text: newValue)
                    }
            }

            HStack {
                Text(journalViewModel.statusMessage ?? "2 秒后自动保存")
                    .font(.caption)
                    .foregroundStyle(journalViewModel.errorMessage == nil ? Color.secondary : Color.red)
                Spacer()
                if journalViewModel.entry?.syncStatus == .failed {
                    Button("重试") {
                        Task {
                            await journalViewModel.forceSave()
                        }
                    }
                }
            }
        }
        .padding(20)
    }

    private var emptyTasksView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.secondary)

            Text("今天没有任务")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func syncText(for status: SyncStatus) -> String {
        switch status {
        case .synced:
            "已同步"
        case .syncing:
            "同步中"
        case .failed:
            "失败"
        case .localPending:
            "待同步"
        }
    }

    private func syncColor(for status: SyncStatus) -> Color {
        switch status {
        case .synced:
            .secondary
        case .syncing, .localPending:
            .orange
        case .failed:
            .red
        }
    }
}

#Preview("内容 / 加载中") {
    ContentView(rootViewModel: makePreviewRootViewModel(state: .loading))
}

#Preview("内容 / 初始配置") {
    ContentView(rootViewModel: makePreviewRootViewModel(state: .onboarding))
}

#Preview("内容 / 主界面") {
    ContentView(rootViewModel: makePreviewRootViewModel(state: .widget))
}

#Preview("初始配置") {
    OnboardingView(viewModel: makePreviewOnboardingViewModel())
        .frame(width: 340, height: 560)
}

#Preview("悬浮组件") {
    FloatingWidgetView(
        todoViewModel: makePreviewTodoListViewModel(),
        journalViewModel: makePreviewJournalViewModel(),
        refreshAction: {},
        bannerMessage: "刚刚同步完成"
    )
    .frame(width: 340, height: 560)
}

private enum PreviewRootState {
    case loading
    case onboarding
    case widget
}

@MainActor
private func makePreviewRootViewModel(state: PreviewRootState) -> RootViewModel {
    let rootViewModel = RootViewModel(repository: makePreviewRepository(), openURL: { _ in })

    switch state {
    case .loading:
        rootViewModel.screen = .loading
    case .onboarding:
        rootViewModel.screen = .onboarding
        rootViewModel.onboardingViewModel.token = "secret_preview_token"
        rootViewModel.onboardingViewModel.tasksDatabaseInput = "任务数据库 ID"
        rootViewModel.onboardingViewModel.journalDatabaseInput = "日记数据库 ID"
        rootViewModel.onboardingViewModel.statusMessage = "已检测到保存在钥匙串中的令牌。"
    case .widget:
        rootViewModel.screen = .widget
        rootViewModel.bannerMessage = "刚刚同步完成"
        rootViewModel.todoListViewModel.tasks = previewTasks
        rootViewModel.journalViewModel.entry = previewJournalEntry
        rootViewModel.journalViewModel.editorText = previewJournalEntry.contentText
        rootViewModel.journalViewModel.statusMessage = "1 分钟前已自动保存"
    }

    return rootViewModel
}

@MainActor
private func makePreviewOnboardingViewModel() -> OnboardingViewModel {
    let viewModel = OnboardingViewModel(repository: makePreviewRepository())
    viewModel.token = "secret_preview_token"
    viewModel.tasksDatabaseInput = "任务数据库 ID"
    viewModel.journalDatabaseInput = "日记数据库 ID"
    viewModel.statusMessage = "请填写 Notion 集成令牌以及两个数据库引用。"
    return viewModel
}

@MainActor
private func makePreviewTodoListViewModel() -> TodoListViewModel {
    let viewModel = TodoListViewModel(repository: makePreviewRepository(), hasPriorityField: true, openURL: { _ in })
    viewModel.tasks = previewTasks
    return viewModel
}

@MainActor
private func makePreviewJournalViewModel() -> JournalViewModel {
    let viewModel = JournalViewModel(repository: makePreviewRepository(), openURL: { _ in })
    viewModel.entry = previewJournalEntry
    viewModel.editorText = previewJournalEntry.contentText
    viewModel.statusMessage = "2 秒后自动保存"
    return viewModel
}

@MainActor
private func makePreviewRepository() -> NotionRepository {
    let previewRootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("WidgetToDoPreview", isDirectory: true)

    return NotionRepository(
        tokenStore: KeychainTokenStore(),
        settingsStore: try! SettingsStore(baseURL: previewRootURL),
        cache: try! SQLiteCache(baseURL: previewRootURL),
        notionClient: NotionClient()
    )
}

private let previewTasks: [TaskItem] = [
    TaskItem(
        id: "preview-task-1",
        title: "完成菜单栏悬浮组件预览",
        isDone: false,
        priority: "高",
        date: .now,
        url: URL(string: "https://www.notion.so"),
        syncStatus: .synced
    ),
    TaskItem(
        id: "preview-task-2",
        title: "重试失败的日记同步场景",
        isDone: false,
        priority: "中",
        date: .now.addingTimeInterval(1800),
        url: nil,
        syncStatus: .failed
    ),
    TaskItem(
        id: "preview-task-3",
        title: "归档过期实验项",
        isDone: true,
        priority: "低",
        date: .now.addingTimeInterval(3600),
        url: nil,
        syncStatus: .localPending
    )
]

private let previewJournalEntry = JournalEntry(
    id: "preview-journal-entry",
    title: "日记",
    date: .now,
    contentText: """
    已完成悬浮组件的 SwiftUI 预览。

    接下来：
    - 确认 Canvas 能渲染所有状态
    - 保持运行时逻辑不变
    """,
    url: URL(string: "https://www.notion.so"),
    syncStatus: .synced
)
