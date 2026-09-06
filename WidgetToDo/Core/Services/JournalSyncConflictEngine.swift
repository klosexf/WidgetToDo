import Foundation

/// 日记同步与本地编辑冲突的决策输入。
/// 全部为值类型快照，保证决策可被 `swift test` 独立覆盖。
public struct JournalSyncContext: Equatable, Sendable {
    /// 编辑器当前文本（可能包含尚未写入 Notion 的内容）。
    public let localText: String
    /// 刚从 Notion 拉取到的远端文本。
    public let remoteText: String
    /// 是否存在未确认写入 Notion 的本地编辑（防抖中 / 保存中 / 保存失败 / 与已同步文本不一致）。
    public let hasUnsavedEdits: Bool
    /// 最近一次保存是否失败（失败意味着本地文本尚未到达云端）。
    public let lastSaveFailed: Bool

    public init(
        localText: String,
        remoteText: String,
        hasUnsavedEdits: Bool,
        lastSaveFailed: Bool
    ) {
        self.localText = localText
        self.remoteText = remoteText
        self.hasUnsavedEdits = hasUnsavedEdits
        self.lastSaveFailed = lastSaveFailed
    }
}

/// 日记同步对编辑器内容的处置决策。
public enum JournalSyncResolution: Equatable, Sendable {
    /// 本地没有未保存编辑：直接用远端内容覆盖编辑器（常规刷新）。
    case applyRemote
    /// 本地有编辑但保存链路健康（已写入或即将写入云端）：保留编辑器内容，仅更新元数据与提示。
    case keepLocal
    /// 本地编辑保存失败且云端内容已分叉：真实冲突，交由用户选择保留本地 / 使用云端 / 合并。
    case conflict
}

/// 日记同步冲突决策引擎（纯计算，无副作用）。
public enum JournalSyncConflictEngine {
    public static func resolve(context: JournalSyncContext) -> JournalSyncResolution {
        // 本地无未落盘编辑：刷新是安全的，直接展示远端最新内容。
        if !context.hasUnsavedEdits {
            return .applyRemote
        }
        // 本地编辑没有成功写入云端（离线、弱网、写入失败），而云端内容与本地不同：
        // 两个版本都已实际存在，不能静默取舍，必须让用户决定。
        if context.lastSaveFailed && context.remoteText != context.localText {
            return .conflict
        }
        // 本地编辑仍在防抖/保存管道中，或云端内容与本地一致：
        // 保留编辑器内容，避免打断输入；后续自动保存会推进同步状态。
        return .keepLocal
    }
}
