import Combine
import Foundation

/// 日记同步冲突快照：云端文本与本地未保存编辑分叉时暂存远端内容，等待用户选择。
struct JournalSyncConflict: Equatable {
    let remoteText: String
}

@MainActor
final class JournalViewModel: ObservableObject {
    @Published var entry: JournalEntry?
    @Published private(set) var selectedDate: Date
    @Published var editorText = ""
    @Published var statusMessage: AppText.Key?
    @Published var errorMessage: AppMessage?
    @Published var isLoading = false
    @Published var conflict: JournalSyncConflict?

    private let repository: NotionRepository
    private let openURL: @MainActor (URL) -> Void
    private let calendar = Calendar(identifier: .gregorian)
    private var debounceTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var pendingSaveText: String?
    /// 加载代际：每次发起加载自增；仅当响应归来时代际仍一致才落地，
    /// 防止快速连续切换日期时旧请求乱序完成后用旧日期内容覆盖当前日期。
    private var loadGeneration = 0

    init(repository: NotionRepository, openURL: @escaping @MainActor (URL) -> Void) {
        self.repository = repository
        self.openURL = openURL
        self.selectedDate = Calendar(identifier: .gregorian).startOfDay(for: Date())
    }

    func load() async {
        await load(for: selectedDate)
    }

    func load(for date: Date) async {
        loadGeneration += 1
        let generation = loadGeneration
        selectedDate = calendar.startOfDay(for: date)
        isLoading = true

        do {
            let entry = try await repository.loadOrCreateJournal(for: selectedDate)
            // 过期响应：期间用户已切换到其他日期，丢弃，避免旧日期内容覆盖当前日期。
            guard generation == loadGeneration else { return }
            self.entry = entry
            editorText = entry.contentText
            statusMessage = entry.contentText.isEmpty ? .journalReadyToWrite : .journalSynced
            errorMessage = nil
        } catch {
            guard generation == loadGeneration else { return }
            statusMessage = nil
            errorMessage = AppMessage(.journalSyncFailed, arguments: [error.localizedDescription])
        }
        isLoading = false
    }

    /// 切换到指定日期的日记：点击即刻更新日期标题并进入加载态（即时反馈，不出现无响应死等），
    /// 再把当前未保存编辑落盘（不丢输入，保存走 entry.id/entry.date，不受 selectedDate 提前变化影响），
    /// 最后加载目标日期内容。
    func switchDate(to date: Date) async {
        let target = calendar.startOfDay(for: date)
        loadGeneration += 1
        let generation = loadGeneration
        selectedDate = target
        isLoading = true

        // 先落盘当前未保存编辑（写入旧日期页面），再加载目标日期。
        await forceSave()
        // 落盘期间用户又切换了日期：本轮过期，由最新流程收尾（isLoading 不在此复位）。
        guard generation == loadGeneration else { return }

        await load(for: target)
    }

    func showPreviousDay() async {
        guard let previous = calendar.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        await switchDate(to: previous)
    }

    func showNextDay() async {
        guard let next = calendar.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        await switchDate(to: next)
    }

    func jumpToToday() async {
        await switchDate(to: Date())
    }

    /// 月历印记：指定日期的本地缓存里是否有非空日记内容（只读，不发网络请求）。
    func hasCachedJournalContent(on date: Date) async -> Bool {
        guard let entry = try? await repository.cachedJournal(for: date) else { return false }
        return !entry.contentText.isEmpty
    }

    /// 月历印记（远端刷新）：拉取 monthAnchor 所在月「日记内容非空」的日期（day -> true），
    /// 并把本地缓存缺失的日记页面补进缓存。网络失败返回空表（保持缓存印记不变）。
    func refreshMonthContentDays(containing monthAnchor: Date) async -> [Int: Bool] {
        (try? await repository.refreshJournalMarks(containing: monthAnchor)) ?? [:]
    }

    /// 当前展示的是否就是今天（与待办 tab 的日期互不同步、各自独立判断）。
    var isShowingToday: Bool {
        calendar.isDate(selectedDate, inSameDayAs: Date())
    }

    /// 编辑感知的同步入口：刷新按钮与工作区刷新统一走这里。
    /// 同步前先把防抖中的文本立即入队并等待在途保存完成（不丢弃任何输入），
    /// 再拉取远端内容，由 `JournalSyncConflictEngine` 决定覆盖、保留或进入冲突流程。
    func reloadFromNotion() async {
        // 1. 把防抖中的最新文本立即入队（而不是取消丢弃），并等待在途保存结束。
        if debounceTask != nil {
            debounceTask?.cancel()
            debounceTask = nil
            enqueueSave(text: editorText)
        }
        if let saveTask {
            await saveTask.value
        }

        isLoading = true
        loadGeneration += 1
        let generation = loadGeneration

        let remote: JournalEntry
        do {
            remote = try await repository.loadOrCreateJournal(for: selectedDate)
        } catch {
            // 过期响应：期间用户已切换日期，交给新的加载流程收尾，这里不落地也不复位状态。
            guard generation == loadGeneration else { return }
            statusMessage = nil
            errorMessage = AppMessage(.journalSyncFailed, arguments: [error.localizedDescription])
            isLoading = false
            return
        }
        // 拉取期间用户切换了日期：丢弃本次结果，新的加载流程会按新日期落地。
        guard generation == loadGeneration else { return }

        // 2. 决策时重新读取编辑器状态：拉取期间用户可能继续输入。
        let decision = JournalSyncConflictEngine.resolve(
            context: JournalSyncContext(
                localText: editorText,
                remoteText: remote.contentText,
                hasUnsavedEdits: hasUnsavedEdits,
                lastSaveFailed: entry?.syncStatus == .failed
            )
        )

        switch decision {
        case .applyRemote:
            entry = remote
            editorText = remote.contentText
            errorMessage = nil
            conflict = nil
            statusMessage = remote.contentText.isEmpty ? .journalReadyToWrite : .journalSynced
        case .keepLocal:
            // 只更新元数据与提示，不触碰 editorText，避免打断正在输入的内容。
            entry = remote
            errorMessage = nil
            statusMessage = .journalEditsKeptDuringSync
        case .conflict:
            // 本地编辑未成功写入云端且远端已分叉：保留本地内容，交给用户选择。
            entry = remote
            conflict = JournalSyncConflict(remoteText: remote.contentText)
            statusMessage = .journalConflictNotice
        }
        isLoading = false
    }

    /// 是否存在未确认写入 Notion 的本地编辑。
    var hasUnsavedEdits: Bool {
        if debounceTask != nil || saveTask != nil || pendingSaveText != nil {
            return true
        }
        guard let entry else { return false }
        if entry.syncStatus == .failed {
            return true
        }
        return editorText != entry.contentText
    }

    func scheduleAutosave(text: String) {
        // 文本与已同步内容一致且保存管道空闲：这是同步回填或手动还原，无需再排队保存。
        if text == entry?.contentText,
           saveTask == nil,
           pendingSaveText == nil,
           debounceTask == nil {
            return
        }
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
        debounceTask = nil
        enqueueSave(text: editorText)
        if let saveTask {
            await saveTask.value
        }
    }

    /// 冲突处理：保留本地内容，下一次自动保存会覆盖云端。
    func resolveConflictKeepingLocal() {
        guard conflict != nil else { return }
        conflict = nil
        statusMessage = .journalEditsKeptDuringSync
    }

    /// 冲突处理：放弃本地未保存编辑，改用云端内容（与刚拉取的远端一致，无需再写回）。
    func resolveConflictUsingCloud() {
        guard let conflict else { return }
        let remoteText = conflict.remoteText
        self.conflict = nil
        debounceTask?.cancel()
        debounceTask = nil
        editorText = remoteText
        errorMessage = nil
        statusMessage = .journalSynced
    }

    /// 冲突处理：云端内容追加到本地末尾，合并结果走正常自动保存。
    func resolveConflictByMerging() {
        guard let conflict else { return }
        let remoteText = conflict.remoteText
        self.conflict = nil
        debounceTask?.cancel()
        debounceTask = nil
        let merged = editorText + "\n\n———\n\n" + remoteText
        editorText = merged
        scheduleAutosave(text: merged)
    }

    /// 后台待定变更重试成功后刷新同步状态。
    /// 只更新 entry 与提示文案，不触碰 editorText，避免打断正在输入的内容；
    /// 有待保存或正在保存的编辑时跳过（保存流程自身会推进状态）。
    func refreshSyncStatus() async {
        guard let entry,
              saveTask == nil,
              debounceTask == nil,
              let cached = try? await repository.cachedJournal(id: entry.id),
              cached.id == entry.id,
              cached.syncStatus != entry.syncStatus
        else { return }
        self.entry = cached
        if cached.syncStatus == .synced, errorMessage != nil {
            errorMessage = nil
            statusMessage = .journalSynced
        }
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
