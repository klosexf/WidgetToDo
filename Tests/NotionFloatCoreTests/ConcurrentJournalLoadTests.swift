import XCTest
@testable import NotionFloatCore

/// 同日并发 loadOrCreateJournal 的在途去重回归：
/// 历史 bug——两个并发调用各自走完「查询无页→建页」，Notion 无唯一约束导致同日双页。
/// 修复后并发调用复用同一在途任务，只产生一次建页请求。
final class ConcurrentJournalLoadTests: XCTestCase {
    func testConcurrentLoadOrCreateJournalCreatesOnlyOnePage() async throws {
        let harness = try await makeHarness()

        let date = ISO8601DateFormatter().date(from: "2026-09-06T00:00:00Z")!

        let repository = harness.repository
        async let first = repository.loadOrCreateJournal(for: date)
        async let second = repository.loadOrCreateJournal(for: date)
        let results = try await [first, second]

        // 两个并发调用拿到同一页面 id（在途复用，而非各建一页）。
        XCTAssertEqual(results[0].id, results[1].id)

        let createCount = JournalMockURLProtocol.requests.filter {
            $0.method == "POST" && $0.path.hasSuffix("/pages")
        }.count
        XCTAssertEqual(createCount, 1, "并发加载同一天只应建一页")
    }

    func testSequentialLoadOrCreateJournalReusesExistingPage() async throws {
        let harness = try await makeHarness()
        let date = ISO8601DateFormatter().date(from: "2026-09-06T00:00:00Z")!

        let first = try await harness.repository.loadOrCreateJournal(for: date)
        let second = try await harness.repository.loadOrCreateJournal(for: date)

        XCTAssertEqual(first.id, second.id)
        let createCount = JournalMockURLProtocol.requests.filter {
            $0.method == "POST" && $0.path.hasSuffix("/pages")
        }.count
        XCTAssertEqual(createCount, 1, "在途任务结束后再次加载应命中远端已有页，不再建页")
    }

    func testFindJournalReturnsNilWithoutCreatingPageWhenRemoteEmpty() async throws {
        let harness = try await makeHarness()
        let date = ISO8601DateFormatter().date(from: "2026-09-06T00:00:00Z")!

        let entry = try await harness.repository.findJournal(for: date)

        XCTAssertNil(entry, "远端无页时只查不建，返回 nil")
        let createCount = JournalMockURLProtocol.requests.filter {
            $0.method == "POST" && $0.path.hasSuffix("/pages")
        }.count
        XCTAssertEqual(createCount, 0, "查看日期不得自动建页")
    }

    func testSaveJournalByTextCreatesPageAndWritesContentWhenRemoteEmpty() async throws {
        let harness = try await makeHarness()
        let date = ISO8601DateFormatter().date(from: "2026-09-06T00:00:00Z")!

        let saved = try await harness.repository.saveJournal(text: "今天写了点东西", date: date)

        XCTAssertEqual(saved.id, "page-a")
        XCTAssertEqual(saved.contentText, "今天写了点东西")
        XCTAssertEqual(saved.syncStatus, .synced)
        let createCount = JournalMockURLProtocol.requests.filter {
            $0.method == "POST" && $0.path.hasSuffix("/pages")
        }.count
        XCTAssertEqual(createCount, 1, "首次保存内容时按需建页，且只建一次")
        // 正文已写入：向 page-a 追加了段落 block。
        let appendCount = JournalMockURLProtocol.requests.filter {
            $0.method == "PATCH" && $0.path.hasSuffix("blocks/page-a/children")
        }.count
        XCTAssertEqual(appendCount, 1)
    }

    func testSaveJournalByTextReusesExistingPageWithoutCreatingAnother() async throws {
        let harness = try await makeHarness()
        let date = ISO8601DateFormatter().date(from: "2026-09-06T00:00:00Z")!

        _ = try await harness.repository.saveJournal(text: "第一段", date: date)
        let second = try await harness.repository.saveJournal(text: "第一段\n第二段", date: date)

        XCTAssertEqual(second.id, "page-a", "再次保存命中已有页面")
        let createCount = JournalMockURLProtocol.requests.filter {
            $0.method == "POST" && $0.path.hasSuffix("/pages")
        }.count
        XCTAssertEqual(createCount, 1, "已有页面时不得再建新页")
    }

    // MARK: - Harness

    private func makeHarness() async throws -> JournalLoadHarness {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [JournalMockURLProtocol.self]
        JournalMockURLProtocol.reset()

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
                    priority: nil,
                    priorityOptions: [],
                    estimatedMinutes: nil
                ),
                journalFieldMapping: JournalDatabaseFieldMapping(
                    title: "日记标题",
                    date: "记录日期"
                )
            )
        )
        let tokenStore = InMemoryTokenStore()
        try tokenStore.save(token: "secret_test_token")

        let cache = try SQLiteCache(baseURL: tempDirectoryURL)
        let repository = NotionRepository(
            tokenStore: tokenStore,
            settingsStore: settingsStore,
            cache: cache,
            notionClient: NotionClient(session: URLSession(configuration: config))
        )
        return JournalLoadHarness(repository: repository, cache: cache, tempDirectoryURL: tempDirectoryURL)
    }
}

private final class JournalLoadHarness {
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

/// 按 URL 路径分发响应的 mock：
/// - `databases/journal-db/query`：首次返回空结果（模拟远端无页），之后返回已建页面；
/// - `pages`（POST 建页）：只允许成功一次，返回 page-a；
/// - `blocks/<id>/children`：空正文。
private final class JournalMockURLProtocol: URLProtocol, @unchecked Sendable {
    struct RecordedRequest {
        let method: String
        let path: String
    }

    nonisolated(unsafe) private static var lock = NSLock()
    nonisolated(unsafe) private static var _requests: [RecordedRequest] = []
    nonisolated(unsafe) private static var pageCreated = false

    static var requests: [RecordedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        _requests = []
        pageCreated = false
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? ""

        Self.lock.lock()
        Self._requests.append(RecordedRequest(method: method, path: path))
        let alreadyCreated = Self.pageCreated
        if method == "POST", path.hasSuffix("/pages") {
            Self.pageCreated = true
        }
        Self.lock.unlock()

        let body: String
        if method == "POST", path.hasSuffix("/query") {
            body = alreadyCreated ? Self.queryWithPage : Self.emptyQuery
        } else if method == "POST", path.hasSuffix("/pages") {
            body = Self.createdPage
        } else {
            body = Self.emptyBlocks
        }

        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static let emptyQuery = """
    { "results": [] }
    """

    private static let queryWithPage = """
    {
      "results": [
        {
          "id": "page-a",
          "url": "https://www.notion.so/page-a",
          "properties": {
            "日记标题": { "title": [{ "plain_text": "日记 2026年9月6日" }] },
            "记录日期": { "date": { "start": "2026-09-06" } }
          }
        }
      ]
    }
    """

    private static let createdPage = """
    {
      "id": "page-a",
      "url": "https://www.notion.so/page-a",
      "properties": {
        "日记标题": { "title": [{ "plain_text": "日记 2026年9月6日" }] },
        "记录日期": { "date": { "start": "2026-09-06" } }
      }
    }
    """

    private static let emptyBlocks = """
    { "results": [] }
    """
}
