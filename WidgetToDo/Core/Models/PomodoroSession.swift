import Foundation

public enum PomodoroPhase: Equatable, Sendable {
    case running
    case paused
    case finished
}

public enum PomodoroTimerEvent: Equatable, Sendable {
    case none
    case finished
}

/// 一段进行中的番茄钟会话。仅存在于内存；退出应用即丢弃。
///
/// `时长` 字段在 Notion 中对应 `estimatedMinutes`，本结构不重命名底层映射，
/// 仅承载本轮计时状态：剩余秒数、活跃秒数（不含暂停）、当前阶段。
public struct PomodoroSession: Equatable, Sendable {
    /// 自定义时长的合法区间（1–480 整分钟）。
    public static let validDurationRange = 1...480

    public let taskID: String
    public let taskTitle: String
    public let durationMinutes: Int
    public private(set) var phase: PomodoroPhase
    public private(set) var remainingSeconds: Int
    public private(set) var activeElapsedSeconds: Int
    public private(set) var lastResumedAt: Date?

    public init(
        taskID: String,
        taskTitle: String,
        durationMinutes: Int,
        phase: PomodoroPhase = .running,
        remainingSeconds: Int,
        activeElapsedSeconds: Int = 0,
        lastResumedAt: Date? = nil
    ) {
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.durationMinutes = durationMinutes
        self.phase = phase
        self.remainingSeconds = remainingSeconds
        self.activeElapsedSeconds = activeElapsedSeconds
        self.lastResumedAt = lastResumedAt
    }

    public static func isValidDuration(_ minutes: Int) -> Bool {
        validDurationRange.contains(minutes)
    }
}
