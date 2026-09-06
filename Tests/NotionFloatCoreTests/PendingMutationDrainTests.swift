import XCTest
@testable import NotionFloatCore

/// `drainPendingMutations()` 契约测试：
/// 重放 queued/failed 变更、last-write-wins、已同步目标跳过、401 停止、失败保留队列。
final class PendingMutationDrainTests: XCTestCase {
    override func setUp() {
        super.setUp()
        DrainMockURLProtocol.reset()
    }

    func testDrainReplaysFailedTaskToggleAndMarksSynced() async throws {
        let task = makeTask(id: "task-1", isDone: true, syncStatus: .failed)
        let harness = try await makeHarness(responses: [
            (200, pageBody(id: "task-1", isDone: true))
        ])
        try harness.cache.upsert(task)
        try harness.cache.enqueue(makeMutation(
            id: "mut-1",
            target: .task,
            targetID: "task-1",
            type: .toggleCheckbox,
            payload: #"{"isDone":true}"#,
            status: .failed
        ))

        let result = await harness.repository.drainPendingMutations()

        XCTAssertEqual(result, PendingMutationDrainResult(replayed: 1, skipped: 0, stopReason: nil))
        let cached = try XCTUnwrap(harness.cache.task(id: "task-1"))
        XCTAssertEqual(cached.syncStatus, .synced)
        XCTAssertEqual(cached.isDone, true)
        XCTAssertTrue(try harness.cache.pendingMutations().isEmpty, "成功后队列应清空")
        XCTAssertEqual(DrainMockURLProtocol.requestBodies.count, 1)
        XCTAssertTrue(DrainMockURLProtocol.requestBodies[0].contains(#""checkbox":true"#))
    }

    func testDrainReplaysOnlyLatestJournalMutationPerTarget() async throws {
        let date = ISO8601DateFormatter().date(from: "2026-08-20T00:00:00Z")!
        let entry = makeEntry(id: "journal-1", date: date, contentText: "第二条内容", syncStatus: .failed)
        let harness = try await makeHarness(responses: [
            (200, #"{"results":[]}"#),
            (200, #"{"results":[]}"#)
        ])
        try harness.cache.upsert(entry)
        // 两条同目标 replaceJournalText：旧的应被最新的取代（last-write-wins）。
        try harness.cache.enqueue(makeMutation(
            id: "mut-old",
            target: .journal,
            targetID: "journal-1",
            type: .replaceJournalText,
            payload: payload(text: "旧内容"),
            status: .failed,
            createdAt: date
        ))
        try harness.cache.enqueue(makeMutation(
            id: "mut-new",
            target: .journal,
            targetID: "journal-1",
            type: .replaceJournalText,
            payload: payload(text: "第二条内容"),
            status: .failed,
            createdAt: date.addingTimeInterval(60)
        ))

        let result = await harness.repository.drainPendingMutations()

        XCTAssertEqual(result, PendingMutationDrainResult(replayed: 1, skipped: 1, stopReason: nil))
        let cached = try XCTUnwrap(harness.cache.journalEntry(id: "journal-1"))
        XCTAssertEqual(cached.contentText, "第二条内容")
        XCTAssertEqual(cached.syncStatus, .synced)
        XCTAssertTrue(try harness.cache.pendingMutations().isEmpty, "被取代的旧条目也应结案清空")
        // 只应发送最新文本，旧文本不应出现在任何请求体中。
        let bodies = DrainMockURLProtocol.requestBodies.joined()
        XCTAssertTrue(bodies.contains("第二条内容"))
        XCTAssertFalse(bodies.contains("旧内容"))
    }

    func testDrainSkipsJournalMutationWhenNewerContentAlreadySynced() async throws {
        let date = ISO8601DateFormatter().date(from: "2026-08-20T00:00:00Z")!
        let entry = makeEntry(id: "journal-1", date: date, contentText: "新内容", syncStatus: .synced)
        let harness = try await makeHarness(responses: [])
        try harness.cache.upsert(entry)
        try harness.cache.enqueue(makeMutation(
            id: "mut-1",
            target: .journal,
            targetID: "journal-1",
            type: .replaceJournalText,
            payload: payload(text: "旧内容"),
            status: .failed
        ))

        let result = await harness.repository.drainPendingMutations()

        XCTAssertEqual(result, PendingMutationDrainResult(replayed: 0, skipped: 1, stopReason: nil))
        XCTAssertTrue(DrainMockURLProtocol.requests.isEmpty, "已同步目标不应发起任何请求")
        XCTAssertEqual(try harness.cache.journalEntry(id: "journal-1")?.contentText, "新内容")
        XCTAssertTrue(try harness.cache.pendingMutations().isEmpty)
    }

    func testDrainKeepsQueueWhenWriteStillFails() async throws {
        let task = makeTask(id: "task-1", isDone: true, syncStatus: .failed)
        let harness = try await makeHarness(responses: [
            (500, #"{"object":"error","status":500,"message":"internal"}"#)
        ])
        try harness.cache.upsert(task)
        try harness.cache.enqueue(makeMutation(
            id: "mut-1",
            target: .task,
            targetID: "task-1",
            type: .toggleCheckbox,
            payload: #"{"isDone":true}"#,
            status: .failed
        ))

        let result = await harness.repository.drainPendingMutations()

        XCTAssertEqual(result.stopReason, .writeFailed)
        XCTAssertEqual(result.replayed, 0)
        XCTAssertEqual(try harness.cache.task(id: "task-1")?.syncStatus, .failed)
        let remaining = try harness.cache.pendingMutations()
        XCTAssertEqual(remaining.count, 1, "失败条目应保留在队列等待下次触发")
        XCTAssertEqual(remaining.first?.id, "mut-1")
    }

    func testDrainStopsOnUnauthorizedWithoutProcessingRemainingMutations() async throws {
        let first = makeTask(id: "task-1", isDone: true, syncStatus: .failed)
        let second = makeTask(id: "task-2", isDone: true, syncStatus: .failed)
        let harness = try await makeHarness(responses: [
            (401, #"{"object":"error","status":401,"message":"unauthorized"}"#)
        ])
        try harness.cache.upsert(first)
        try harness.cache.upsert(second)
        try harness.cache.enqueue(makeMutation(
            id: "mut-1",
            target: .task,
            targetID: "task-1",
            type: .toggleCheckbox,
            payload: #"{"isDone":true}"#,
            status: .failed
        ))
        try harness.cache.enqueue(makeMutation(
            id: "mut-2",
            target: .task,
            targetID: "task-2",
            type: .toggleCheckbox,
            payload: #"{"isDone":true}"#,
            status: .failed,
            createdAt: Date().addingTimeInterval(1)
        ))

        let result = await harness.repository.drainPendingMutations()

        XCTAssertEqual(result.stopReason, .unauthorized, "401 应停止且不重试")
        XCTAssertEqual(DrainMockURLProtocol.requests.count, 1, "授权失效后不应继续请求")
        let remaining = try harness.cache.pendingMutations()
        XCTAssertEqual(remaining.count, 2, "两条都应保留（401 不清队列）")
    }

    func testDrainWithoutConfigurationLeavesQueueUntouched() async throws {
        let harness = try await makeHarness(responses: [], saveConfiguration: false)
        try harness.cache.enqueue(makeMutation(
            id: "mut-1",
            target: .task,
            targetID: "task-1",
            type: .toggleCheckbox,
            payload: #"{"isDone":true}"#,
            status: .queued
        ))

        let result = await harness.repository.drainPendingMutations()

        XCTAssertEqual(result, PendingMutationDrainResult(replayed: 0, skipped: 0, stopReason: .missingConfiguration))
        XCTAssertEqual(try harness.cache.pendingMutations().count, 1, "未配置时不应动队列")
    }

    func testDrainSkipsMutationWhoseTaskNoLongerExists() async throws {
        let harness = try await makeHarness(responses: [])
        try harness.cache.enqueue(makeMutation(
            id: "mut-1",
            target: .task,
            targetID: "task-deleted",
            type: .toggleCheckbox,
            payload: #"{"isDone":true}"#,
            status: .failed
        ))

        let result = await harness.repository.drainPendingMutations()

        XCTAssertEqual(result, PendingMutationDrainResult(replayed: 0, skipped: 1, stopReason: nil))
        XCTAssertTrue(DrainMockURLProtocol.requests.isEmpty)
        XCTAssertTrue(try harness.cache.pendingMutations().isEmpty)
    }

    // MARK: - Helpers

    private func makeHarness(
        responses: [(statusCode: Int, body: String)],
        saveConfiguration: Bool = true
    ) async throws -> RepositoryHarness {
        DrainMockURLProtocol.reset()
        DrainMockURLProtocol.responses = responses

        let tokenStore = InMemoryDrainTokenStore()
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)

        if saveConfiguration {
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
                        priorityOptions: [NotionSelectOption(name: "High", color: .orange)],
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
                notionClient: NotionClient(session: makeMockSession())
            )
            return RepositoryHarness(repository: repository, cache: cache, tempDirectoryURL: tempDirectoryURL)
        }

        let settingsStore = try SettingsStore(baseURL: tempDirectoryURL)
        let cache = try SQLiteCache(baseURL: tempDirectoryURL)
        let repository = NotionRepository(
            tokenStore: tokenStore,
            settingsStore: settingsStore,
            cache: cache,
            notionClient: NotionClient(session: makeMockSession())
        )
        return RepositoryHarness(repository: repository, cache: cache, tempDirectoryURL: tempDirectoryURL)
    }

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DrainMockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeTask(id: String, isDone: Bool, syncStatus: SyncStatus) -> TaskItem {
        TaskItem(
            id: id,
            title: "任务 \(id)",
            isDone: isDone,
            priority: nil,
            estimatedMinutes: nil,
            date: ISO8601DateFormatter().date(from: "2026-08-20T00:00:00Z")!,
            url: URL(string: "https://www.notion.so/\(id)"),
            syncStatus: syncStatus
        )
    }

    private func makeEntry(id: String, date: Date, contentText: String, syncStatus: SyncStatus) -> JournalEntry {
        JournalEntry(
            id: id,
            title: "日记",
            date: date,
            contentText: contentText,
            url: URL(string: "https://www.notion.so/\(id)"),
            syncStatus: syncStatus
        )
    }

    private func makeMutation(
        id: String,
        target: PendingMutationTarget,
        targetID: String,
        type: PendingMutationType,
        payload: String,
        status: PendingMutationStatus,
        createdAt: Date = Date()
    ) -> PendingMutation {
        PendingMutation(
            id: id,
            target: target,
            targetID: targetID,
            type: type,
            payload: payload,
            status: status,
            createdAt: createdAt
        )
    }

    private func payload(text: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: ["text": text])
        return String(decoding: data, as: UTF8.self)
    }

    private func pageBody(id: String, isDone: Bool) -> String {
        """
        {
          "id": "\(id)",
          "url": "https://www.notion.so/\(id)",
          "properties": {
            "任务标题": { "title": [{ "plain_text": "任务 \(id)" }] },
            "计划日期": { "date": { "start": "2026-08-20" } },
            "已完成": { "checkbox": \(isDone) }
          }
        }
        """
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

private final class InMemoryDrainTokenStore: TokenStore, @unchecked Sendable {
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

/// 按顺序消费响应队列的 URLProtocol：每个请求弹出队首响应，并记录请求体。
private final class DrainMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [(statusCode: Int, body: String)] = []
    nonisolated(unsafe) static var requests: [URLRequest] = []
    nonisolated(unsafe) static var requestBodies: [String] = []

    static func reset() {
        responses = []
        requests = []
        requestBodies = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.append(request)
        if let body = request.httpBody {
            Self.requestBodies.append(String(decoding: body, as: UTF8.self))
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
            Self.requestBodies.append(String(decoding: data as Data, as: UTF8.self))
        }
        let response = Self.responses.isEmpty
            ? (statusCode: 200, body: "{}")
            : Self.responses.removeFirst()
        let httpResponse = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
