import Foundation
import Combine
import AppKit

enum PomodoroPrompt: Equatable, Sendable {
    case pause
    case abandon
    case manualCompletion(minutesToAdd: Int)
    case naturalEnd(minutesToAdd: Int)
    case durationWriteFailed
    case success(completedTask: Bool, minutesToAdd: Int)
}

struct FinishedPomodoroContext: Equatable {
    let taskID: String
    let taskTitle: String
    let minutesToAdd: Int
    let baseEstimatedMinutes: Int?
    var durationWriteSucceeded: Bool
}

@MainActor
final class TodoListViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published private(set) var selectedDate: Date
    @Published var isLoading = false
    @Published var errorMessage: AppMessage?
    @Published var pendingTask: PendingTaskItem?
    @Published var showFailureHighlight = false
    @Published var toast: ToastItem?
    @Published private(set) var tasksDatabaseURL: URL?
    @Published var editingTask: TaskItem?
    @Published var editingTitle = ""
    @Published var editingEstimatedMinutesText = ""
    @Published var editingEstimatedMinutesError: AppMessage?
    @Published var editingPriority: String?
    @Published var choiceField: TaskChoiceField?
    @Published var isSavingTaskEdit = false
    @Published var deletingTaskID: String?

    // MARK: - Frequent Task Names
    /// 高频任务名（时间衰减评分 Top 5，含最近使用的类型），供「快速添加」与表单「常用」标签行展示。
    @Published private(set) var frequentTaskNames: [FrequentTaskName] = []
    private let frequencyStore: TaskNameFrequencyStore

    // MARK: - Pomodoro State
    @Published private(set) var pomodoroSession: PomodoroSession?
    @Published var pomodoroStartTask: TaskItem?
    @Published var pomodoroSelectedMinutes = 25
    @Published var pomodoroCustomMinutesText = ""
    @Published var pomodoroDurationError: AppMessage?
    @Published var pomodoroPrompt: PomodoroPrompt?
    @Published var pomodoroDurationWriteError: AppMessage?
    @Published var pomodoroCompleteTaskToggle = false

    private var pomodoroEngine = PomodoroSessionEngine()
    private var pomodoroTickTask: Task<Void, Never>?
    private var finishedPomodoro: FinishedPomodoroContext?

    private let repository: NotionRepository
    private let openURL: @MainActor (URL) -> Void
    let newTaskViewModel: NewTaskViewModel
    private let calendar = Calendar(identifier: .gregorian)

    init(
        repository: NotionRepository,
        hasPriorityField: Bool,
        openURL: @escaping @MainActor (URL) -> Void,
        frequencyStore: TaskNameFrequencyStore = TaskNameFrequencyStore()
    ) {
        self.repository = repository
        self.openURL = openURL
        self.selectedDate = Date()
        self.frequencyStore = frequencyStore
        self.newTaskViewModel = NewTaskViewModel(repository: repository, hasPriorityField: hasPriorityField)

        newTaskViewModel.onSubmit = { [weak self] pendingItem in
            self?.pendingTask = pendingItem
        }

        newTaskViewModel.onCreateSuccess = { [weak self] task in
            self?.pendingTask = nil
            var tasks = self?.tasks ?? []
            tasks.insert(task, at: 0)
            self?.tasks = TaskSorting.sort(tasks)
            self?.showToast(.success, message: AppMessage(.taskCreated))
            self?.recordFrequentTaskName(task.title, priority: task.priority)
        }

        newTaskViewModel.onCreateFailure = { [weak self] pendingItem, errorMessage in
            self?.handleCreationFailure(pendingItem, errorMessage: errorMessage)
        }

        Task { @MainActor [weak self] in
            await self?.refreshFrequentTaskNames()
        }
    }

    deinit {
        pomodoroTickTask?.cancel()
    }

    func load() async {
        await load(for: selectedDate)
    }

    func load(for date: Date) async {
        selectedDate = normalizedDay(for: date)
        isLoading = true
        defer { isLoading = false }

        do {
            tasksDatabaseURL = try await repository.tasksDatabasePageURL()
            tasks = try await repository.loadTasks(for: selectedDate)
            errorMessage = nil
        } catch {
            tasksDatabaseURL = nil
            errorMessage = AppMessage(.taskSyncFailed, arguments: [error.localizedDescription])
        }
    }

    func toggleTask(_ task: TaskItem) async {
        do {
            let updated = try await repository.toggleTask(id: task.id, isDone: !task.isDone)
            tasks = TaskSorting.sort(tasks.map { $0.id == updated.id ? updated : $0 })
            errorMessage = nil
        } catch {
            tasks = TaskSorting.sort(tasks.map {
                guard $0.id == task.id else { return $0 }
                var failed = task
                failed.isDone.toggle()
                failed.syncStatus = .failed
                return failed
            })
            errorMessage = AppMessage(.taskUpdateFailed, arguments: [error.localizedDescription])
        }
    }

    func retry(_ task: TaskItem) async {
        do {
            let updated = try await repository.retryTask(id: task.id)
            tasks = TaskSorting.sort(tasks.map { $0.id == updated.id ? updated : $0 })
            errorMessage = nil
        } catch {
            errorMessage = AppMessage(.taskRetryFailed, arguments: [error.localizedDescription])
        }
    }

    func openInNotion(_ url: URL) {
        openURL(url)
    }

    func openTasksDatabaseInNotion() {
        guard let tasksDatabaseURL else { return }
        openURL(tasksDatabaseURL)
    }

    func openNewTaskForm() {
        newTaskViewModel.openForm(defaultDate: selectedDate)
    }

    /// 一键快速添加：跳过表单，以默认值（当前查看日期、该任务名最近使用的类型）创建任务。
    func quickAddTask(_ entry: FrequentTaskName) {
        newTaskViewModel.quickAdd(title: entry.name, priority: entry.priority, date: selectedDate)
    }

    private func recordFrequentTaskName(_ rawName: String, priority: String?) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.frequencyStore.record(name: name, priority: priority, now: Date())
            await self.refreshFrequentTaskNames()
        }
    }

    private func refreshFrequentTaskNames() async {
        frequentTaskNames = await frequencyStore.topEntries(limit: 5, now: Date())
    }

    func showPreviousDay() async {
        guard let previous = calendar.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        await load(for: previous)
    }

    func showNextDay() async {
        guard let next = calendar.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        await load(for: next)
    }

    func jumpToToday() async {
        await load(for: Date())
    }

    /// 月历印记：指定日期的本地缓存里是否有任务（只读，不发网络请求）。
    func hasCachedTasks(on date: Date) async -> Bool {
        guard let cached = try? await repository.cachedTasks(for: date) else { return false }
        return !cached.isEmpty
    }

    /// 月历印记（远端刷新）：拉取 monthAnchor 所在月「有任务」的日期（day -> true），
    /// 并把本地缓存缺失的任务补进缓存。网络失败返回空表（保持缓存印记不变）。
    func refreshMonthTaskDays(containing monthAnchor: Date) async -> [Int: Bool] {
        (try? await repository.refreshTaskMarks(containing: monthAnchor)) ?? [:]
    }

    var isShowingToday: Bool {
        calendar.isDate(selectedDate, inSameDayAs: Date())
    }

    func beginEditing(_ task: TaskItem) {
        editingTask = task
        editingTitle = task.title
        editingEstimatedMinutesText = task.estimatedMinutes.map(String.init) ?? ""
        editingEstimatedMinutesError = nil
        editingPriority = task.priority
        errorMessage = nil
    }

    func cancelEditing() {
        editingTask = nil
        editingTitle = ""
        editingEstimatedMinutesText = ""
        editingEstimatedMinutesError = nil
        editingPriority = nil
        isSavingTaskEdit = false
    }

    func saveTaskEdit() async {
        guard let task = editingTask else { return }

        let trimmedTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = AppMessage(.taskTitleRequired)
            return
        }

        let parsedEstimatedMinutes = parseEditingEstimatedMinutes()
        if !editingEstimatedMinutesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           parsedEstimatedMinutes == nil {
            editingEstimatedMinutesError = AppMessage(.estimatedMinutesInvalid)
            return
        }
        editingEstimatedMinutesError = nil

        isSavingTaskEdit = true
        defer { isSavingTaskEdit = false }

        do {
            let updated = try await repository.updateTaskTitle(
                id: task.id,
                title: trimmedTitle,
                priority: editingPriority,
                estimatedMinutes: parsedEstimatedMinutes
            )
            tasks = TaskSorting.sort(tasks.map { $0.id == updated.id ? updated : $0 })
            errorMessage = nil
            cancelEditing()
            showToast(.success, message: AppMessage(.taskUpdated))
        } catch {
            errorMessage = AppMessage(.taskUpdateFailed, arguments: [error.localizedDescription])
        }
    }

    func configure(choiceField: TaskChoiceField?) {
        self.choiceField = choiceField
        newTaskViewModel.choiceField = choiceField
        newTaskViewModel.hasPriorityField = choiceField != nil
    }

    private func parseEditingEstimatedMinutes() -> Int? {
        let trimmed = editingEstimatedMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let parsed = Int(trimmed), parsed > 0 else { return nil }
        return parsed
    }

    func deleteTask(_ task: TaskItem) async {
        deletingTaskID = task.id
        defer { deletingTaskID = nil }

        do {
            try await repository.deleteTask(id: task.id)
            tasks.removeAll { $0.id == task.id }
            errorMessage = nil
            if editingTask?.id == task.id {
                cancelEditing()
            }
            showToast(.success, message: AppMessage(.taskDeleted))
        } catch {
            errorMessage = AppMessage(.taskDeleteFailed, arguments: [error.localizedDescription])
        }
    }

    private func handleCreationFailure(_ pendingItem: PendingTaskItem, errorMessage: String) {
        showFailureHighlight = true
        showToast(.taskCreateFailed, message: AppMessage(.taskCreateFailed, arguments: [errorMessage]))

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self?.showFailureHighlight = false
            self?.pendingTask = nil
        }
    }

    private func showToast(_ kind: ToastKind, message: AppMessage) {
        toast = ToastItem(kind: kind, message: message)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.toast = nil
        }
    }

    private func normalizedDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    // MARK: - Pomodoro Actions

    func presentPomodoroStart(for task: TaskItem) {
        guard pomodoroSession == nil, pomodoroStartTask == nil else { return }
        pomodoroStartTask = task
        pomodoroSelectedMinutes = 25
        pomodoroCustomMinutesText = ""
        pomodoroDurationError = nil
    }

    func cancelPomodoroStart() {
        pomodoroStartTask = nil
        pomodoroCustomMinutesText = ""
        pomodoroDurationError = nil
    }

    func selectPomodoroPreset(_ minutes: Int) {
        pomodoroSelectedMinutes = minutes
        pomodoroCustomMinutesText = ""
        pomodoroDurationError = nil
    }

    func validatePomodoroCustomMinutes() -> Int? {
        let trimmed = pomodoroCustomMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let parsed = Int(trimmed),
              PomodoroSession.isValidDuration(parsed) else {
            return nil
        }
        return parsed
    }

    func beginPomodoro() {
        guard pomodoroSession == nil, let task = pomodoroStartTask else { return }

        let durationMinutes: Int
        if pomodoroSelectedMinutes == 25 || pomodoroSelectedMinutes == 45 {
            durationMinutes = pomodoroSelectedMinutes
        } else {
            guard let custom = validatePomodoroCustomMinutes() else {
                pomodoroDurationError = AppMessage(.pomodoroDurationError)
                return
            }
            durationMinutes = custom
        }

        pomodoroEngine.start(task: task, durationMinutes: durationMinutes, at: Date())
        pomodoroSession = pomodoroEngine.session
        pomodoroStartTask = nil
        pomodoroCustomMinutesText = ""
        pomodoroDurationError = nil
        startPomodoroTick()
    }

    func pausePomodoro() {
        guard pomodoroSession?.phase == .running else { return }
        pomodoroEngine.pause(at: Date())
        pomodoroSession = pomodoroEngine.session
        cancelPomodoroTick()
        pomodoroPrompt = .pause
    }

    func resumePomodoro() {
        if pomodoroSession?.phase == .paused {
            pomodoroEngine.resume(at: Date())
            pomodoroSession = pomodoroEngine.session
            startPomodoroTick()
        }
        pomodoroPrompt = nil
    }

    func requestPomodoroAbandon() {
        pomodoroPrompt = .abandon
    }

    func confirmPomodoroAbandon() {
        pomodoroEngine.abandon()
        pomodoroSession = nil
        pomodoroPrompt = nil
        pomodoroCompleteTaskToggle = false
        finishedPomodoro = nil
        pomodoroDurationWriteError = nil
        cancelPomodoroTick()
    }

    func requestPomodoroManualCompletion() {
        guard pomodoroSession?.phase == .running else { return }
        pomodoroEngine.pause(at: Date())
        pomodoroSession = pomodoroEngine.session
        cancelPomodoroTick()
        let minutesToAdd = pomodoroEngine.completedMinutes(at: Date())
        pomodoroCompleteTaskToggle = false
        pomodoroPrompt = .manualCompletion(minutesToAdd: minutesToAdd)
    }

    func confirmPomodoroManualCompletion() async {
        guard let prompt = pomodoroPrompt,
              case .manualCompletion(let minutesToAdd) = prompt else { return }
        guard let session = pomodoroSession else { return }

        let context = FinishedPomodoroContext(
            taskID: session.taskID,
            taskTitle: session.taskTitle,
            minutesToAdd: minutesToAdd,
            baseEstimatedMinutes: tasks.first(where: { $0.id == session.taskID })?.estimatedMinutes,
            durationWriteSucceeded: false
        )
        finishedPomodoro = context
        pomodoroSession = nil
        pomodoroPrompt = nil

        let durationSuccess = await recordPomodoroDuration(for: context)
        guard finishedPomodoro?.taskID == context.taskID else { return }

        if !durationSuccess {
            pomodoroPrompt = .durationWriteFailed
            return
        }

        finishedPomodoro?.durationWriteSucceeded = true

        if pomodoroCompleteTaskToggle {
            do {
                let updated = try await repository.toggleTask(id: context.taskID, isDone: true)
                guard finishedPomodoro?.taskID == context.taskID else { return }
                tasks = TaskSorting.sort(tasks.map { $0.id == updated.id ? updated : $0 })
                pomodoroPrompt = .success(completedTask: true, minutesToAdd: context.minutesToAdd)
            } catch {
                errorMessage = AppMessage(.taskUpdateFailed, arguments: [error.localizedDescription])
                pomodoroPrompt = .success(completedTask: false, minutesToAdd: context.minutesToAdd)
            }
        } else {
            pomodoroPrompt = .success(completedTask: false, minutesToAdd: context.minutesToAdd)
        }

        finishedPomodoro = nil
        pomodoroCompleteTaskToggle = false
    }

    func confirmPomodoroNaturalEnd() async {
        guard let context = finishedPomodoro, context.durationWriteSucceeded else { return }
        pomodoroPrompt = nil

        if pomodoroCompleteTaskToggle {
            do {
                let updated = try await repository.toggleTask(id: context.taskID, isDone: true)
                guard finishedPomodoro?.taskID == context.taskID else { return }
                tasks = TaskSorting.sort(tasks.map { $0.id == updated.id ? updated : $0 })
                pomodoroPrompt = .success(completedTask: true, minutesToAdd: context.minutesToAdd)
            } catch {
                errorMessage = AppMessage(.taskUpdateFailed, arguments: [error.localizedDescription])
                pomodoroPrompt = .success(completedTask: false, minutesToAdd: context.minutesToAdd)
            }
        } else {
            pomodoroPrompt = .success(completedTask: false, minutesToAdd: context.minutesToAdd)
        }

        finishedPomodoro = nil
        pomodoroCompleteTaskToggle = false
    }

    func retryPomodoroDurationWrite() async {
        guard let context = finishedPomodoro, !context.durationWriteSucceeded else { return }
        pomodoroPrompt = nil

        let success = await recordPomodoroDuration(for: context)
        guard finishedPomodoro?.taskID == context.taskID else { return }

        if success {
            finishedPomodoro?.durationWriteSucceeded = true
            pomodoroCompleteTaskToggle = false
            pomodoroPrompt = .naturalEnd(minutesToAdd: context.minutesToAdd)
        } else {
            pomodoroPrompt = .durationWriteFailed
        }
    }

    func dismissPomodoroLater() {
        pomodoroPrompt = nil
        pomodoroDurationWriteError = nil
        pomodoroCompleteTaskToggle = false
        finishedPomodoro = nil
    }

    func dismissPomodoroSuccess() {
        pomodoroPrompt = nil
        pomodoroCompleteTaskToggle = false
        finishedPomodoro = nil
    }

    // MARK: - Pomodoro Private Helpers

    private func startPomodoroTick() {
        cancelPomodoroTick()
        pomodoroTickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                let event = self.pomodoroEngine.advance(to: Date())
                self.pomodoroSession = self.pomodoroEngine.session
                if event == .finished {
                    self.finishPomodoroRound()
                    return
                }
            }
        }
    }

    private func cancelPomodoroTick() {
        pomodoroTickTask?.cancel()
        pomodoroTickTask = nil
    }

    private func finishPomodoroRound() {
        cancelPomodoroTick()
        guard let session = pomodoroSession else { return }

        let context = FinishedPomodoroContext(
            taskID: session.taskID,
            taskTitle: session.taskTitle,
            minutesToAdd: session.durationMinutes,
            baseEstimatedMinutes: tasks.first(where: { $0.id == session.taskID })?.estimatedMinutes,
            durationWriteSucceeded: false
        )
        finishedPomodoro = context

        playPomodoroCompletionChime()
        pomodoroSession = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            let success = await self.recordPomodoroDuration(for: context)
            guard self.finishedPomodoro?.taskID == context.taskID else { return }

            if success {
                self.finishedPomodoro?.durationWriteSucceeded = true
                self.pomodoroCompleteTaskToggle = false
                self.pomodoroPrompt = .naturalEnd(minutesToAdd: context.minutesToAdd)
            } else {
                self.pomodoroPrompt = .durationWriteFailed
            }
        }
    }

    /// 闹钟式完成提示音：播放 freesound 下载的真实闹钟音效（约 4.5s）。
    /// 音频文件随 PBXFileSystemSynchronizedRootGroup 自动同步进 app bundle，无需改 .xcodeproj。
    /// 加载失败回退到系统 beep。
    private func playPomodoroCompletionChime() {
        if let url = Bundle.main.url(forResource: "freesound_community-house_alarm-clock_loud-92419", withExtension: "mp3"),
           let sound = NSSound(contentsOf: url, byReference: true) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func recordPomodoroDuration(for context: FinishedPomodoroContext) async -> Bool {
        let currentTask = tasks.first(where: { $0.id == context.taskID })
        let baseMinutes = currentTask?.estimatedMinutes ?? context.baseEstimatedMinutes
        let newTotal = (baseMinutes ?? 0) + context.minutesToAdd
        let title = currentTask?.title ?? context.taskTitle

        do {
            let updated = try await repository.updateTaskTitle(
                id: context.taskID,
                title: title,
                estimatedMinutes: newTotal
            )
            tasks = TaskSorting.sort(tasks.map { $0.id == updated.id ? updated : $0 })
            pomodoroDurationWriteError = nil
            return true
        } catch {
            pomodoroDurationWriteError = AppMessage(.pomodoroDurationWriteFailed)
            return false
        }
    }
}
