import XCTest
@testable import NotionFloatCore

/// `journalEntry(for:)` 的按日查询契约：notion_date 历史数据存在
/// 「本地午夜」（2026-08-10T16:00:00Z，东八区）与「UTC 午夜」（2026-05-22T00:00:00Z）
/// 两种写入格式，按日查询必须两种都能命中（曾因完整时间戳等值匹配导致印记丢失）。
final class JournalCacheDayQueryTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("journal-cache-day-query-\(UUID().uuidString)")
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    private func makeCache() throws -> SQLiteCache {
        try SQLiteCache(baseURL: tempDirectory)
    }

    private func utcMidnight(_ dateString: String) -> Date {
        ISO8601DateFormatter().date(from: "\(dateString)T00:00:00Z")!
    }

    private func entry(id: String, date: Date, content: String) -> JournalEntry {
        JournalEntry(
            id: id,
            title: "日记",
            date: date,
            contentText: content,
            url: nil,
            syncStatus: .synced
        )
    }

    func testQueryFindsUTCMidnightFormatEntry() throws {
        let cache = try makeCache()
        // 历史 UTC 午夜格式（本地 08:00，东八区）：等值匹配查不到，范围匹配必须命中。
        try cache.upsert(entry(id: "j1", date: utcMidnight("2026-05-22"), content: "有内容"))

        let calendar = Calendar(identifier: .gregorian)
        let localDay = calendar.date(
            from: DateComponents(timeZone: .current, year: 2026, month: 5, day: 22)
        )!

        let found = try XCTUnwrap(cache.journalEntry(for: localDay))
        XCTAssertEqual(found.id, "j1")
        XCTAssertEqual(found.contentText, "有内容")
    }

    func testQueryFindsLocalMidnightFormatEntry() throws {
        let cache = try makeCache()
        let calendar = Calendar(identifier: .gregorian)
        let localDay = calendar.date(
            from: DateComponents(timeZone: .current, year: 2026, month: 8, day: 11)
        )!
        // 本地午夜格式（东八区写入 = UTC 前一天 16:00）。
        try cache.upsert(entry(id: "j2", date: localDay, content: "本地午夜"))

        let found = try XCTUnwrap(cache.journalEntry(for: localDay))
        XCTAssertEqual(found.id, "j2")
    }

    func testQueryDoesNotLeakIntoAdjacentDays() throws {
        let cache = try makeCache()
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.date(
            from: DateComponents(timeZone: .current, year: 2026, month: 9, day: 6)
        )!
        try cache.upsert(entry(id: "j3", date: day, content: "当天"))

        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        XCTAssertNil(try cache.journalEntry(for: nextDay))
        let previousDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: day))
        XCTAssertNil(try cache.journalEntry(for: previousDay))
    }

    func testQueryFindsEntryWrittenAsLocalMorningInstant() throws {
        // Notion 返回带时间偏移的日期（ISO8601 fallback 路径）时，entry.date 可能是
        // 当天任意时刻（如 UTC 午夜 = 本地 08:00）；只要落在本地自然日内就必须命中。
        let cache = try makeCache()
        try cache.upsert(entry(id: "j4", date: utcMidnight("2026-09-01"), content: "任意时刻"))

        let calendar = Calendar(identifier: .gregorian)
        let localDay = calendar.date(
            from: DateComponents(timeZone: .current, year: 2026, month: 9, day: 1)
        )!

        let found = try XCTUnwrap(cache.journalEntry(for: localDay))
        XCTAssertEqual(found.id, "j4")
    }
}
