import XCTest
@testable import NotionFloatCore

/// `MutationSyncScheduler` 契约测试：去抖窗口、窗口外再次触发、drain 进行中排队再执行一轮。
final class MutationSyncSchedulerTests: XCTestCase {
    func testDebounceWindowIgnoresRapidRetriggers() async {
        let clock = MutableClock(now: Date(timeIntervalSince1970: 0))
        let counter = DrainCounter()
        let scheduler = MutationSyncScheduler(
            configuration: .init(minTriggerInterval: 5),
            clock: { clock.now },
            drain: { await counter.increment() }
        )

        await scheduler.requestDrain()
        clock.now = clock.now.addingTimeInterval(2)
        await scheduler.requestDrain()

        let count = await counter.count
        XCTAssertEqual(count, 1, "去抖窗口内的重复触发应被忽略")
    }

    func testTriggerAfterDebounceWindowDrainsAgain() async {
        let clock = MutableClock(now: Date(timeIntervalSince1970: 0))
        let counter = DrainCounter()
        let scheduler = MutationSyncScheduler(
            configuration: .init(minTriggerInterval: 5),
            clock: { clock.now },
            drain: { await counter.increment() }
        )

        await scheduler.requestDrain()
        clock.now = clock.now.addingTimeInterval(10)
        await scheduler.requestDrain()

        let count = await counter.count
        XCTAssertEqual(count, 2, "去抖窗口外的触发应再次 drain")
    }

    func testRequestDuringDrainRunsOneMoreRoundAfterCompletion() async {
        let clock = MutableClock(now: Date(timeIntervalSince1970: 0))
        let counter = DrainCounter(holdFirstDrain: true)
        let scheduler = MutationSyncScheduler(
            configuration: .init(minTriggerInterval: 5),
            clock: { clock.now },
            drain: { await counter.increment() }
        )

        let drainTask = Task { await scheduler.requestDrain() }
        // 等第一轮 drain 进入并被挂起。
        await counter.waitUntilCount(1)
        // drain 进行中再次触发：应排队到本轮结束后追加一轮。
        await scheduler.requestDrain()
        await counter.release()
        _ = await drainTask.value

        let count = await counter.count
        XCTAssertEqual(count, 2, "drain 进行中的触发应在完成后追加一轮")
    }
}

private final class MutableClock: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private actor DrainCounter {
    private(set) var count = 0
    private let holdFirstDrain: Bool
    private var gate: CheckedContinuation<Void, Never>?
    private var countChanged: [CheckedContinuation<Void, Never>] = []

    init(holdFirstDrain: Bool = false) {
        self.holdFirstDrain = holdFirstDrain
    }

    func increment() async {
        count += 1
        let waiters = countChanged
        countChanged = []
        waiters.forEach { $0.resume() }
        if holdFirstDrain, count == 1 {
            await withCheckedContinuation { gate = $0 }
        }
    }

    func release() {
        gate?.resume()
        gate = nil
    }

    func waitUntilCount(_ target: Int) async {
        while count < target {
            await withCheckedContinuation { countChanged.append($0) }
        }
    }
}
