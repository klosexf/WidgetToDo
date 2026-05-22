import XCTest
@testable import NotionFloatCore

final class TaskDateSelectionTests: XCTestCase {
    func testTodoDateTitleMarksActualToday() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 23, hour: 9)))

        let title = TodoDateDisplayFormatter.title(for: today, today: today, calendar: calendar)

        XCTAssertEqual(title, "今天5月23日")
    }

    func testTodoDateTitleShowsActualValueForYesterdayAndTomorrow() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 23, hour: 9)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today))

        XCTAssertEqual(TodoDateDisplayFormatter.title(for: yesterday, today: today, calendar: calendar), "5月22日")
        XCTAssertEqual(TodoDateDisplayFormatter.title(for: tomorrow, today: today, calendar: calendar), "5月24日")
    }

    func testTodoDateTitleHandlesCrossMonthDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 9)))
        let nextMonth = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today))

        let title = TodoDateDisplayFormatter.title(for: nextMonth, today: today, calendar: calendar)

        XCTAssertEqual(title, "6月1日")
    }

    func testTodoEmptyStateUsesTodayOnlyForActualToday() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 23, hour: 9)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))

        XCTAssertEqual(TodoDateDisplayFormatter.emptyStateTitle(for: today, today: today, calendar: calendar), "今天没有任务")
        XCTAssertEqual(TodoDateDisplayFormatter.emptyStateTitle(for: yesterday, today: today, calendar: calendar), "5月22日 没有任务")
    }

    func testCacheLoadTasksForDateReturnsOnlyMatchingNaturalDay() throws {
        let tempDirectoryURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let cache = try SQLiteCache(baseURL: tempDirectoryURL)
        let calendar = Calendar(identifier: .gregorian)
        let targetDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 21, hour: 0, minute: 0)))
        let sameDayLater = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 21, hour: 18, minute: 30)))
        let nextDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 22, hour: 9, minute: 0)))

        try cache.upsert(makeTask(id: "task-1", title: "当天早些时候", date: targetDate))
        try cache.upsert(makeTask(id: "task-2", title: "当天晚些时候", date: sameDayLater))
        try cache.upsert(makeTask(id: "task-3", title: "次日任务", date: nextDay))

        let loaded = try cache.loadTasks(for: targetDate)

        XCTAssertEqual(loaded.map { $0.id }, ["task-1", "task-2"])
    }

    func testLoadTasksFallsBackToSelectedDateCacheOnlyWhenRemoteQueryFails() async throws {
        let tokenStore = InMemoryTokenStore()
        let tempDirectoryURL = try makeTempDirectory()
        let settingsStore = try SettingsStore(baseURL: tempDirectoryURL)
        try await settingsStore.save(
            AppSettings(
                tasksDatabaseID: "tasks-db",
                journalDatabaseID: "journal-db",
                lastValidatedAt: Date(),
                hasPriorityField: true
            )
        )
        try tokenStore.save(token: "secret_test_token")

        let cache = try SQLiteCache(baseURL: tempDirectoryURL)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let calendar = Calendar(identifier: .gregorian)
        let targetDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 21, hour: 8)))
        let otherDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 22, hour: 8)))

        try cache.upsert(makeTask(id: "task-1", title: "目标日任务", date: targetDate))
        try cache.upsert(makeTask(id: "task-2", title: "其他日任务", date: otherDate))

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.responseStatusCode = 500
        MockURLProtocol.responseBody = Data(#"{"object":"error","status":500,"message":"server error"}"#.utf8)

        let repository = NotionRepository(
            tokenStore: tokenStore,
            settingsStore: settingsStore,
            cache: cache,
            notionClient: NotionClient(session: URLSession(configuration: config))
        )

        let loaded = try await repository.loadTasks(for: targetDate)

        XCTAssertEqual(loaded.map { $0.id }, ["task-1"])
    }

    private func makeTempDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func makeTask(id: String, title: String, date: Date) -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            isDone: false,
            priority: "Medium",
            date: date,
            url: URL(string: "https://www.notion.so/\(id)"),
            syncStatus: .synced
        )
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

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
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
