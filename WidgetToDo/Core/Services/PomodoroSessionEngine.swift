import Foundation

/// 纯计时状态机：负责 start / advance / pause / resume / abandon 与活跃时长换算。
///
/// 设计约束：
/// - 不持有任何 AppKit / SwiftUI / 网络依赖；可被 `swift test` 直接覆盖。
/// - 所有时间推移基于 `Date` 计算，避免每秒盲目自减带来的漂移。
/// - 暂停期不计入活跃秒数；`completedMinutes(at:)` 给出向上取整的累计分钟数，
///   手动结束至少记 1 分钟，自然结束给出整轮时长。
public struct PomodoroSessionEngine: Sendable {
    public private(set) var session: PomodoroSession?

    public init(session: PomodoroSession? = nil) {
        self.session = session
    }

    public mutating func start(task: TaskItem, durationMinutes: Int, at date: Date) {
        guard PomodoroSession.isValidDuration(durationMinutes) else {
            session = nil
            return
        }
        session = PomodoroSession(
            taskID: task.id,
            taskTitle: task.title,
            durationMinutes: durationMinutes,
            phase: .running,
            remainingSeconds: durationMinutes * 60,
            activeElapsedSeconds: 0,
            lastResumedAt: date
        )
    }

    public mutating func advance(to date: Date) -> PomodoroTimerEvent {
        guard let current = session,
              current.phase == .running,
              let resumed = current.lastResumedAt else {
            return .none
        }

        let delta = max(0, Int(date.timeIntervalSince(resumed)))
        let activeDelta = min(delta, current.remainingSeconds)
        let newActive = current.activeElapsedSeconds + activeDelta
        let newRemaining = current.remainingSeconds - activeDelta

        if newRemaining <= 0 {
            session = PomodoroSession(
                taskID: current.taskID,
                taskTitle: current.taskTitle,
                durationMinutes: current.durationMinutes,
                phase: .finished,
                remainingSeconds: 0,
                activeElapsedSeconds: newActive,
                lastResumedAt: nil
            )
            return .finished
        }

        session = PomodoroSession(
            taskID: current.taskID,
            taskTitle: current.taskTitle,
            durationMinutes: current.durationMinutes,
            phase: .running,
            remainingSeconds: newRemaining,
            activeElapsedSeconds: newActive,
            lastResumedAt: date
        )
        return .none
    }

    public mutating func pause(at date: Date) {
        guard let current = session,
              current.phase == .running,
              let resumed = current.lastResumedAt else {
            return
        }

        let delta = max(0, Int(date.timeIntervalSince(resumed)))
        let activeDelta = min(delta, current.remainingSeconds)
        let newActive = current.activeElapsedSeconds + activeDelta
        let newRemaining = current.remainingSeconds - activeDelta

        if newRemaining <= 0 {
            session = PomodoroSession(
                taskID: current.taskID,
                taskTitle: current.taskTitle,
                durationMinutes: current.durationMinutes,
                phase: .finished,
                remainingSeconds: 0,
                activeElapsedSeconds: newActive,
                lastResumedAt: nil
            )
            return
        }

        session = PomodoroSession(
            taskID: current.taskID,
            taskTitle: current.taskTitle,
            durationMinutes: current.durationMinutes,
            phase: .paused,
            remainingSeconds: newRemaining,
            activeElapsedSeconds: newActive,
            lastResumedAt: nil
        )
    }

    public mutating func resume(at date: Date) {
        guard let current = session, current.phase == .paused else {
            return
        }
        session = PomodoroSession(
            taskID: current.taskID,
            taskTitle: current.taskTitle,
            durationMinutes: current.durationMinutes,
            phase: .running,
            remainingSeconds: current.remainingSeconds,
            activeElapsedSeconds: current.activeElapsedSeconds,
            lastResumedAt: date
        )
    }

    public mutating func abandon() {
        session = nil
    }

    /// 当前活跃秒数向上取整为分钟；手动结束至少 1 分钟，无会话返回 0。
    public func completedMinutes(at date: Date) -> Int {
        guard let current = session else { return 0 }

        let activeSeconds: Int
        switch current.phase {
        case .running:
            if let resumed = current.lastResumedAt {
                let delta = max(0, Int(date.timeIntervalSince(resumed)))
                let activeDelta = min(delta, current.remainingSeconds)
                activeSeconds = current.activeElapsedSeconds + activeDelta
            } else {
                activeSeconds = current.activeElapsedSeconds
            }
        case .paused, .finished:
            activeSeconds = current.activeElapsedSeconds
        }

        return max(1, Int((Double(activeSeconds) / 60.0).rounded(.up)))
    }
}
