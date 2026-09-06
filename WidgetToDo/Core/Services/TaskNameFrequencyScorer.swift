import Foundation

/// 单个任务名的使用统计：累计成功创建次数 + 最近一次使用时间 + 最近一次选择的类型。
public struct TaskNameUsage: Codable, Equatable, Sendable {
    public var count: Int
    public var lastUsedAt: Date
    /// 最近一次创建该任务名时选择的类型（能力维度 choice 值），未选过为 nil。
    public var lastPriority: String?

    public init(count: Int, lastUsedAt: Date, lastPriority: String? = nil) {
        self.count = count
        self.lastUsedAt = lastUsedAt
        self.lastPriority = lastPriority
    }
}

/// 高频任务名条目：任务名 + 最近一次使用的类型，供快捷标签行一键还原。
public struct FrequentTaskName: Equatable, Sendable {
    public let name: String
    public let priority: String?

    public init(name: String, priority: String?) {
        self.name = name
        self.priority = priority
    }
}

/// 高频任务名评分：纯计算，无副作用。
///
/// 评分公式：`score = count × 0.5^(距上次使用天数 / 半衰期天数)`。
/// 默认半衰期 7 天——最近 7 天内用过的满权重，每过一周权重减半；
/// 老任务名不再永久霸榜，新习惯用几次即可进入推荐。
public enum TaskNameFrequencyScorer {
    public static let defaultHalfLifeDays: Double = 7

    /// 计算单个任务名的当前评分。
    public static func score(
        count: Int,
        lastUsedAt: Date,
        now: Date,
        halfLifeDays: Double = defaultHalfLifeDays
    ) -> Double {
        let effectiveHalfLife = max(halfLifeDays, 1)
        let days = max(0, now.timeIntervalSince(lastUsedAt) / 86_400)
        return Double(max(count, 0)) * pow(0.5, days / effectiveHalfLife)
    }

    /// 按评分降序返回前 `limit` 个任务名。
    ///
    /// 排序规则（确定性）：
    /// 1. 评分降序；
    /// 2. 评分相同 → 最近使用在前；
    /// 3. 仍相同 → 任务名字典序，保证结果稳定。
    public static func topNames(
        entries: [String: TaskNameUsage],
        limit: Int,
        now: Date,
        halfLifeDays: Double = defaultHalfLifeDays
    ) -> [String] {
        guard limit > 0, !entries.isEmpty else { return [] }

        return entries
            .sorted { lhs, rhs in
                let lhsScore = score(count: lhs.value.count, lastUsedAt: lhs.value.lastUsedAt, now: now, halfLifeDays: halfLifeDays)
                let rhsScore = score(count: rhs.value.count, lastUsedAt: rhs.value.lastUsedAt, now: now, halfLifeDays: halfLifeDays)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                if lhs.value.lastUsedAt != rhs.value.lastUsedAt {
                    return lhs.value.lastUsedAt > rhs.value.lastUsedAt
                }
                return lhs.key < rhs.key
            }
            .prefix(limit)
            .map(\.key)
    }

    /// 按评分降序返回前 `limit` 个任务名条目（含最近一次使用的类型）。
    public static func topEntries(
        entries: [String: TaskNameUsage],
        limit: Int,
        now: Date,
        halfLifeDays: Double = defaultHalfLifeDays
    ) -> [FrequentTaskName] {
        topNames(entries: entries, limit: limit, now: now, halfLifeDays: halfLifeDays)
            .map { name in
                FrequentTaskName(name: name, priority: entries[name]?.lastPriority)
            }
    }
}
