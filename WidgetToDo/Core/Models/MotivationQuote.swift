import Foundation

/// 浮窗顶部激励话术的持久化内容：显示开关 + 单行文案。
///
/// 默认关闭：这是新增的可选装饰，不应在用户没主动开启时就占用列表高度。
public struct MotivationQuote: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var text: String

    public init(enabled: Bool = false, text: String = "") {
        self.enabled = enabled
        self.text = text
    }
}
