import Combine
import Foundation

@MainActor
final class JournalViewModel: ObservableObject {
    @Published var entry: JournalEntry?
    @Published var editorText = ""
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let repository: NotionRepository
    private let openURL: @MainActor (URL) -> Void
    private var autosaveTask: Task<Void, Never>?

    init(repository: NotionRepository, openURL: @escaping @MainActor (URL) -> Void) {
        self.repository = repository
        self.openURL = openURL
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let entry = try await repository.loadOrCreateJournal()
            self.entry = entry
            editorText = entry.contentText
            statusMessage = entry.contentText.isEmpty ? "可以开始记录了" : "日记已同步"
            errorMessage = nil
        } catch {
            errorMessage = "日记同步失败：\(error.localizedDescription)"
        }
    }

    func scheduleAutosave(text: String) {
        autosaveTask?.cancel()
        statusMessage = "即将保存..."
        autosaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.save(text: text)
        }
    }

    func forceSave() async {
        await save(text: editorText)
    }

    func reloadFromNotion() async {
        autosaveTask?.cancel()
        await load()
    }

    func openInNotion(_ url: URL) {
        openURL(url)
    }

    private func save(text: String) async {
        guard let entry else { return }

        do {
            let saved = try await repository.saveJournal(entryID: entry.id, text: text, date: entry.date)
            self.entry = saved
            statusMessage = "已保存到 Notion"
            errorMessage = nil
        } catch {
            self.entry?.syncStatus = .failed
            statusMessage = "保存失败"
            errorMessage = "日记保存失败：\(error.localizedDescription)"
        }
    }
}
