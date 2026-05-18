import Combine
import Foundation

@MainActor
final class TodoListViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: NotionRepository
    private let openURL: @MainActor (URL) -> Void

    init(repository: NotionRepository, openURL: @escaping @MainActor (URL) -> Void) {
        self.repository = repository
        self.openURL = openURL
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
}
