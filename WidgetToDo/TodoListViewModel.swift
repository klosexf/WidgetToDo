import Combine
import Foundation

@MainActor
final class TodoListViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pendingTask: PendingTaskItem?
    @Published var showFailureHighlight = false
    @Published var toast: ToastItem?

    private let repository: NotionRepository
    private let openURL: @MainActor (URL) -> Void
    let newTaskViewModel: NewTaskViewModel
    private var cancellables = Set<AnyCancellable>()

    init(repository: NotionRepository, hasPriorityField: Bool, openURL: @escaping @MainActor (URL) -> Void) {
        self.repository = repository
        self.openURL = openURL
        self.newTaskViewModel = NewTaskViewModel(repository: repository, hasPriorityField: hasPriorityField)

        newTaskViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

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

        newTaskViewModel.onCreateFailure = { [weak self] pendingItem in
            self?.handleCreationFailure(pendingItem)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            tasks = try await repository.loadTasks()
            errorMessage = nil
        } catch {
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

    func openNewTaskForm() {
        newTaskViewModel.openForm()
    }

    private func handleCreationFailure(_ pendingItem: PendingTaskItem) {
        showFailureHighlight = true
        showToast(.taskCreateFailed, message: "⚠️ 创建失败，已撤回")

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
}
