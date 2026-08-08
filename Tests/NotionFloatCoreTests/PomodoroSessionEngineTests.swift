import Foundation
import XCTest
@testable import NotionFloatCore

final class PomodoroSessionEngineTests: XCTestCase {
    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeTask(estimatedMinutes: Int? = 45) -> TaskItem {
        TaskItem(
            id: "task-1",
            title: "写 WidgetToDo PRD",
            isDone: false,
            priority: "High",
            estimatedMinutes: estimatedMinutes,
            date: referenceDate,
            url: nil,
            syncStatus: .synced
        )
    }

    func testStartCreatesRunningSessionWithFullRemainingSeconds() throws {
        var engine = PomodoroSessionEngine()
        engine.start(task: makeTask(), durationMinutes: 45, at: referenceDate)

        let session = try XCTUnwrap(engine.session)
        XCTAssertEqual(session.phase, .running)
        XCTAssertEqual(session.durationMinutes, 45)
        XCTAssertEqual(session.remainingSeconds, 2_700)
        XCTAssertEqual(session.activeElapsedSeconds, 0)
        XCTAssertEqual(session.lastResumedAt, referenceDate)
        XCTAssertEqual(session.taskID, "task-1")
        XCTAssertEqual(session.taskTitle, "写 WidgetToDo PRD")
    }

    func testAdvanceByFullDurationEmitsFinishedOnceAndYieldsActiveSeconds() throws {
        var engine = PomodoroSessionEngine()
        engine.start(task: makeTask(), durationMinutes: 25, at: referenceDate)

        XCTAssertEqual(engine.advance(to: referenceDate.addingTimeInterval(1_500)), .finished)
        let finished = try XCTUnwrap(engine.session)
        XCTAssertEqual(finished.phase, .finished)
        XCTAssertEqual(finished.remainingSeconds, 0)
        XCTAssertEqual(finished.activeElapsedSeconds, 1_500)
        XCTAssertNil(finished.lastResumedAt)

        XCTAssertEqual(engine.advance(to: referenceDate.addingTimeInterval(1_600)), .none)
        let stillFinished = try XCTUnwrap(engine.session)
        XCTAssertEqual(stillFinished.phase, .finished)
        XCTAssertEqual(stillFinished.activeElapsedSeconds, 1_500)
    }

    func testPauseExcludesInactiveIntervalFromActiveDuration() throws {
        var engine = PomodoroSessionEngine()
        engine.start(task: makeTask(), durationMinutes: 25, at: referenceDate)

        XCTAssertEqual(engine.advance(to: referenceDate.addingTimeInterval(70)), .none)
        engine.pause(at: referenceDate.addingTimeInterval(70))

        let paused = try XCTUnwrap(engine.session)
        XCTAssertEqual(paused.phase, .paused)
        XCTAssertEqual(paused.activeElapsedSeconds, 70)
        XCTAssertNil(paused.lastResumedAt)

        // 600 秒暂停期内不应累计任何活跃时间。
        XCTAssertEqual(engine.advance(to: referenceDate.addingTimeInterval(670)), .none)
        XCTAssertEqual(engine.session?.activeElapsedSeconds, 70)

        engine.resume(at: referenceDate.addingTimeInterval(670))
        XCTAssertEqual(engine.session?.phase, .running)
        XCTAssertEqual(engine.session?.lastResumedAt, referenceDate.addingTimeInterval(670))

        XCTAssertEqual(engine.advance(to: referenceDate.addingTimeInterval(700)), .none)
        XCTAssertEqual(engine.session?.activeElapsedSeconds, 100)
        XCTAssertEqual(engine.completedMinutes(at: referenceDate.addingTimeInterval(700)), 2)
    }

    func testInvalidDurationsAreRejected() {
        var engine = PomodoroSessionEngine()
        engine.start(task: makeTask(), durationMinutes: 0, at: referenceDate)
        XCTAssertNil(engine.session)

        engine.start(task: makeTask(), durationMinutes: 481, at: referenceDate)
        XCTAssertNil(engine.session)
    }

    func testAbandonClearsSession() throws {
        var engine = PomodoroSessionEngine()
        engine.start(task: makeTask(), durationMinutes: 25, at: referenceDate)
        try XCTUnwrap(engine.session)

        engine.abandon()
        XCTAssertNil(engine.session)
    }

    func testPausedSessionDoesNotAdvance() throws {
        var engine = PomodoroSessionEngine()
        engine.start(task: makeTask(), durationMinutes: 25, at: referenceDate)
        engine.advance(to: referenceDate.addingTimeInterval(30))
        engine.pause(at: referenceDate.addingTimeInterval(30))

        let activeBefore = engine.session?.activeElapsedSeconds
        XCTAssertEqual(engine.advance(to: referenceDate.addingTimeInterval(5_000)), .none)
        XCTAssertEqual(engine.session?.activeElapsedSeconds, activeBefore)
        XCTAssertEqual(engine.session?.phase, .paused)
    }

    func testAdvanceClampsActiveDeltaToRemainingSeconds() throws {
        var engine = PomodoroSessionEngine()
        engine.start(task: makeTask(), durationMinutes: 1, at: referenceDate)

        // 1 分钟会话，前进 600 秒：只应累计 60 秒活跃时间，且进入 finished。
        XCTAssertEqual(engine.advance(to: referenceDate.addingTimeInterval(600)), .finished)
        let finished = try XCTUnwrap(engine.session)
        XCTAssertEqual(finished.activeElapsedSeconds, 60)
        XCTAssertEqual(finished.remainingSeconds, 0)
        XCTAssertEqual(engine.completedMinutes(at: referenceDate.addingTimeInterval(600)), 1)
    }

    func testRoundingPolicyOneSecondRecordsOneMinute() {
        var engine = PomodoroSessionEngine()
        engine.start(task: makeTask(), durationMinutes: 25, at: referenceDate)
        engine.advance(to: referenceDate.addingTimeInterval(1))
        XCTAssertEqual(engine.completedMinutes(at: referenceDate.addingTimeInterval(1)), 1)
    }

    func testRoundingPolicySixtySecondsRecordsOneMinute() {
        var engine = PomodoroSessionEngine()
        engine.start(task: makeTask(), durationMinutes: 25, at: referenceDate)
        engine.advance(to: referenceDate.addingTimeInterval(60))
        XCTAssertEqual(engine.completedMinutes(at: referenceDate.addingTimeInterval(60)), 1)
    }

    func testRoundingPolicySixtyOneSecondsRecordsTwoMinutes() {
        var engine = PomodoroSessionEngine()
        engine.start(task: makeTask(), durationMinutes: 25, at: referenceDate)
        engine.advance(to: referenceDate.addingTimeInterval(61))
        XCTAssertEqual(engine.completedMinutes(at: referenceDate.addingTimeInterval(61)), 2)
    }

    func testCompletedMinutesIsZeroWhenNoSessionExists() {
        let engine = PomodoroSessionEngine()
        XCTAssertEqual(engine.completedMinutes(at: referenceDate), 0)
    }
}
