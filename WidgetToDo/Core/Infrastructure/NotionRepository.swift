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
        return ConfigurationSnapshot(
            hasToken: token?.isEmpty == false,
            token: token,
            tasksDatabaseID: settings?.tasksDatabaseID,
            journalDatabaseID: settings?.journalDatabaseID,
            hasPriorityField: settings?.hasPriorityField ?? true
        )
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

        let taskIssues = FieldValidator.validate(taskSchema, for: .tasks)
        let journalIssues = FieldValidator.validate(journalSchema, for: .journal)
        let issues = taskIssues + journalIssues
        guard issues.isEmpty else {
            throw NotionRepositoryError.validationFailed(issues)
        }

        let hasPriorityField = taskSchema.contains { $0.name == "Priority" && $0.type == "select" }
        let settings = AppSettings(
            tasksDatabaseID: tasksReference.rawValue,
            journalDatabaseID: journalReference.rawValue,
            lastValidatedAt: Date(),
            hasPriorityField: hasPriorityField
        )
        try await settingsStore.save(settings)
        return settings
    }

    public func loadTasks(for date: Date = Date()) async throws -> [TaskItem] {
        let context = try await configurationContext()

        do {
            let tasks = TaskSorting.sort(
                try await notionClient.queryTasks(on: date, databaseID: context.settings.tasksDatabaseID, token: context.token)
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
            try await notionClient.updateTaskCheckbox(pageID: id, isDone: isDone, token: context.token)
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

    public func updateTaskTitle(id: String, title: String) async throws -> TaskItem {
        guard var task = try cache.task(id: id) else {
            throw NotionRepositoryError.missingCacheRecord("任务缓存记录不存在。")
        }

        task.title = title
        task.syncStatus = .localPending
        try cache.upsert(task)

        do {
            let context = try await configurationContext()
            let updated = try await notionClient.updateTaskTitle(pageID: id, title: title, token: context.token)
            try cache.upsert(updated)
            return updated
        } catch {
            task.syncStatus = .failed
            try cache.upsert(task)
            throw error
        }
    }

    public func deleteTask(id: String) async throws {
        guard try cache.task(id: id) != nil else {
            throw NotionRepositoryError.missingCacheRecord("任务缓存记录不存在。")
        }

        let context = try await configurationContext()
        try await notionClient.deleteTask(pageID: id, token: context.token)
        try cache.deleteTask(id: id)
    }

    public func createTask(title: String, date: Date, priority: String?, hasPriorityField: Bool) async throws -> TaskItem {
        let context = try await configurationContext()
        let task = try await notionClient.createTask(
            databaseID: context.settings.tasksDatabaseID,
            title: title,
            date: date,
            priority: priority,
            hasPriorityField: hasPriorityField,
            token: context.token
        )
        try cache.upsert(task)
        return task
    }

    public func loadOrCreateJournal(for date: Date = Date()) async throws -> JournalEntry {
        let context = try await configurationContext()

        do {
            if var journal = try await notionClient.findJournalPage(databaseID: context.settings.journalDatabaseID, token: context.token, date: date) {
                journal.syncStatus = .synced
                try cache.upsert(journal)
                return journal
            }

            let created = try await notionClient.createJournalPage(databaseID: context.settings.journalDatabaseID, token: context.token, date: date)
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
        guard var entry = try cache.journalEntry(for: date), entry.id == entryID else {
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

    public func cachedJournal(for date: Date = Date()) async throws -> JournalEntry? {
        try cache.journalEntry(for: date)
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

public struct ConfigurationSnapshot: Sendable {
    public let hasToken: Bool
    public let token: String?
    public let tasksDatabaseID: String?
    public let journalDatabaseID: String?
    public let hasPriorityField: Bool

    public init(hasToken: Bool, token: String? = nil, tasksDatabaseID: String?, journalDatabaseID: String?, hasPriorityField: Bool = true) {
        self.hasToken = hasToken
        self.token = token
        self.tasksDatabaseID = tasksDatabaseID
        self.journalDatabaseID = journalDatabaseID
        self.hasPriorityField = hasPriorityField
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
            let details = issues.map(\.message).joined(separator: "；")
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
