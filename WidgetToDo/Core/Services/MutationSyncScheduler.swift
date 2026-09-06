import Foundation

/// 待定变更自动重试调度器。
///
/// 把「启动」「网络恢复」等外部触发去抖后串行调用 drain：
/// - 去抖：两次触发间隔小于 `minTriggerInterval` 时忽略，吸收网络状态抖动；
/// - 串行：drain 进行中收到的新触发会在本轮结束后再执行一轮，避免并发重放。
public actor MutationSyncScheduler {
    public struct Configuration: Sendable {
        /// 两次 drain 的最小触发间隔（秒）。
        public var minTriggerInterval: TimeInterval

        public init(minTriggerInterval: TimeInterval = 5) {
            self.minTriggerInterval = minTriggerInterval
        }
    }

    private let configuration: Configuration
    private let clock: @Sendable () -> Date
    private let drain: @Sendable () async -> Void
    private var isDraining = false
    private var hasQueuedTrigger = false
    private var lastDrainStartedAt: Date?

    public init(
        configuration: Configuration = Configuration(),
        clock: @escaping @Sendable () -> Date = { Date() },
        drain: @escaping @Sendable () async -> Void
    ) {
        self.configuration = configuration
        self.clock = clock
        self.drain = drain
    }

    /// 请求执行一次 drain。若当前正在 drain，则在本轮结束后追加一轮。
    public func requestDrain() async {
        if isDraining {
            hasQueuedTrigger = true
            return
        }
        if let lastDrainStartedAt,
           clock().timeIntervalSince(lastDrainStartedAt) < configuration.minTriggerInterval {
            return
        }
        repeat {
            hasQueuedTrigger = false
            lastDrainStartedAt = clock()
            isDraining = true
            await drain()
            isDraining = false
        } while hasQueuedTrigger
    }
}
