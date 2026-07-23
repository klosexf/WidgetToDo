import Foundation
import Combine

@MainActor
final class TodoListViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published private(set) var selectedDate: Date
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pendingTask: PendingTaskItem?
    @Published var showFailureHighlight = false
    @Published var toast: ToastItem?
    @Published private(set) var tasksDatabaseURL: URL?
    @Published var editingTask: TaskItem?
    @Published var editingTitle = ""
    @Published var editingEstimatedMinutesText = ""
    @Published var editingEstimatedMinutesError: String?
    @Published var isSavingTaskEdit = false
    @Published var deletingTaskID: String?

    private let repository: NotionRepository
    private let openURL: @MainActor (URL) -> Void
    let newTaskViewModel: NewTaskViewModel
    private let calendar = Calendar(identifier: .gregorian)

    init(repository: NotionRepository, hasPriorityField: Bool, openURL: @escaping @MainActor (URL) -> Void) {
        self.repository = repository
        self.openURL = openURL
        self.selectedDate = Date()
        self.newTaskViewModel = NewTaskViewModel(repository: repository, hasPriorityField: hasPriorityField)

        newTaskViewModel.onSubmit = { [weak self] pendingItem in
            self?.pendingTask = pendingItem
        }

        newTaskViewModel.onCreateSuccess = { [weak self] task in
            self?.pendingTask = nil
            var tasks = self?.tasks ?? []
            tasks.insert(task, at: 0)
            self?.tasks = TaskSorting.sort(tasks)
            self?.showToast(.success, message: "已同步到 Notion")
        }

        newTaskViewModel.onCreateFailure = { [weak self] pendingItem, errorMessage in
            self?.handleCreationFailure(pendingItem, errorMessage: errorMessage)
        }
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
            errorMessage = "任务同步失败：\(error.localizedDescription)"
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
            errorMessage = "任务更新失败：\(error.localizedDescription)"
        }
    }

    func retry(_ task: TaskItem) async {
        do {
            let updated = try await repository.retryTask(id: task.id)
            tasks = TaskSorting.sort(tasks.map { $0.id == updated.id ? updated : $0 })
            errorMessage = nil
        } catch {
            errorMessage = "重试失败：\(error.localizedDescription)"
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

    var isShowingToday: Bool {
        calendar.isDate(selectedDate, inSameDayAs: Date())
    }

    func beginEditing(_ task: TaskItem) {
        editingTask = task
        editingTitle = task.title
        editingEstimatedMinutesText = task.estimatedMinutes.map(String.init) ?? ""
        editingEstimatedMinutesError = nil
        errorMessage = nil
    }

    func cancelEditing() {
        editingTask = nil
        editingTitle = ""
        editingEstimatedMinutesText = ""
        editingEstimatedMinutesError = nil
        isSavingTaskEdit = false
    }

    func saveTaskEdit() async {
        guard let task = editingTask else { return }

        let trimmedTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "任务标题不能为空。"
            return
        }

        let parsedEstimatedMinutes = parseEditingEstimatedMinutes()
        if !editingEstimatedMinutesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           parsedEstimatedMinutes == nil {
            editingEstimatedMinutesError = "预计时长需填写为大于 0 的分钟数"
            return
        }
        editingEstimatedMinutesError = nil

        isSavingTaskEdit = true
        defer { isSavingTaskEdit = false }

        do {
            let updated = try await repository.updateTaskTitle(
                id: task.id,
                title: trimmedTitle,
                estimatedMinutes: parsedEstimatedMinutes
            )
            tasks = TaskSorting.sort(tasks.map { $0.id == updated.id ? updated : $0 })
            errorMessage = nil
            cancelEditing()
            showToast(.success, message: "任务已更新")
        } catch {
            errorMessage = "任务更新失败：\(error.localizedDescription)"
        }
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
            showToast(.success, message: "任务已删除")
        } catch {
            errorMessage = "任务删除失败：\(error.localizedDescription)"
        }
    }

    private func handleCreationFailure(_ pendingItem: PendingTaskItem, errorMessage: String) {
        showFailureHighlight = true
        showToast(.taskCreateFailed, message: "⚠️ 创建失败：\(errorMessage)")

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self?.showFailureHighlight = false
            self?.pendingTask = nil
        }
    }

    private func showToast(_ kind: ToastKind, message: String) {
        toast = ToastItem(kind: kind, message: message)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.toast = nil
        }
    }

    private func normalizedDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}
