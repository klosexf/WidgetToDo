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

        let updated = try await harness.repository.updateTaskTitle(id: task.id, title: "修改后的任务标题")

        XCTAssertEqual(updated.title, "修改后的任务标题")
        XCTAssertEqual(updated.syncStatus, .synced)
        let requestBody = try XCTUnwrap(MockURLProtocol.lastRequestBody)
        XCTAssertTrue(requestBody.contains(#""任务标题""#))
        XCTAssertFalse(requestBody.contains(#""Name""#))
        let cached = try XCTUnwrap(harness.cache.task(id: task.id))
        XCTAssertEqual(cached.title, "修改后的任务标题")
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
            _ = try await harness.repository.updateTaskTitle(id: task.id, title: "失败后的标题")
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

    private func makeHarness(responseStatusCode: Int, responseBody: String) async throws -> RepositoryHarness {
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
                    estimatedMinutes: "预计时长"
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
