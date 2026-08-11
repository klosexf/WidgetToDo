import XCTest
@testable import NotionFloatCore

final class NotionRepositoryTaskMutationTests: XCTestCase {
    func testUpdateTaskTitleUpdatesCacheAfterSuccessfulRemoteWrite() async throws {
        let task = makeTask()
        let responseBody = """
        {
          "id": "\(task.id)",
          "url": "https://www.notion.so/task-1",
          "properties": {
            "任务标题": { "title": [{ "plain_text": "修改后的任务标题" }] },
            "计划日期": { "date": { "start": "2026-05-21" } },
            "已完成": { "checkbox": false },
            "任务优先级": { "select": { "name": "High" } }
          }
        }
        """
        let harness = try await makeHarness(responseStatusCode: 200, responseBody: responseBody)
        try harness.cache.upsert(task)

        let updated = try await harness.repository.updateTaskTitle(id: task.id, title: "修改后的任务标题", estimatedMinutes: nil)

        XCTAssertEqual(updated.title, "修改后的任务标题")
        XCTAssertEqual(updated.syncStatus, .synced)
        let requestBody = try XCTUnwrap(MockURLProtocol.lastRequestBody)
        XCTAssertTrue(requestBody.contains(#""任务标题""#))
        XCTAssertFalse(requestBody.contains(#""Name""#))
        let cached = try XCTUnwrap(harness.cache.task(id: task.id))
        XCTAssertEqual(cached.title, "修改后的任务标题")
        XCTAssertEqual(cached.syncStatus, .synced)
    }

    func testUpdateTaskTitleUpdatesEstimatedMinutesInPayloadAndCache() async throws {
        let task = makeTask()
        let responseBody = """
        {
          "id": "\(task.id)",
          "url": "https://www.notion.so/task-1",
          "properties": {
            "任务标题": { "title": [{ "plain_text": "原始任务标题" }] },
            "计划日期": { "date": { "start": "2026-05-21" } },
            "已完成": { "checkbox": false },
            "任务优先级": { "select": { "name": "High" } },
            "预计时长": { "number": 90 }
          }
        }
        """
        let harness = try await makeHarness(responseStatusCode: 200, responseBody: responseBody)
        try harness.cache.upsert(task)

        let updated = try await harness.repository.updateTaskTitle(id: task.id, title: "原始任务标题", estimatedMinutes: 90)

        XCTAssertEqual(updated.estimatedMinutes, 90)
        XCTAssertEqual(updated.syncStatus, .synced)
        let requestBody = try XCTUnwrap(MockURLProtocol.lastRequestBody)
        XCTAssertTrue(requestBody.contains(#""预计时长""#))
        XCTAssertTrue(requestBody.contains(#""number":90"#))
        let cached = try XCTUnwrap(harness.cache.task(id: task.id))
        XCTAssertEqual(cached.estimatedMinutes, 90)
        XCTAssertEqual(cached.syncStatus, .synced)
    }

    func testUpdateTaskTitleClearsConfiguredSelectField() async throws {
        let task = makeTask()
        let responseBody = """
        {
          "id": "\(task.id)",
          "url": "https://www.notion.so/task-1",
          "properties": {
            "任务标题": { "title": [{ "plain_text": "原始任务标题" }] },
            "计划日期": { "date": { "start": "2026-05-21" } },
            "已完成": { "checkbox": false },
            "任务优先级": { "select": null }
          }
        }
        """
        let harness = try await makeHarness(responseStatusCode: 200, responseBody: responseBody)
        try harness.cache.upsert(task)

        let updated = try await harness.repository.updateTaskTitle(
            id: task.id,
            title: "原始任务标题",
            priority: nil,
            estimatedMinutes: nil
        )

        XCTAssertNil(updated.priority)
        let requestBody = try XCTUnwrap(MockURLProtocol.lastRequestBody)
        XCTAssertTrue(requestBody.contains(#""任务优先级""#))
        XCTAssertTrue(requestBody.contains(#""select":null"#))
    }

    func testUpdateTaskTitleOmitsSelectFieldWhenMappingHasNoOptions() async throws {
        let task = makeTask()
        let responseBody = """
        {
          "id": "\(task.id)",
          "url": "https://www.notion.so/task-1",
          "properties": {
            "任务标题": { "title": [{ "plain_text": "原始任务标题" }] },
            "计划日期": { "date": { "start": "2026-05-21" } },
            "已完成": { "checkbox": false },
            "任务优先级": { "select": { "name": "High" } }
          }
        }
        """
        let harness = try await makeHarness(
            responseStatusCode: 200,
            responseBody: responseBody,
            priorityOptions: []
        )
        try harness.cache.upsert(task)

        _ = try await harness.repository.updateTaskTitle(id: task.id, title: "原始任务标题", estimatedMinutes: nil)

        let requestBody = try XCTUnwrap(MockURLProtocol.lastRequestBody)
        XCTAssertFalse(requestBody.contains(#""任务优先级""#))
    }

    func testUpdateTaskTitleOmitsEstimatedMinutesWhenMappingIsNil() async throws {
        let task = makeTask()
        let responseBody = """
        {
          "id": "\(task.id)",
          "url": "https://www.notion.so/task-1",
          "properties": {
            "任务标题": { "title": [{ "plain_text": "原始任务标题" }] },
            "计划日期": { "date": { "start": "2026-05-21" } },
            "已完成": { "checkbox": false },
            "任务优先级": { "select": { "name": "High" } }
          }
        }
        """
        let harness = try await makeHarness(
            responseStatusCode: 200,
            responseBody: responseBody,
            estimatedMinutesField: nil
        )
        try harness.cache.upsert(task)

        let updated = try await harness.repository.updateTaskTitle(id: task.id, title: "原始任务标题", estimatedMinutes: 90)

        XCTAssertEqual(updated.estimatedMinutes, 90)
        let requestBody = try XCTUnwrap(MockURLProtocol.lastRequestBody)
        XCTAssertFalse(requestBody.contains(#""预计时长""#))
        let cached = try XCTUnwrap(harness.cache.task(id: task.id))
        XCTAssertEqual(cached.estimatedMinutes, 90)
    }

    /// 番茄钟累计写回契约：任务原有时长 45 分钟，完成一轮 25 分钟后，
    /// 视图层计算 `45 + 25 = 70` 并复用现有 `updateTaskTitle` 写入；
    /// 返回值与缓存必须为 70，请求体必须命中已映射的 number 字段。
    func testPomodoroAccumulationWritesCumulativeDurationToExistingField() async throws {
        let task = TaskItem(
            id: "task-pomodoro",
            title: "写 WidgetToDo PRD",
            isDone: false,
            priority: "High",
            estimatedMinutes: 45,
            date: ISO8601DateFormatter().date(from: "2026-05-21T00:00:00Z")!,
            url: URL(string: "https://www.notion.so/task-pomodoro"),
            syncStatus: .synced
        )
        let responseBody = """
        {
          "id": "\(task.id)",
          "url": "https://www.notion.so/task-pomodoro",
          "properties": {
            "任务标题": { "title": [{ "plain_text": "写 WidgetToDo PRD" }] },
            "计划日期": { "date": { "start": "2026-05-21" } },
            "已完成": { "checkbox": false },
            "任务优先级": { "select": { "name": "High" } },
            "预计时长": { "number": 70 }
          }
        }
        """
        let harness = try await makeHarness(responseStatusCode: 200, responseBody: responseBody)
        try harness.cache.upsert(task)

        let newTotal = (task.estimatedMinutes ?? 0) + 25
        let updated = try await harness.repository.updateTaskTitle(
            id: task.id,
            title: task.title,
            estimatedMinutes: newTotal
        )

        XCTAssertEqual(newTotal, 70)
        XCTAssertEqual(updated.estimatedMinutes, 70)
        XCTAssertEqual(updated.syncStatus, .synced)
        let requestBody = try XCTUnwrap(MockURLProtocol.lastRequestBody)
        XCTAssertTrue(requestBody.contains(#""预计时长""#), "累计写回应复用已映射的 number 字段名")
        XCTAssertTrue(requestBody.contains(#""number":70"#), "请求体应携带累计后的 70 分钟")
        let cached = try XCTUnwrap(harness.cache.task(id: task.id))
        XCTAssertEqual(cached.estimatedMinutes, 70)
        XCTAssertEqual(cached.syncStatus, .synced)
    }

    func testUpdateTaskTitleMarksCacheFailedWhenRemoteWriteFails() async throws {
        let task = makeTask()
        let harness = try await makeHarness(
            responseStatusCode: 400,
            responseBody: #"{"object":"error","status":400,"message":"title is invalid"}"#
        )
        try harness.cache.upsert(task)

        do {
            _ = try await harness.repository.updateTaskTitle(id: task.id, title: "失败后的标题", estimatedMinutes: nil)
            XCTFail("Expected updateTaskTitle to throw")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Notion 请求失败（HTTP 400）：title is invalid")
        }

        let cached = try XCTUnwrap(harness.cache.task(id: task.id))
        XCTAssertEqual(cached.title, "失败后的标题")
        XCTAssertEqual(cached.syncStatus, .failed)
    }

    func testDeleteTaskRemovesTaskFromCacheAfterSuccessfulArchive() async throws {
        let task = makeTask()
        let responseBody = """
        {
          "id": "\(task.id)",
          "url": "https://www.notion.so/task-1",
          "properties": {
            "任务标题": { "title": [{ "plain_text": "\(task.title)" }] },
            "计划日期": { "date": { "start": "2026-05-21" } },
            "已完成": { "checkbox": false },
            "任务优先级": { "select": { "name": "High" } }
          }
        }
        """
        let harness = try await makeHarness(responseStatusCode: 200, responseBody: responseBody)
        try harness.cache.upsert(task)

        try await harness.repository.deleteTask(id: task.id)

        XCTAssertNil(try harness.cache.task(id: task.id))
    }

    func testCreateTaskUsesResolvedCustomFieldNames() async throws {
        let createResponseBody = """
        {
          "id": "task-created",
          "url": "https://www.notion.so/task-created",
          "properties": {
            "任务标题": { "title": [{ "plain_text": "新任务" }] },
            "计划日期": { "date": { "start": "2026-05-21" } },
            "已完成": { "checkbox": false },
            "任务优先级": { "select": { "name": "High" } },
            "预计时长": { "number": 60 }
          }
        }
        """
        let harness = try await makeHarness(responseStatusCode: 200, responseBody: createResponseBody)

        _ = try await harness.repository.createTask(
            title: "新任务",
            date: ISO8601DateFormatter().date(from: "2026-05-21T00:00:00Z")!,
            priority: "High",
            estimatedMinutes: 60,
            hasPriorityField: true
        )

        let requestBody = try XCTUnwrap(MockURLProtocol.lastRequestBody)
        XCTAssertTrue(requestBody.contains(#""任务标题""#))
        XCTAssertTrue(requestBody.contains(#""计划日期""#))
        XCTAssertTrue(requestBody.contains(#""已完成""#))
        XCTAssertTrue(requestBody.contains(#""任务优先级""#))
        XCTAssertTrue(requestBody.contains(#""预计时长""#))
        XCTAssertTrue(requestBody.contains(#""number":60"#))
        XCTAssertFalse(requestBody.contains(#""Name""#))
        XCTAssertFalse(requestBody.contains(#""Date""#))
        XCTAssertFalse(requestBody.contains(#""Done""#))
        XCTAssertFalse(requestBody.contains(#""Priority""#))
    }

    func testCreateTaskOmitsEstimatedMinutesWhenDraftLeavesItEmpty() async throws {
        let createResponseBody = """
        {
          "id": "task-created",
          "url": "https://www.notion.so/task-created",
          "properties": {
            "任务标题": { "title": [{ "plain_text": "新任务" }] },
            "计划日期": { "date": { "start": "2026-05-21" } },
            "已完成": { "checkbox": false },
            "任务优先级": { "select": { "name": "High" } }
          }
        }
        """
        let harness = try await makeHarness(responseStatusCode: 200, responseBody: createResponseBody)

        _ = try await harness.repository.createTask(
            title: "新任务",
            date: ISO8601DateFormatter().date(from: "2026-05-21T00:00:00Z")!,
            priority: "High",
            estimatedMinutes: nil,
            hasPriorityField: true
        )

        let requestBody = try XCTUnwrap(MockURLProtocol.lastRequestBody)
        XCTAssertFalse(requestBody.contains(#""预计时长""#))
    }

    func testDeleteTaskThrowsReadableErrorWhenCacheRecordMissing() async throws {
        let harness = try await makeHarness(responseStatusCode: 200, responseBody: "{}")

        do {
            try await harness.repository.deleteTask(id: "missing-task")
            XCTFail("Expected deleteTask to throw")
        } catch {
            XCTAssertEqual(error.localizedDescription, "任务缓存记录不存在。")
        }
    }

    func testSaveJournalUsesEntryIDWhenSameDayHasMultipleCachedEntries() async throws {
        let responseBody = #"{"results":[]}"#
        let harness = try await makeHarness(responseStatusCode: 200, responseBody: responseBody)
        let date = ISO8601DateFormatter().date(from: "2026-07-12T00:00:00Z")!
        let staleEntry = JournalEntry(
            id: "journal-stale",
            title: "日记 2026年7月12日",
            date: date,
            contentText: "旧内容",
            url: URL(string: "https://www.notion.so/journal-stale"),
            syncStatus: .synced
        )
        let currentEntry = JournalEntry(
            id: "journal-current",
            title: "日记 2026年7月12日",
            date: date,
            contentText: "",
            url: URL(string: "https://www.notion.so/journal-current"),
            syncStatus: .synced
        )
        try harness.cache.upsert(staleEntry)
        try harness.cache.upsert(currentEntry)

        let saved = try await harness.repository.saveJournal(
            entryID: currentEntry.id,
            text: "当天的新内容",
            date: date
        )

        XCTAssertEqual(saved.id, currentEntry.id)
        XCTAssertEqual(saved.contentText, "当天的新内容")
        XCTAssertEqual(saved.syncStatus, .synced)
    }

    private func makeHarness(
        responseStatusCode: Int,
        responseBody: String,
        estimatedMinutesField: String? = "预计时长",
        priorityOptions: [NotionSelectOption] = [NotionSelectOption(name: "High", color: .orange)]
    ) async throws -> RepositoryHarness {
        let tokenStore = InMemoryTokenStore()

        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        MockURLProtocol.responseStatusCode = responseStatusCode
        MockURLProtocol.responseBody = Data(responseBody.utf8)
        MockURLProtocol.lastRequestBody = nil

        let settingsStore = try SettingsStore(baseURL: tempDirectoryURL)
        try await settingsStore.save(
            AppSettings(
                tasksDatabaseID: "tasks-db",
                journalDatabaseID: "journal-db",
                lastValidatedAt: Date(),
                hasPriorityField: true,
                tasksFieldMapping: TaskDatabaseFieldMapping(
                    title: "任务标题",
                    date: "计划日期",
                    done: "已完成",
                    priority: "任务优先级",
                    priorityOptions: priorityOptions,
                    estimatedMinutes: estimatedMinutesField
                ),
                journalFieldMapping: JournalDatabaseFieldMapping(
                    title: "日记标题",
                    date: "记录日期"
                )
            )
        )
        try tokenStore.save(token: "secret_test_token")

        let cache = try SQLiteCache(baseURL: tempDirectoryURL)
        let repository = NotionRepository(
            tokenStore: tokenStore,
            settingsStore: settingsStore,
            cache: cache,
            notionClient: NotionClient(session: URLSession(configuration: config))
        )
        return RepositoryHarness(
            repository: repository,
            cache: cache,
            tempDirectoryURL: tempDirectoryURL
        )
    }

    private func makeTask() -> TaskItem {
        TaskItem(
            id: "task-1",
            title: "原始任务标题",
            isDone: false,
            priority: "High",
            estimatedMinutes: 60,
            date: ISO8601DateFormatter().date(from: "2026-05-21T00:00:00Z")!,
            url: URL(string: "https://www.notion.so/task-1"),
            syncStatus: .synced
        )
    }
}

private final class RepositoryHarness {
    let repository: NotionRepository
    let cache: SQLiteCache
    private let tempDirectoryURL: URL

    init(repository: NotionRepository, cache: SQLiteCache, tempDirectoryURL: URL) {
        self.repository = repository
        self.cache = cache
        self.tempDirectoryURL = tempDirectoryURL
    }

    deinit {
        try? FileManager.default.removeItem(at: tempDirectoryURL)
    }
}

private final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private var token: String?

    func save(token: String) throws {
        self.token = token
    }

    func loadToken() throws -> String? {
        token
    }

    func deleteToken() {
        token = nil
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responseStatusCode = 200
    nonisolated(unsafe) static var responseBody = Data()
    nonisolated(unsafe) static var lastRequestBody: String?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if let body = request.httpBody {
            Self.lastRequestBody = String(decoding: body, as: UTF8.self)
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            let data = NSMutableData()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: 4096)
                guard read > 0 else { break }
                data.append(buffer, length: read)
            }
            Self.lastRequestBody = String(decoding: data as Data, as: UTF8.self)
        } else {
            Self.lastRequestBody = nil
        }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: Self.responseStatusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
