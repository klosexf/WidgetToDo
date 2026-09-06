import XCTest
@testable import NotionFloatCore

final class TaskNameFrequencyStoreTests: XCTestCase {
    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TaskNameFrequencyStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testRecordTrimsAndMergesSameName() async {
        let directory = try! makeTempDirectory()
        let now = Date()
        let store = TaskNameFrequencyStore(baseURL: directory)

        await store.record(name: "  背单词  ", priority: nil, now: now)
        await store.record(name: "背单词", priority: "学习", now: now.addingTimeInterval(60))
        await store.record(name: "阅读", priority: nil, now: now)

        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.count, 2)
        XCTAssertEqual(snapshot["背单词"]?.count, 2)
        XCTAssertEqual(snapshot["背单词"]?.lastUsedAt, now.addingTimeInterval(60))
        XCTAssertEqual(snapshot["背单词"]?.lastPriority, "学习")
    }

    func testRecordIgnoresBlankName() async {
        let directory = try! makeTempDirectory()
        let store = TaskNameFrequencyStore(baseURL: directory)

        await store.record(name: "   ", priority: "学习", now: Date())
        let snapshot = await store.snapshot()
        XCTAssertTrue(snapshot.isEmpty)
    }

    func testRecordOverwritesPriorityWithLatestUsage() async {
        let directory = try! makeTempDirectory()
        let now = Date()
        let store = TaskNameFrequencyStore(baseURL: directory)

        await store.record(name: "练习表达", priority: "表达", now: now)
        await store.record(name: "练习表达", priority: "沟通", now: now.addingTimeInterval(60))

        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot["练习表达"]?.count, 2)
        XCTAssertEqual(snapshot["练习表达"]?.lastPriority, "沟通")
    }

    func testTopEntriesCarryPriority() async {
        let directory = try! makeTempDirectory()
        let now = Date()
        let store = TaskNameFrequencyStore(baseURL: directory)

        await store.record(name: "背单词", priority: "学习", now: now)
        await store.record(name: "阅读", priority: nil, now: now)

        let top = await store.topEntries(limit: 5, now: now)
        XCTAssertEqual(top.count, 2)
        let byName = Dictionary(uniqueKeysWithValues: top.map { ($0.name, $0.priority) })
        XCTAssertEqual(byName["背单词"], .some("学习"))
        XCTAssertEqual(byName["阅读"], .some(nil))
    }

    func testTopEntriesOrdersByDecayScore() async {
        let directory = try! makeTempDirectory()
        let now = Date()
        let store = TaskNameFrequencyStore(baseURL: directory)

        await store.record(name: "老任务", priority: nil, now: now.addingTimeInterval(-30 * 86_400))
        await store.record(name: "老任务", priority: nil, now: now.addingTimeInterval(-30 * 86_400))
        await store.record(name: "新习惯", priority: "健康", now: now.addingTimeInterval(-86_400))

        let top = await store.topEntries(limit: 5, now: now)
        XCTAssertEqual(top.map(\.name), ["新习惯", "老任务"])
        XCTAssertEqual(top.first?.priority, "健康")
    }

    func testTopEntriesRespectsLimit() async {
        let directory = try! makeTempDirectory()
        let now = Date()
        let store = TaskNameFrequencyStore(baseURL: directory)

        for index in 1...6 {
            await store.record(name: "任务\(index)", priority: nil, now: now.addingTimeInterval(Double(-index) * 60))
        }

        let top = await store.topEntries(limit: 3, now: now)
        XCTAssertEqual(top.count, 3)
        XCTAssertEqual(top.first?.name, "任务1")
    }

    func testEntriesPersistAcrossStoreInstances() async {
        let directory = try! makeTempDirectory()
        let now = Date()
        let first = TaskNameFrequencyStore(baseURL: directory)
        await first.record(name: "练习表达", priority: "表达", now: now)
        await first.record(name: "练习表达", priority: "表达", now: now.addingTimeInterval(60))

        let second = TaskNameFrequencyStore(baseURL: directory)
        let snapshot = await second.snapshot()
        XCTAssertEqual(snapshot["练习表达"]?.count, 2)
        XCTAssertEqual(snapshot["练习表达"]?.lastPriority, "表达")
    }

    func testLegacyJSONWithoutPriorityKeyDecodesWithNilPriority() async throws {
        let directory = try makeTempDirectory()
        // 旧版本格式：无 lastPriority 字段
        let legacyJSON = """
        {"背单词": {"count": 3, "lastUsedAt": "2026-09-01T00:00:00Z"}}
        """
        try Data(legacyJSON.utf8).write(to: directory.appendingPathComponent("task-name-frequency.json"))

        let store = TaskNameFrequencyStore(baseURL: directory)
        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot["背单词"]?.count, 3)
        XCTAssertNil(snapshot["背单词"]?.lastPriority)

        let top = await store.topEntries(limit: 5, now: Date())
        XCTAssertEqual(top.first?.name, "背单词")
        XCTAssertNil(top.first?.priority)
    }

    func testCorruptFileDegradesToEmpty() async throws {
        let directory = try makeTempDirectory()
        let corruptURL = directory.appendingPathComponent("task-name-frequency.json")
        try Data("not valid json".utf8).write(to: corruptURL)

        let store = TaskNameFrequencyStore(baseURL: directory)
        let snapshot = await store.snapshot()
        XCTAssertTrue(snapshot.isEmpty)

        // 覆盖写入后恢复正常
        await store.record(name: "恢复任务", priority: nil, now: Date())
        let third = TaskNameFrequencyStore(baseURL: directory)
        let restored = await third.snapshot()
        XCTAssertEqual(restored["恢复任务"]?.count, 1)
    }

    func testMissingDirectoryIsCreatedOnPersist() async {
        let directory = try! makeTempDirectory()
        let nested = directory.appendingPathComponent("nested", isDirectory: true)
        let store = TaskNameFrequencyStore(baseURL: nested)

        await store.record(name: "深目录任务", priority: nil, now: Date())

        let reloaded = TaskNameFrequencyStore(baseURL: nested)
        let snapshot = await reloaded.snapshot()
        XCTAssertEqual(snapshot["深目录任务"]?.count, 1)
    }
}
