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
                OnboardingView(viewModel: rootViewModel.onboardingViewModel, mode: .onboarding)
            case .settings:
                OnboardingView(
                    viewModel: rootViewModel.onboardingViewModel,
                    mode: .settings,
                    onBack: rootViewModel.returnFromSettings
                )
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
        case settings
        case widget
    }

    @Published var screen: Screen = .loading
    @Published var bannerMessage: String?
    private var screenBeforeSettings: Screen = .widget

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

    func openSettings() {
        if screen != .settings {
            screenBeforeSettings = screen
        }
        screen = .settings
        Task { @MainActor [weak self] in
            do {
                let snapshot = try await self?.onboardingViewModel.loadSnapshot()
                if let snapshot {
                    self?.todoListViewModel.newTaskViewModel.hasPriorityField = snapshot.hasPriorityField
                }
            } catch {
                self?.onboardingViewModel.statusMessage = "读取设置失败：\(error.localizedDescription)"
                self?.onboardingViewModel.isErrorState = true
            }
        }
    }

    func returnFromSettings() {
        screen = screenBeforeSettings
    }
}

struct OnboardingView: View {
    enum Mode {
        case onboarding
        case settings
    }

    @ObservedObject var viewModel: OnboardingViewModel
    let mode: Mode
    var onBack: (() -> Void)?
    @State private var isShowingTokenHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if mode == .settings {
                    Button {
                        onBack?()
                    } label: {
                        Label("返回", systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }

            Text(mode == .settings ? "设置" : "连接 Notion")
                .font(.title2.weight(.semibold))

            Text("这个版本需要一个 Notion 集成令牌，以及一个任务数据库和一个日记数据库。")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Notion Token")
                        .font(.headline)
                    Spacer()
                    Button {
                        isShowingTokenHelp = true
                    } label: {
                        Text("如何获取?")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("如何获取?")
                }
                SecureField("Notion Token", text: $viewModel.token)
                    .textFieldStyle(.roundedBorder)
                Text("令牌只保存在本机钥匙串。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Tasks Database ID")
                        .font(.headline)
                    Spacer()
                    Text("粘贴整个URL自动提取")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("任务数据库 URL 或 ID", text: $viewModel.tasksDatabaseInput)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.tasksDatabaseInput) { _ in
                        viewModel.normalizeTasksDatabaseInput()
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Journal Database ID")
                        .font(.headline)
                    Spacer()
                    Text("粘贴整个URL自动提取")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("日记数据库 URL 或 ID", text: $viewModel.journalDatabaseInput)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.journalDatabaseInput) { _ in
                        viewModel.normalizeJournalDatabaseInput()
                    }
            }

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
                    Text(mode == .settings ? "保存设置" : "验证并继续")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isWorking)

            Spacer()
        }
        .padding(24)
        .sheet(isPresented: $isShowingTokenHelp) {
            NotionTokenHelpView()
        }
    }
}

private struct NotionTokenHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("获取 Notion Token")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("1. 打开 Notion 的 My integrations，创建一个 Internal Integration。")
                Text("2. 在该 integration 的 Configuration 页面复制 Installation access token。")
                Text("3. 打开 Tasks 和 Journal 数据库右上角菜单，把这个 integration 添加到 Connections。")
                Text("4. 回到这里粘贴 token，并把两个数据库的完整 URL 粘贴到对应输入框。")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Link("打开 Notion integrations", destination: URL(string: "https://www.notion.so/my-integrations")!)

            Spacer()
        }
        .padding(24)
        .frame(width: 420, height: 260)
    }
}

struct FloatingWidgetView: View {
    private let todoDateTitleWidth: CGFloat = 104
    private let jumpToTodayWidth: CGFloat = 56
    @ObservedObject var todoViewModel: TodoListViewModel
    @ObservedObject var journalViewModel: JournalViewModel
    @ObservedObject private var newTaskViewModel: NewTaskViewModel
    @State private var taskPendingDeletion: TaskItem?
    let refreshAction: @MainActor () async -> Void
    var bannerMessage: String?

    init(
        todoViewModel: TodoListViewModel,
        journalViewModel: JournalViewModel,
        refreshAction: @escaping @MainActor () async -> Void,
        bannerMessage: String?
    ) {
        self.todoViewModel = todoViewModel
        self.journalViewModel = journalViewModel
        _newTaskViewModel = ObservedObject(wrappedValue: todoViewModel.newTaskViewModel)
        self.refreshAction = refreshAction
        self.bannerMessage = bannerMessage
    }

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
                    Button {
                        Task {
                            await todoViewModel.showPreviousDay()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .help("前一天")

                    Text(todoTitle)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                        .frame(height: 28)
                        .frame(width: todoDateTitleWidth, alignment: .leading)

                    Button {
                        Task {
                            await todoViewModel.showNextDay()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .help("后一天")

                    Button("回到今天") {
                        guard !todoViewModel.isShowingToday else { return }
                        Task {
                            await todoViewModel.jumpToToday()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .frame(width: jumpToTodayWidth, alignment: .leading)
                    .opacity(todoViewModel.isShowingToday ? 0 : 1)
                    .allowsHitTesting(!todoViewModel.isShowingToday)
                    .accessibilityHidden(todoViewModel.isShowingToday)

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

                    if todoViewModel.tasksDatabaseURL != nil {
                        Button {
                            todoViewModel.openTasksDatabaseInNotion()
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

                                if todoViewModel.deletingTaskID == task.id {
                                    ProgressView()
                                        .controlSize(.small)
                                }

                                if task.syncStatus == .failed {
                                    Button("重试") {
                                        Task {
                                            await todoViewModel.retry(task)
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                }

                                Menu {
                                    taskActionMenu(for: task)
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .menuStyle(.borderlessButton)
                                .menuIndicator(.hidden)
                            }
                            .padding(.vertical, 4)
                            .contextMenu {
                                taskActionMenu(for: task)
                            }
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

            if newTaskViewModel.showForm {
                Color.black.opacity(0.3)
                    .onTapGesture {
                        newTaskViewModel.dismissForm()
                    }
                NewTaskFormCard(viewModel: newTaskViewModel)
            }

            if todoViewModel.editingTask != nil {
                Color.black.opacity(0.3)
                    .onTapGesture {
                        guard !todoViewModel.isSavingTaskEdit else { return }
                        todoViewModel.cancelEditing()
                    }
                EditTaskFormCard(viewModel: todoViewModel)
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
        .confirmationDialog(
            "删除这个任务？",
            isPresented: Binding(
                get: { taskPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        taskPendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let taskPendingDeletion {
                Button("删除任务", role: .destructive) {
                    let taskToDelete = taskPendingDeletion
                    self.taskPendingDeletion = nil
                    Task {
                        await todoViewModel.deleteTask(taskToDelete)
                    }
                }
            }
        } message: {
            Text("删除后会在 Notion 中归档该任务，无法在这里直接恢复。")
        }
    }

    @ViewBuilder
    private func taskActionMenu(for task: TaskItem) -> some View {
        Button("编辑任务") {
            todoViewModel.beginEditing(task)
        }

        Button("删除任务", role: .destructive) {
            taskPendingDeletion = task
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

            Text(emptyTasksTitle)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var todoTitle: String {
        TodoDateDisplayFormatter.title(for: todoViewModel.selectedDate)
    }

    private var emptyTasksTitle: String {
        TodoDateDisplayFormatter.emptyStateTitle(for: todoViewModel.selectedDate)
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

struct EditTaskFormCard: View {
    @ObservedObject var viewModel: TodoListViewModel
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("编辑任务")
                .font(.system(size: 14, weight: .medium))

            TextField("标题(必填)", text: $viewModel.editingTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .disabled(viewModel.isSavingTaskEdit)
                .focused($isTitleFocused)
                .onAppear {
                    isTitleFocused = true
                }

            if viewModel.errorMessage == "任务标题不能为空。" {
                Text("任务标题不能为空。")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("取消") {
                    viewModel.cancelEditing()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .disabled(viewModel.isSavingTaskEdit)

                Spacer()

                if viewModel.isSavingTaskEdit {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("保存") {
                    Task {
                        await viewModel.saveTaskEdit()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.accentColor)
                .disabled(viewModel.isSavingTaskEdit)
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
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
    OnboardingView(viewModel: makePreviewOnboardingViewModel(), mode: .onboarding)
        .frame(width: 340, height: 560)
}

#Preview("设置") {
    OnboardingView(viewModel: makePreviewOnboardingViewModel(), mode: .settings, onBack: {})
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
