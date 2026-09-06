import XCTest
@testable import NotionFloatCore

/// 月历印记远端刷新的端到端契约（mock Notion API）：
/// 印记语义为「该日写过内容」——app 切日期时自动创建的空页不算
/// （存在页面 ≠ 写过日记；用户实测确认空页印记是误导）。
/// 同时保证非 paragraph block（标题/列表/引用）的正文被正确提取。
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
        XCTAssertEqual(marks[8], nil, "无页面的日期不标记")
    }

    /// 远端拉到的正文会写入缓存，但缓存已有条目不被覆盖。
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

        let repository = try makeRepository(
            cache: cache
        )
        _ = try await repository.refreshJournalMarks(containing: date(2026, 9, 6))

        let cachedPage1 = try XCTUnwrap(cache.journalEntry(id: "page-1"))
        XCTAssertEqual(cachedPage1.contentText, "本地内容", "已有条目不被远端刷新覆盖")
        XCTAssertEqual(cachedPage1.syncStatus, .localPending)

        let cachedPage2 = try XCTUnwrap(cache.journalEntry(id: "page-2"))
        XCTAssertEqual(cachedPage2.contentText, "", "divider-only 页面正文为空")
        XCTAssertEqual(cachedPage2.syncStatus, .synced)
    }

    /// 回归：同一天存在两个日记页（历史自动建页竞态），一页有正文、一页为空。
    /// API 返回顺序中空页在后——OR 合并下印记必须仍为 true（曾被空页覆盖成 false，
    /// 导致「有日记内容却没有印记」，实测 8月25日全天印记丢失）。
    func testDuplicatePagesSameDayEmptyPageMustNotOverwriteMark() async throws {
        try await makeHarness(
            queryBody: duplicateSameDayQueryBody,
            blocksBodies: [
                "page-a": paragraphBlocksBody,
                "page-b": emptyBlocksBody
            ]
        )

        let repository = try makeRepository()
        let marks = try await repository.refreshJournalMarks(containing: date(2026, 9, 6))

        XCTAssertEqual(marks[6], true, "同日任一页有正文即点亮，空页不得覆盖")
    }

    /// 回归：本地缓存同日双页时，journalEntry(for:) 必须优先返回有正文的
    /// （LIMIT 1 无排序时随机命中，空页会让印记/编辑回退误判「无内容」）。
    func testCacheDuplicatePagesPrefersEntryWithContent() async throws {
        let cache = try SQLiteCache(baseURL: tempDirectory)
        // 先插入有正文的，再插入空页——无排序时多数实现返回先插入的，故反序验证更稳：
        // 无论插入顺序，查询都必须给出有正文的那条。
        try cache.upsert(
            JournalEntry(
                id: "page-a",
                title: "日记",
                date: date(2026, 9, 6),
                contentText: "有正文",
                url: nil,
                syncStatus: .synced
            )
        )
        try cache.upsert(
            JournalEntry(
                id: "page-b",
                title: "日记",
                date: date(2026, 9, 6),
                contentText: "",
                url: nil,
                syncStatus: .synced
            )
        )
        // 也覆盖反序：空页先插、有正文后插。
        try cache.upsert(
            JournalEntry(
                id: "page-c",
                title: "日记",
                date: date(2026, 9, 7),
                contentText: "",
                url: nil,
                syncStatus: .synced
            )
        )
        try cache.upsert(
            JournalEntry(
                id: "page-d",
                title: "日记",
                date: date(2026, 9, 7),
                contentText: "七号正文",
                url: nil,
                syncStatus: .synced
            )
        )

        let sep6 = try XCTUnwrap(cache.journalEntry(for: date(2026, 9, 6)))
        XCTAssertEqual(sep6.id, "page-a", "同日多页时优先返回有正文的（正序插入）")
        let sep7 = try XCTUnwrap(cache.journalEntry(for: date(2026, 9, 7)))
        XCTAssertEqual(sep7.id, "page-d", "同日多页时优先返回有正文的（反序插入）")
    }

    // MARK: - Fixtures

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func makeRepository(cache: SQLiteCache? = nil) throws -> NotionRepository {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RoutingMockURLProtocol.self]
        let resolvedCache = try cache ?? SQLiteCache(baseURL: tempDirectory)
        return NotionRepository(
            tokenStore: InMemoryTokenStore(),
            settingsStore: settingsStore,
            cache: resolvedCache,
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

    /// 同一天（9月6日）两个日记页：page-a 有正文、page-b 为空（模拟历史建页竞态）。
    /// 空页排在有正文页之后——复现覆盖 bug 的 API 顺序。
    private var duplicateSameDayQueryBody: String {
        """
        {
          "results": [
            {
              "id": "page-a",
              "url": "https://www.notion.so/page-a",
              "properties": {
                "日记标题": { "title": [{ "plain_text": "日记 2026年9月6日" }] },
                "记录日期": { "date": { "start": "2026-09-06" } }
              }
            },
            {
              "id": "page-b",
              "url": "https://www.notion.so/page-b",
              "properties": {
                "日记标题": { "title": [{ "plain_text": "日记 2026年9月6日" }] },
                "记录日期": { "date": { "start": "2026-09-06" } }
              }
            }
          ]
        }
        """
    }

    private var paragraphBlocksBody: String {
        """
        {
          "results": [
            {
              "id": "b1",
              "type": "paragraph",
              "paragraph": { "rich_text": [{ "plain_text": "关于新建待办的功能记录" }] }
            }
          ]
        }
        """
    }

    private var emptyBlocksBody: String {
        """
        { "results": [] }
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
