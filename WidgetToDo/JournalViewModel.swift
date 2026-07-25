import Combine
import Foundation

@MainActor
final class JournalViewModel: ObservableObject {
    @Published var entry: JournalEntry?
    @Published var editorText = ""
    @Published var statusMessage: AppText.Key?
    @Published var errorMessage: AppMessage?
    @Published var isLoading = false

    private let repository: NotionRepository
    private let openURL: @MainActor (URL) -> Void
    private var debounceTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var pendingSaveText: String?

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
            statusMessage = entry.contentText.isEmpty ? .journalReadyToWrite : .journalSynced
            errorMessage = nil
        } catch {
            statusMessage = nil
            errorMessage = AppMessage(.journalSyncFailed, arguments: [error.localizedDescription])
        }
    }

    func scheduleAutosave(text: String) {
        debounceTask?.cancel()
        statusMessage = .journalSavingSoon
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.enqueueSave(text: text)
        }
    }

    func forceSave() async {
        debounceTask?.cancel()
        enqueueSave(text: editorText)
        if let saveTask {
            await saveTask.value
        }
    }

    func reloadFromNotion() async {
        debounceTask?.cancel()
        if let saveTask {
            await saveTask.value
        }
        await load()
    }

    func openInNotion(_ url: URL) {
        openURL(url)
    }

    private func enqueueSave(text: String) {
        pendingSaveText = text
        guard saveTask == nil else { return }

        saveTask = Task { @MainActor [weak self] in
            await self?.flushPendingSaves()
        }
    }

    private func flushPendingSaves() async {
        while let text = pendingSaveText {
            pendingSaveText = nil
            await save(text: text)
        }
        saveTask = nil
    }

    private func save(text: String) async {
        guard let entry else { return }

        do {
            let saved = try await repository.saveJournal(entryID: entry.id, text: text, date: entry.date)
            self.entry = saved
            statusMessage = .journalSavedToNotion
            errorMessage = nil
        } catch {
            self.entry?.syncStatus = .failed
            errorMessage = AppMessage(.journalSaveFailed, arguments: [error.localizedDescription])
            statusMessage = nil
        }
    }
}
