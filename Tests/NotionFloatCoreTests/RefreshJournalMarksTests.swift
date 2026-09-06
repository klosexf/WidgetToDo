import XCTest
@testable import NotionFloatCore

/// 月历印记远端刷新的端到端契约（mock Notion API）：
/// 在 Notion 客户端用标题/列表/引用等非 paragraph block 写的日记，
/// 也必须被判定为「有内容」（曾因只提取 paragraph block 导致印记缺失）。
final class RefreshJournalMarksTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("refresh-journal-marks-\(UUID().uuidString)")
        RoutingMockURLProtocol.reset()
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        RoutingMockURLProtocol.reset()
        super.tearDown()
    }

    /// Notion 返回两个日记页：9月6日（标题+列表+引用，全是非 paragraph block）、
    /// 9月7日（只有 divider，无文本）。只有 6 号应该被标记。
    func testNonParagraphBlocksCountAsContent() async throws {
        try await makeHarness(queryBody: twoPagesQueryBody, blocksBodies: [
            "page-1": nonParagraphBlocksBody,
            "page-2": dividerOnlyBlocksBody
        ])

        let repository = try makeRepository()
        let marks = try await repository.refreshJournalMarks(containing: date(2026, 9, 6))

        XCTAssertEqual(marks[6], true, "标题/列表/引用 block 必须算有内容")
        XCTAssertEqual(marks[7], false, "只有 divider 的页面不算有内容")
    }

    /// 远端拉到的正文会写入缓存（contentText 含非 paragraph 文本），
    /// 但缓存已有条目不被覆盖。
    func testRefreshBackfillsCacheWithoutOverwriting() async throws {
        try await makeHarness(queryBody: twoPagesQueryBody, blocksBodies: [
            "page-1": nonParagraphBlocksBody,
            "page-2": dividerOnlyBlocksBody
        ])

        let cache = try SQLiteCache(baseURL: tempDirectory)
        // page-1 已有缓存（含本地未保存编辑语义），远端刷新不得覆盖。
        try cache.upsert(
            JournalEntry(
                id: "page-1",
                title: "日记",
                date: date(2026, 9, 6),
                contentText: "本地内容",
                url: nil,
                syncStatus: .localPending
            )
        )

        let repository = try makeRepository()
        _ = try await repository.refreshJournalMarks(containing: date(2026, 9, 6))

        let cachedPage1 = try XCTUnwrap(cache.journalEntry(id: "page-1"))
        XCTAssertEqual(cachedPage1.contentText, "本地内容", "已有条目不被远端刷新覆盖")
        XCTAssertEqual(cachedPage1.syncStatus, .localPending)

        let cachedPage2 = try XCTUnwrap(cache.journalEntry(id: "page-2"))
        XCTAssertEqual(cachedPage2.contentText, "", "divider-only 页面正文为空")
        XCTAssertEqual(cachedPage2.syncStatus, .synced)
    }

    // MARK: - Fixtures

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func makeRepository() throws -> NotionRepository {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RoutingMockURLProtocol.self]
        return NotionRepository(
            tokenStore: InMemoryTokenStore(),
            settingsStore: settingsStore,
            cache: try SQLiteCache(baseURL: tempDirectory),
            notionClient: NotionClient(session: URLSession(configuration: config))
        )
    }

    private lazy var settingsStore: SettingsStore = {
        let store = try! SettingsStore(baseURL: tempDirectory)
        let saved = store
        Task {
            try? await saved.save(
                AppSettings(
                    tasksDatabaseID: "tasks-db",
                    journalDatabaseID: "journal-db",
                    lastValidatedAt: Date(),
                    hasPriorityField: false,
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
        }
        return store
    }()

    private func makeHarness(queryBody: String, blocksBodies: [String: String]) async throws {
        RoutingMockURLProtocol.routeHandler = { url in
            if url.path.contains("/databases/journal-db/query") {
                return (200, queryBody)
            }
            for (pageID, body) in blocksBodies where url.path.contains("/blocks/\(pageID)/children") {
                return (200, body)
            }
            return (404, "{}")
        }
        // settingsStore 是 lazy 属性，首次访问触发保存 Task；等它落盘。
        _ = settingsStore
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    private var twoPagesQueryBody: String {
        """
        {
          "results": [
            {
              "id": "page-1",
              "url": "https://www.notion.so/page-1",
              "properties": {
                "日记标题": { "title": [{ "plain_text": "日记 2026年9月6日" }] },
                "记录日期": { "date": { "start": "2026-09-06" } }
              }
            },
            {
              "id": "page-2",
              "url": "https://www.notion.so/page-2",
              "properties": {
                "日记标题": { "title": [{ "plain_text": "日记 2026年9月7日" }] },
                "记录日期": { "date": { "start": "2026-09-07" } }
              }
            }
          ]
        }
        """
    }

    /// 全部是非 paragraph 的文本 block：heading_2、bulleted_list_item、quote。
    private var nonParagraphBlocksBody: String {
        """
        {
          "results": [
            {
              "id": "b1",
              "type": "heading_2",
              "heading_2": { "rich_text": [{ "plain_text": "周末计划" }] }
            },
            {
              "id": "b2",
              "type": "bulleted_list_item",
              "bulleted_list_item": { "rich_text": [{ "plain_text": "读一本书" }] }
            },
            {
              "id": "b3",
              "type": "quote",
              "quote": { "rich_text": [{ "plain_text": "今日金句" }] }
            }
          ]
        }
        """
    }

    /// 只有 divider（无 rich_text）的页面。
    private var dividerOnlyBlocksBody: String {
        """
        {
          "results": [
            { "id": "b4", "type": "divider", "divider": {} }
          ]
        }
        """
    }
}

/// 按 URL 路由的 mock：query 与 blocks 请求返回不同响应。
private final class RoutingMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var routeHandler: ((URL) -> (Int, String))?

    static func reset() {
        routeHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.routeHandler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let (status, body) = handler(url)
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    func save(token: String) throws {}
    func loadToken() throws -> String? { "test-token" }
    func deleteToken() {}
}
