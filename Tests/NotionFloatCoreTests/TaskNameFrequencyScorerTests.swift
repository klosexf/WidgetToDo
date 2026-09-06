import XCTest
@testable import NotionFloatCore

final class TaskNameFrequencyScorerTests: XCTestCase {
    private func daysAgo(_ days: Double, from now: Date) -> Date {
        now.addingTimeInterval(-days * 86_400)
    }

    // MARK: - score

    func testRecentUsageKeepsNearFullWeight() {
        let now = Date()
        let halfDayOld = TaskNameFrequencyScorer.score(
            count: 8,
            lastUsedAt: daysAgo(0.5, from: now),
            now: now
        )
        // 8 × 0.5^(0.5/7) ≈ 7.61，视为接近满权重
        XCTAssertEqual(halfDayOld, 8 * pow(0.5, 0.5 / 7), accuracy: 0.0001)
    }

    func testScoreHalvesPerHalfLife() {
        let now = Date()
        let sevenDays = TaskNameFrequencyScorer.score(
            count: 8,
            lastUsedAt: daysAgo(7, from: now),
            now: now
        )
        XCTAssertEqual(sevenDays, 4, accuracy: 0.0001)

        let fourteenDays = TaskNameFrequencyScorer.score(
            count: 8,
            lastUsedAt: daysAgo(14, from: now),
            now: now
        )
        XCTAssertEqual(fourteenDays, 2, accuracy: 0.0001)
    }

    func testFutureLastUsedAtIsClampedToFullWeight() {
        let now = Date()
        let score = TaskNameFrequencyScorer.score(
            count: 3,
            lastUsedAt: now.addingTimeInterval(3_600),
            now: now
        )
        XCTAssertEqual(score, 3, accuracy: 0.0001)
    }

    func testZeroCountScoresZero() {
        let now = Date()
        let score = TaskNameFrequencyScorer.score(
            count: 0,
            lastUsedAt: now,
            now: now
        )
        XCTAssertEqual(score, 0, accuracy: 0.0001)
    }

    // MARK: - topNames

    func testRecentLowerCountBeatsStaleHigherCount() {
        let now = Date()
        let entries = [
            "新习惯": TaskNameUsage(count: 3, lastUsedAt: daysAgo(1, from: now)),
            "老任务": TaskNameUsage(count: 10, lastUsedAt: daysAgo(35, from: now)),
        ]
        // 老任务 10 × 0.5^5 ≈ 0.31 < 新习惯 3 × 0.5^(1/7) ≈ 2.72
        let top = TaskNameFrequencyScorer.topNames(entries: entries, limit: 2, now: now)
        XCTAssertEqual(top, ["新习惯", "老任务"])
    }

    func testLimitTruncatesResults() {
        let now = Date()
        let entries = (1...6).reduce(into: [String: TaskNameUsage]()) { result, index in
            result["任务\(index)"] = TaskNameUsage(count: index, lastUsedAt: now)
        }
        let top = TaskNameFrequencyScorer.topNames(entries: entries, limit: 5, now: now)
        XCTAssertEqual(top.count, 5)
        XCTAssertEqual(top.first, "任务6")
        XCTAssertFalse(top.contains("任务1"))
    }

    func testEqualScoresPreferRecentThenNameOrder() {
        let now = Date()
        let entries = [
            "乙任务": TaskNameUsage(count: 2, lastUsedAt: daysAgo(1, from: now)),
            "甲任务": TaskNameUsage(count: 2, lastUsedAt: daysAgo(2, from: now)),
            "丙任务": TaskNameUsage(count: 2, lastUsedAt: daysAgo(1, from: now)),
        ]
        let top = TaskNameFrequencyScorer.topNames(entries: entries, limit: 3, now: now)
        // 乙/丙 同评分同时间 → 字典序；甲时间更早排最后
        XCTAssertEqual(top, ["丙任务", "乙任务", "甲任务"])
    }

    func testEmptyEntriesAndNonPositiveLimitReturnEmpty() {
        let now = Date()
        XCTAssertTrue(TaskNameFrequencyScorer.topNames(entries: [:], limit: 5, now: now).isEmpty)
        let entries = ["任务": TaskNameUsage(count: 1, lastUsedAt: now)]
        XCTAssertTrue(TaskNameFrequencyScorer.topNames(entries: entries, limit: 0, now: now).isEmpty)
    }

    func testTopEntriesCarryLastPriority() {
        let now = Date()
        let entries = [
            "背单词": TaskNameUsage(count: 5, lastUsedAt: now, lastPriority: "学习"),
            "冥想": TaskNameUsage(count: 2, lastUsedAt: now, lastPriority: nil),
        ]
        let top = TaskNameFrequencyScorer.topEntries(entries: entries, limit: 2, now: now)
        XCTAssertEqual(top.map(\.name), ["背单词", "冥想"])
        XCTAssertEqual(top[0].priority, "学习")
        XCTAssertNil(top[1].priority)
    }
}
