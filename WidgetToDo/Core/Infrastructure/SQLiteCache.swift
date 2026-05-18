import Foundation
import SQLite3

public final class SQLiteCache: @unchecked Sendable {
    private let db: OpaquePointer?
    private let iso8601 = ISO8601DateFormatter()

    public init(baseURL: URL? = nil) throws {
        let fileURL = try Self.resolveDatabaseURL(baseURL: baseURL)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var handle: OpaquePointer?
        guard sqlite3_open(fileURL.path, &handle) == SQLITE_OK else {
            throw SQLiteCacheError.openFailed(message: String(cString: sqlite3_errmsg(handle)))
        }

        db = handle
        try execute(
            """
            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                is_done INTEGER NOT NULL,
                priority TEXT,
                notion_date TEXT NOT NULL,
                url TEXT,
                sync_status TEXT NOT NULL,
                local_updated_at TEXT NOT NULL
            );
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS journal_entries (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                notion_date TEXT NOT NULL,
                content_text TEXT NOT NULL,
                url TEXT,
                sync_status TEXT NOT NULL,
                local_updated_at TEXT NOT NULL
            );
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS pending_mutations (
                id TEXT PRIMARY KEY,
                target_type TEXT NOT NULL,
                target_id TEXT NOT NULL,
                mutation_type TEXT NOT NULL,
                payload TEXT NOT NULL,
                retry_count INTEGER NOT NULL,
                status TEXT NOT NULL,
                last_error TEXT,
                created_at TEXT NOT NULL
            );
            """
        )
    }

    deinit {
        sqlite3_close(db)
    }

    public func loadTasks() throws -> [TaskItem] {
        let sql = "SELECT id, title, is_done, priority, notion_date, url, sync_status FROM tasks;"
        return try query(sql) { statement in
            let id = Self.readString(from: statement, at: 0)
            let title = Self.readString(from: statement, at: 1)
            let isDone = sqlite3_column_int(statement, 2) == 1
            let priority = Self.readOptionalString(from: statement, at: 3)
            let date = try parseDate(Self.readString(from: statement, at: 4))
            let url = Self.readOptionalString(from: statement, at: 5).flatMap(URL.init(string:))
            let syncStatus = SyncStatus(rawValue: Self.readString(from: statement, at: 6)) ?? .synced
            return TaskItem(id: id, title: title, isDone: isDone, priority: priority, date: date, url: url, syncStatus: syncStatus)
        }
    }

    public func task(id: String) throws -> TaskItem? {
        let sql = "SELECT id, title, is_done, priority, notion_date, url, sync_status FROM tasks WHERE id = ? LIMIT 1;"
        let rows = try query(sql, bindings: [id]) { statement in
            let taskID = Self.readString(from: statement, at: 0)
            let title = Self.readString(from: statement, at: 1)
            let isDone = sqlite3_column_int(statement, 2) == 1
            let priority = Self.readOptionalString(from: statement, at: 3)
            let date = try parseDate(Self.readString(from: statement, at: 4))
            let url = Self.readOptionalString(from: statement, at: 5).flatMap(URL.init(string:))
            let syncStatus = SyncStatus(rawValue: Self.readString(from: statement, at: 6)) ?? .synced
            return TaskItem(id: taskID, title: title, isDone: isDone, priority: priority, date: date, url: url, syncStatus: syncStatus)
        }
        return rows.first
    }

    public func saveTasks(_ tasks: [TaskItem]) throws {
        try execute("DELETE FROM tasks;")
        for task in tasks {
            try upsert(task)
        }
    }

    public func upsert(_ task: TaskItem) throws {
        try execute(
            """
            INSERT INTO tasks (id, title, is_done, priority, notion_date, url, sync_status, local_updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                is_done = excluded.is_done,
                priority = excluded.priority,
                notion_date = excluded.notion_date,
                url = excluded.url,
                sync_status = excluded.sync_status,
                local_updated_at = excluded.local_updated_at;
            """,
            bindings: [
                task.id,
                task.title,
                task.isDone ? "1" : "0",
                task.priority ?? NSNull(),
                iso8601.string(from: task.date),
                task.url?.absoluteString ?? NSNull(),
                task.syncStatus.rawValue,
                iso8601.string(from: Date())
            ]
        )
    }

    public func journalEntry(for date: Date) throws -> JournalEntry? {
        let sql = "SELECT id, title, notion_date, content_text, url, sync_status FROM journal_entries WHERE notion_date = ? LIMIT 1;"
        let rows = try query(sql, bindings: [iso8601.string(from: date)]) { statement in
            let id = Self.readString(from: statement, at: 0)
            let title = Self.readString(from: statement, at: 1)
            let entryDate = try parseDate(Self.readString(from: statement, at: 2))
            let content = Self.readString(from: statement, at: 3)
            let url = Self.readOptionalString(from: statement, at: 4).flatMap(URL.init(string:))
            let syncStatus = SyncStatus(rawValue: Self.readString(from: statement, at: 5)) ?? .synced
            return JournalEntry(id: id, title: title, date: entryDate, contentText: content, url: url, syncStatus: syncStatus)
        }
        return rows.first
    }

    public func upsert(_ entry: JournalEntry) throws {
        try execute(
            """
            INSERT INTO journal_entries (id, title, notion_date, content_text, url, sync_status, local_updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                notion_date = excluded.notion_date,
                content_text = excluded.content_text,
                url = excluded.url,
                sync_status = excluded.sync_status,
                local_updated_at = excluded.local_updated_at;
            """,
            bindings: [
                entry.id,
                entry.title,
                iso8601.string(from: entry.date),
                entry.contentText,
                entry.url?.absoluteString ?? NSNull(),
                entry.syncStatus.rawValue,
                iso8601.string(from: Date())
            ]
        )
    }

    public func enqueue(_ mutation: PendingMutation) throws {
        try execute(
            """
            INSERT INTO pending_mutations (id, target_type, target_id, mutation_type, payload, retry_count, status, last_error, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                retry_count = excluded.retry_count,
                status = excluded.status,
                last_error = excluded.last_error;
            """,
            bindings: [
                mutation.id,
                mutation.target.rawValue,
                mutation.targetID,
                mutation.type.rawValue,
                mutation.payload,
                "\(mutation.retryCount)",
                mutation.status.rawValue,
                mutation.lastError ?? NSNull(),
                iso8601.string(from: mutation.createdAt)
            ]
        )
    }

    public func markMutation(id: String, status: PendingMutationStatus, lastError: String?) throws {
        try execute(
            "UPDATE pending_mutations SET status = ?, last_error = ?, retry_count = retry_count + 1 WHERE id = ?;",
            bindings: [status.rawValue, lastError ?? NSNull(), id]
        )
    }

    private func execute(_ sql: String, bindings: [Any] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteCacheError.statementFailed(message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteCacheError.statementFailed(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    private func query<T>(_ sql: String, bindings: [Any] = [], row: (OpaquePointer) throws -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteCacheError.statementFailed(message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        var rows: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            try rows.append(row(statement!))
        }
        return rows
    }

    private func bind(_ bindings: [Any], to statement: OpaquePointer?) throws {
        for (index, value) in bindings.enumerated() {
            let parameterIndex = Int32(index + 1)
            switch value {
            case let string as String:
                sqlite3_bind_text(statement, parameterIndex, string, -1, SQLITE_TRANSIENT)
            case let number as NSString:
                sqlite3_bind_text(statement, parameterIndex, number.utf8String, -1, SQLITE_TRANSIENT)
            case is NSNull:
                sqlite3_bind_null(statement, parameterIndex)
            default:
                sqlite3_bind_text(statement, parameterIndex, "\(value)", -1, SQLITE_TRANSIENT)
            }
        }
    }

    private func parseDate(_ value: String) throws -> Date {
        guard let date = iso8601.date(from: value) else {
            throw SQLiteCacheError.invalidDate(value)
        }
        return date
    }

    private static func readString(from statement: OpaquePointer, at index: Int32) -> String {
        String(cString: sqlite3_column_text(statement, index))
    }

    private static func readOptionalString(from statement: OpaquePointer, at index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: pointer)
    }

    private static func resolveDatabaseURL(baseURL: URL?) throws -> URL {
        if let baseURL {
            return baseURL.appendingPathComponent("cache.sqlite")
        }

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return appSupport
            .appendingPathComponent("NotionFloat", isDirectory: true)
            .appendingPathComponent("cache.sqlite")
    }
}

public enum SQLiteCacheError: Error {
    case openFailed(message: String)
    case statementFailed(message: String)
    case invalidDate(String)
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
