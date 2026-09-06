import Foundation

public actor NotionRepository {
    private let tokenStore: any TokenStore
    private let settingsStore: SettingsStore
    private let cache: SQLiteCache
    private let notionClient: NotionClient

    public init(
        tokenStore: any TokenStore,
        settingsStore: SettingsStore,
        cache: SQLiteCache,
        notionClient: NotionClient
    ) {
        self.tokenStore = tokenStore
        self.settingsStore = settingsStore
        self.cache = cache
        self.notionClient = notionClient
    }

    public func loadConfigurationSnapshot() async throws -> ConfigurationSnapshot {
        let settings = try await settingsStore.load()
        let token = try tokenStore.loadToken()
        guard let settings,
              let token,
              !token.isEmpty,
              settings.tasksFieldMapping.priorityOptions.isEmpty
        else {
            return makeConfigurationSnapshot(settings: settings, token: token)
        }

        do {
            let schema = try await notionClient.fetchDatabaseSchema(databaseID: settings.tasksDatabaseID, token: token)
            guard case let .success(.tasks(discoveredMapping)) = FieldValidator.resolve(schema, for: .tasks) else {
                return makeConfigurationSnapshot(settings: settings, token: token)
            }

            let refreshedMapping = TaskDatabaseFieldMapping(
                title: settings.tasksFieldMapping.title,
                date: settings.tasksFieldMapping.date,
                done: settings.tasksFieldMapping.done,
                priority: discoveredMapping.priority,
                priorityOptions: discoveredMapping.priorityOptions,
                estimatedMinutes: settings.tasksFieldMapping.estimatedMinutes
            )
            guard refreshedMapping != settings.tasksFieldMapping else {
                return makeConfigurationSnapshot(settings: settings, token: token)
            }

            let updatedSettings = AppSettings(
                tasksDatabaseID: settings.tasksDatabaseID,
                journalDatabaseID: settings.journalDatabaseID,
                tasksPageURL: settings.tasksPageURL,
                journalPageURL: settings.journalPageURL,
                lastValidatedAt: settings.lastValidatedAt,
                hasPriorityField: refreshedMapping.priority != nil,
                tasksFieldMapping: refreshedMapping,
                journalFieldMapping: settings.journalFieldMapping,
                miniModeState: settings.miniModeState
            )
            try await settingsStore.save(updatedSettings)
            return makeConfigurationSnapshot(settings: updatedSettings, token: token)
        } catch {
            return makeConfigurationSnapshot(settings: settings, token: token)
        }
    }

    private func makeConfigurationSnapshot(settings: AppSettings?, token: String?) -> ConfigurationSnapshot {
        ConfigurationSnapshot(
            hasToken: token?.isEmpty == false,
            token: token,
            tasksDatabaseID: settings?.tasksDatabaseID,
            journalDatabaseID: settings?.journalDatabaseID,
            hasPriorityField: settings?.hasPriorityField ?? true,
            choiceField: settings.flatMap { settings in
                guard let name = settings.tasksFieldMapping.priority, !settings.tasksFieldMapping.priorityOptions.isEmpty else { return nil }
                return TaskChoiceField(name: name, options: settings.tasksFieldMapping.priorityOptions)
            }
        )
    }

    public func loadMiniModeState() async throws -> MiniModeState {
        let settings = try await settingsStore.load()
        return settings?.miniModeState ?? .default
    }

    public func loadAppLanguage() async throws -> AppLanguage {
        try await settingsStore.loadAppLanguage()
    }

    public func saveAppLanguage(_ language: AppLanguage) async throws {
        try await settingsStore.saveAppLanguage(language)
    }

    public func saveMiniModeState(_ state: MiniModeState) async throws {
        guard let settings = try await settingsStore.load() else {
            return
        }
        let updated = AppSettings(
            tasksDatabaseID: settings.tasksDatabaseID,
            journalDatabaseID: settings.journalDatabaseID,
            tasksPageURL: settings.tasksPageURL,
            journalPageURL: settings.journalPageURL,
            lastValidatedAt: settings.lastValidatedAt,
            hasPriorityField: settings.hasPriorityField,
            tasksFieldMapping: settings.tasksFieldMapping,
            journalFieldMapping: settings.journalFieldMapping,
            miniModeState: state
        )
        try await settingsStore.save(updated)
    }

    @discardableResult
    public func saveConfiguration(token: String, tasksInput: String, journalInput: String) async throws -> AppSettings {
        guard let tasksReference = NotionDatabaseReference.parse(tasksInput) else {
            throw NotionRepositoryError.invalidDatabaseInput("任务数据库 URL 或 ID 无效。")
        }
        guard let journalReference = NotionDatabaseReference.parse(journalInput) else {
            throw NotionRepositoryError.invalidDatabaseInput("日记数据库 URL 或 ID 无效。")
        }

        try tokenStore.save(token: token)
        let taskSchema = try await notionClient.fetchDatabaseSchema(databaseID: tasksReference.rawValue, token: token)
        let journalSchema = try await notionClient.fetchDatabaseSchema(databaseID: journalReference.rawValue, token: token)

        let taskResolution = FieldValidator.resolve(taskSchema, for: .tasks)
        let journalResolution = FieldValidator.resolve(journalSchema, for: .journal)

        var issues: [ValidationIssue] = []
        let tasksFieldMapping: TaskDatabaseFieldMapping?
        switch taskResolution {
        case let .success(.tasks(mapping)):
            tasksFieldMapping = mapping
        case let .failure(validationIssues):
            tasksFieldMapping = nil
            issues += validationIssues
        case .success:
            tasksFieldMapping = nil
        }

        let journalFieldMapping: JournalDatabaseFieldMapping?
        switch journalResolution {
        case let .success(.journal(mapping)):
            journalFieldMapping = mapping
        case let .failure(validationIssues):
            journalFieldMapping = nil
            issues += validationIssues
        case .success:
            journalFieldMapping = nil
        }

        guard issues.isEmpty else {
            throw NotionRepositoryError.validationFailed(issues)
        }

        guard let tasksFieldMapping, let journalFieldMapping else {
            throw NotionRepositoryError.validationFailed([
                ValidationIssue(.fieldMappingFailed, arguments: ["无法识别任务或日记数据库的字段结构。"])
            ])
        }

        let hasPriorityField = tasksFieldMapping.priority != nil
        let settings = AppSettings(
            tasksDatabaseID: tasksReference.rawValue,
            journalDatabaseID: journalReference.rawValue,
            lastValidatedAt: Date(),
            hasPriorityField: hasPriorityField,
            tasksFieldMapping: tasksFieldMapping,
            journalFieldMapping: journalFieldMapping
        )
        try await settingsStore.save(settings)
        return settings
    }

    public func loadTasks(for date: Date = Date()) async throws -> [TaskItem] {
        let context = try await configurationContext()

        do {
            let tasks = TaskSorting.sort(
                try await notionClient.queryTasks(
                    on: date,
                    databaseID: context.settings.tasksDatabaseID,
                    fields: context.settings.tasksFieldMapping,
                    token: context.token
                )
            )
            try cache.saveTasks(tasks, for: date)
            return tasks
        } catch {
            let cached = try cache.loadTasks(for: date)
            guard !cached.isEmpty else {
                throw error
            }
            return TaskSorting.sort(cached)
        }
    }

    public func tasksDatabasePageURL() async throws -> URL {
        let context = try await configurationContext()
        if let savedURL = context.settings.tasksPageURL {
            return savedURL
        }

        guard let url = URL(string: "https://www.notion.so/\(context.settings.tasksDatabaseID.replacingOccurrences(of: "-", with: ""))") else {
            throw NotionRepositoryError.invalidDatabaseInput("任务数据库 URL 无效。")
        }
        return url
    }

    public func toggleTask(id: String, isDone: Bool) async throws -> TaskItem {
        guard var task = try cache.task(id: id) else {
            throw NotionRepositoryError.missingCacheRecord("任务缓存记录不存在。")
        }

        task.isDone = isDone
        task.syncStatus = .localPending
        try cache.upsert(task)

        let mutation = PendingMutation(
            target: .task,
            targetID: id,
            type: .toggleCheckbox,
            payload: #"{"isDone":\#(isDone)}"#
        )
        try cache.enqueue(mutation)

        do {
            let context = try await configurationContext()
            try await notionClient.updateTaskCheckbox(
                pageID: id,
                isDone: isDone,
                fields: context.settings.tasksFieldMapping,
                token: context.token
            )
            task.syncStatus = .synced
            try cache.upsert(task)
            try cache.markMutation(id: mutation.id, status: .synced, lastError: nil)
        } catch {
            task.syncStatus = .failed
            try cache.upsert(task)
            try cache.markMutation(id: mutation.id, status: .failed, lastError: String(describing: error))
            throw error
        }

        return task
    }

    public func retryTask(id: String) async throws -> TaskItem {
        guard let task = try cache.task(id: id) else {
            throw NotionRepositoryError.missingCacheRecord("任务缓存记录不存在。")
        }
        return try await toggleTask(id: id, isDone: task.isDone)
    }

    /// 重放本地待定变更队列（queued + failed）。
    ///
    /// - 同一目标（targetID + type）只重放最新一条（last-write-wins），旧条目直接标记 synced。
    /// - 目标缓存记录已是 synced（被更新内容取代）或已不存在时跳过重放，避免旧数据覆盖新内容。
    /// - 遇到写入失败立即停止：401/403 视为需要重新授权，其余（网络、限流等）等待下次触发。
    @discardableResult
    public func drainPendingMutations() async -> PendingMutationDrainResult {
        guard let context = try? await configurationContext() else {
            return PendingMutationDrainResult(replayed: 0, skipped: 0, stopReason: .missingConfiguration)
        }

        let mutations = (try? cache.pendingMutations()) ?? []
        guard !mutations.isEmpty else {
            return PendingMutationDrainResult(replayed: 0, skipped: 0, stopReason: nil)
        }

        let latest = latestMutationsPerTarget(from: mutations)
        var replayed = 0
        var skipped = 0
        // 被同目标更新变更取代的旧条目直接结案，避免队列无限累积。
        for mutation in mutations where !latest.contains(where: { $0.id == mutation.id }) {
            try? cache.markMutation(id: mutation.id, status: .synced, lastError: "已被更新的变更取代。")
            skipped += 1
        }

        for mutation in latest {
            switch (mutation.target, mutation.type) {
            case (.task, .toggleCheckbox):
                guard let isDone = Self.decodeBoolPayload(mutation.payload, key: "isDone") else {
                    try? cache.markMutation(id: mutation.id, status: .synced, lastError: "待定变更载荷无法解析，已丢弃。")
                    skipped += 1
                    continue
                }
                guard var task = try? cache.task(id: mutation.targetID) else {
                    // 任务已删除或归档，重放无意义。
                    try? cache.markMutation(id: mutation.id, status: .synced, lastError: nil)
                    skipped += 1
                    continue
                }
                guard task.syncStatus != .synced else {
                    // 已有更新内容同步成功，旧变更作废。
                    try? cache.markMutation(id: mutation.id, status: .synced, lastError: nil)
                    skipped += 1
                    continue
                }
                do {
                    try await notionClient.updateTaskCheckbox(
                        pageID: mutation.targetID,
                        isDone: isDone,
                        fields: context.settings.tasksFieldMapping,
                        token: context.token
                    )
                } catch {
                    return drainFailureResult(mutation: mutation, error: error, replayed: replayed, skipped: skipped)
                }
                task.syncStatus = .synced
                try? cache.upsert(task)
                try? cache.markMutation(id: mutation.id, status: .synced, lastError: nil)
                replayed += 1

            case (.journal, .replaceJournalText):
                guard let text = Self.decodeStringPayload(mutation.payload, key: "text") else {
                    try? cache.markMutation(id: mutation.id, status: .synced, lastError: "待定变更载荷无法解析，已丢弃。")
                    skipped += 1
                    continue
                }
                guard var entry = try? cache.journalEntry(id: mutation.targetID) else {
                    try? cache.markMutation(id: mutation.id, status: .synced, lastError: nil)
                    skipped += 1
                    continue
                }
                guard entry.syncStatus != .synced else {
                    try? cache.markMutation(id: mutation.id, status: .synced, lastError: nil)
                    skipped += 1
                    continue
                }
                do {
                    try await notionClient.replaceJournalText(pageID: mutation.targetID, text: text, token: context.token)
                } catch {
                    return drainFailureResult(mutation: mutation, error: error, replayed: replayed, skipped: skipped)
                }
                entry.contentText = text
                entry.syncStatus = .synced
                try? cache.upsert(entry)
                try? cache.markMutation(id: mutation.id, status: .synced, lastError: nil)
                replayed += 1

            default:
                skipped += 1
            }
        }

        return PendingMutationDrainResult(replayed: replayed, skipped: skipped, stopReason: nil)
    }

    /// 每个（目标 + 类型）只保留最新一条，并维持原时间顺序。
    private func latestMutationsPerTarget(from mutations: [PendingMutation]) -> [PendingMutation] {
        var latestIDs: [String: String] = [:]
        for mutation in mutations {
            let key = "\(mutation.target.rawValue)|\(mutation.targetID)|\(mutation.type.rawValue)"
            latestIDs[key] = mutation.id
        }
        return mutations.filter { mutation in
            let key = "\(mutation.target.rawValue)|\(mutation.targetID)|\(mutation.type.rawValue)"
            return latestIDs[key] == mutation.id
        }
    }

    private func drainFailureResult(
        mutation: PendingMutation,
        error: Error,
        replayed: Int,
        skipped: Int
    ) -> PendingMutationDrainResult {
        try? cache.markMutation(id: mutation.id, status: .failed, lastError: String(describing: error))
        let reason: PendingMutationDrainResult.StopReason
        if case let NotionClientError.httpError(statusCode, _) = error, statusCode == 401 || statusCode == 403 {
            reason = .unauthorized
        } else {
            reason = .writeFailed
        }
        return PendingMutationDrainResult(replayed: replayed, skipped: skipped, stopReason: reason)
    }

    private static func decodeBoolPayload(_ payload: String, key: String) -> Bool? {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object[key] as? Bool
        else { return nil }
        return value
    }

    private static func decodeStringPayload(_ payload: String, key: String) -> String? {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object[key] as? String
        else { return nil }
        return value
    }

    public func updateTaskTitle(id: String, title: String, priority: String?, estimatedMinutes: Int?) async throws -> TaskItem {
        guard var task = try cache.task(id: id) else {
            throw NotionRepositoryError.missingCacheRecord("任务缓存记录不存在。")
        }

        task.title = title
        task.estimatedMinutes = estimatedMinutes
        task.priority = priority
        task.syncStatus = .localPending
        try cache.upsert(task)

        do {
            let context = try await configurationContext()
            let updated = try await notionClient.updateTaskTitle(
                pageID: id,
                title: title,
                priority: priority,
                estimatedMinutes: estimatedMinutes,
                fields: context.settings.tasksFieldMapping,
                token: context.token
            )
            var merged = updated
            if merged.estimatedMinutes == nil, let estimatedMinutes {
                merged.estimatedMinutes = estimatedMinutes
            }
            try cache.upsert(merged)
            return merged
        } catch {
            task.syncStatus = .failed
            try cache.upsert(task)
            throw error
        }
    }

    public func updateTaskTitle(id: String, title: String, estimatedMinutes: Int?) async throws -> TaskItem {
        guard let task = try cache.task(id: id) else {
            throw NotionRepositoryError.missingCacheRecord("任务缓存记录不存在。")
        }
        return try await updateTaskTitle(id: id, title: title, priority: task.priority, estimatedMinutes: estimatedMinutes)
    }

    public func deleteTask(id: String) async throws {
        guard try cache.task(id: id) != nil else {
            throw NotionRepositoryError.missingCacheRecord("任务缓存记录不存在。")
        }

        let context = try await configurationContext()
        try await notionClient.deleteTask(pageID: id, token: context.token)
        try cache.deleteTask(id: id)
    }

    public func createTask(title: String, date: Date, priority: String?, estimatedMinutes: Int?, hasPriorityField: Bool) async throws -> TaskItem {
        let context = try await configurationContext()
        let task = try await notionClient.createTask(
            databaseID: context.settings.tasksDatabaseID,
            title: title,
            date: date,
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            hasPriorityField: hasPriorityField,
            fields: context.settings.tasksFieldMapping,
            token: context.token
        )
        try cache.upsert(task)
        return task
    }

    public func loadOrCreateJournal(for date: Date = Date()) async throws -> JournalEntry {
        let context = try await configurationContext()

        do {
            if var journal = try await notionClient.findJournalPage(
                databaseID: context.settings.journalDatabaseID,
                fields: context.settings.journalFieldMapping,
                token: context.token,
                date: date
            ) {
                journal.syncStatus = .synced
                try cache.upsert(journal)
                return journal
            }

            let created = try await notionClient.createJournalPage(
                databaseID: context.settings.journalDatabaseID,
                fields: context.settings.journalFieldMapping,
                token: context.token,
                date: date
            )
            try cache.upsert(created)
            return created
        } catch {
            if let cached = try cache.journalEntry(for: date) {
                return cached
            }
            throw error
        }
    }

    public func saveJournal(entryID: String, text: String, date: Date = Date()) async throws -> JournalEntry {
        guard var entry = try cache.journalEntry(id: entryID) else {
            throw NotionRepositoryError.missingCacheRecord("日记缓存记录不存在。")
        }

        entry.contentText = text
        entry.syncStatus = .localPending
        try cache.upsert(entry)

        let payloadData = try JSONEncoder().encode(["text": text])
        let mutation = PendingMutation(
            target: .journal,
            targetID: entryID,
            type: .replaceJournalText,
            payload: String(decoding: payloadData, as: UTF8.self)
        )
        try cache.enqueue(mutation)

        do {
            let context = try await configurationContext()
            try await notionClient.replaceJournalText(pageID: entry.id, text: text, token: context.token)
            entry.syncStatus = .synced
            try cache.upsert(entry)
            try cache.markMutation(id: mutation.id, status: .synced, lastError: nil)
        } catch {
            entry.syncStatus = .failed
            try cache.upsert(entry)
            try cache.markMutation(id: mutation.id, status: .failed, lastError: String(describing: error))
            throw error
        }

        return entry
    }

    public func resetConfiguration() async throws {
        tokenStore.deleteToken()
        try await settingsStore.clear()
    }

    public func cachedJournal(for date: Date = Date()) async throws -> JournalEntry? {
        try cache.journalEntry(for: date)
    }

    /// 只读：读取本地缓存中指定日期的任务（不发网络请求），供月历印记使用。
    public func cachedTasks(for date: Date) async throws -> [TaskItem] {
        try cache.loadTasks(for: date)
    }

    /// 月历印记（远端刷新）：拉取指定月（monthAnchor 所在月）的日记条目（含正文），
    /// 只把本地缓存缺失的页面补进缓存（已有条目一律不覆盖，避免踩到本地未保存编辑），
    /// 返回 day -> 是否有非空内容。
    public func refreshJournalMarks(containing monthAnchor: Date) async throws -> [Int: Bool] {
        let context = try await configurationContext()
        let calendar = Calendar(identifier: .gregorian)
        guard
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor)),
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)
        else { return [:] }

        let entries = try await notionClient.findJournalEntries(
            databaseID: context.settings.journalDatabaseID,
            fields: context.settings.journalFieldMapping,
            token: context.token,
            from: monthStart,
            to: nextMonth
        )

        var marks: [Int: Bool] = [:]
        for var entry in entries {
            let day = calendar.component(.day, from: calendar.startOfDay(for: entry.date))
            marks[day] = !entry.contentText.isEmpty
            if try cache.journalEntry(id: entry.id) == nil {
                entry.syncStatus = .synced
                try cache.upsert(entry)
            }
        }
        return marks
    }

    /// 月历印记（远端刷新）：拉取指定月（monthAnchor 所在月）的任务，
    /// 只把本地缓存缺失的任务补进缓存（已有的不动），返回 day -> 是否有任务。
    public func refreshTaskMarks(containing monthAnchor: Date) async throws -> [Int: Bool] {
        let context = try await configurationContext()
        let calendar = Calendar(identifier: .gregorian)
        guard
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor)),
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)
        else { return [:] }

        let tasks = try await notionClient.queryTasks(
            from: monthStart,
            to: nextMonth,
            databaseID: context.settings.tasksDatabaseID,
            fields: context.settings.tasksFieldMapping,
            token: context.token
        )

        var marks: [Int: Bool] = [:]
        for var task in TaskSorting.sort(tasks) {
            let day = calendar.component(.day, from: calendar.startOfDay(for: task.date))
            marks[day] = true
            if try cache.task(id: task.id) == nil {
                task.syncStatus = .synced
                try cache.upsert(task)
            }
        }
        return marks
    }

    public func cachedJournal(id: String) async throws -> JournalEntry? {
        try cache.journalEntry(id: id)
    }

    private func configurationContext() async throws -> ConfigurationContext {
        guard let settings = try await settingsStore.load() else {
            throw NotionRepositoryError.missingConfiguration
        }
        guard let token = try tokenStore.loadToken(), !token.isEmpty else {
            throw NotionRepositoryError.missingToken
        }
        return ConfigurationContext(settings: settings, token: token)
    }
}

/// 待定变更队列一次重放的汇总结果。
public struct PendingMutationDrainResult: Sendable, Equatable {
    public enum StopReason: String, Sendable, Equatable {
        /// 未完成配置或缺 token，本次不处理任何条目。
        case missingConfiguration
        /// Notion 返回 401/403，需要重新授权，不自动重试。
        case unauthorized
        /// 其他写入失败（网络、限流等），保留队列等待下次触发。
        case writeFailed
    }

    /// 成功重放到 Notion 的条数。
    public let replayed: Int
    /// 因已被更新内容取代、目标不存在等原因跳过的条数。
    public let skipped: Int
    /// 非 nil 表示本次重放中途停止的原因；nil 表示全部处理完毕。
    public let stopReason: StopReason?

    public init(replayed: Int, skipped: Int, stopReason: StopReason?) {
        self.replayed = replayed
        self.skipped = skipped
        self.stopReason = stopReason
    }
}

public struct ConfigurationSnapshot: Sendable {
    public let hasToken: Bool
    public let token: String?
    public let tasksDatabaseID: String?
    public let journalDatabaseID: String?
    public let hasPriorityField: Bool
    public let choiceField: TaskChoiceField?

    public init(hasToken: Bool, token: String? = nil, tasksDatabaseID: String?, journalDatabaseID: String?, hasPriorityField: Bool = true, choiceField: TaskChoiceField? = nil) {
        self.hasToken = hasToken
        self.token = token
        self.tasksDatabaseID = tasksDatabaseID
        self.journalDatabaseID = journalDatabaseID
        self.hasPriorityField = hasPriorityField
        self.choiceField = choiceField
    }
}

public enum NotionRepositoryError: Error {
    case missingConfiguration
    case missingToken
    case invalidDatabaseInput(String)
    case validationFailed([ValidationIssue])
    case missingCacheRecord(String)
}

extension NotionRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "尚未完成 Notion 配置。"
        case .missingToken:
            return "Notion 令牌不存在或为空。"
        case let .invalidDatabaseInput(message):
            return message
        case let .validationFailed(issues):
            let details = issues.map { $0.message.string(in: .default) }.joined(separator: "；")
            return "数据库字段校验失败：\(details)"
        case let .missingCacheRecord(message):
            return message
        }
    }
}

private struct ConfigurationContext {
    let settings: AppSettings
    let token: String
}
