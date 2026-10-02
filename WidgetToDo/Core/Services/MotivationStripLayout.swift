import CoreGraphics
import Foundation

/// 激励话术单行条的纯计算：文案归一化、可用宽度、溢出判定、滚动时长。
///
/// 视图层只负责把结果画出来，判定逻辑全部留在这里，便于 `swift test` 覆盖。
public enum MotivationStripLayout {
    /// 跑马灯双副本之间的接缝宽度。
    public static let gap: CGFloat = 36

    /// 横向滚动速度，单位 px/秒。
    /// 45 是用户选定值：154 字（约 1950px）一轮约 44s。退回 26 会让一轮变成 76s。
    public static let pointsPerSecond: CGFloat = 45

    /// 把任意输入压成单行：换行与连续空白折叠为单个空格，并去掉首尾空白。
    public static func normalizedQuote(_ raw: String) -> String {
        raw.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// 可用宽度必须由容器反算，不能读文字元素自身宽度：
    /// 静止态下文字容器会收成文字宽度，用它判定会让任意短句都被误判成需要滚动。
    public static func availableWidth(
        containerWidth: CGFloat,
        horizontalPadding: CGFloat,
        trailingAllowance: CGFloat
    ) -> CGFloat {
        max(0, containerWidth - horizontalPadding * 2 - trailingAllowance)
    }

    /// 只有真正放不下时才滚动；空文案与刚好占满的情况都保持静止。
    public static func shouldScroll(textWidth: CGFloat, availableWidth: CGFloat, gap: CGFloat) -> Bool {
        textWidth > 0 && textWidth + gap > availableWidth
    }

    /// 一圈的时长，保证位移速度恒定为 `pointsPerSecond`。
    public static func scrollDuration(
        textWidth: CGFloat,
        gap: CGFloat,
        pointsPerSecond: CGFloat = MotivationStripLayout.pointsPerSecond
    ) -> Double {
        guard pointsPerSecond > 0 else { return 0 }
        return Double((textWidth + gap) / pointsPerSecond)
    }
}
