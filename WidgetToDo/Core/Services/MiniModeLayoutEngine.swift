import CoreGraphics
import Foundation

public enum MiniModeLayoutEngine {
    public static let defaultMiniSize = CGSize(width: 220, height: 56)
    public static let defaultNormalSize = CGSize(width: 340, height: 460)

    /// 以窗口右上角为锚点，计算完整窗口对应的迷你胶囊 frame。
    public static func miniFrame(
        fromNormalFrame normalFrame: CGRect,
        miniSize: CGSize = defaultMiniSize
    ) -> CGRect {
        let topRight = CGPoint(x: normalFrame.maxX, y: normalFrame.maxY)
        return CGRect(
            x: topRight.x - miniSize.width,
            y: topRight.y - miniSize.height,
            width: miniSize.width,
            height: miniSize.height
        )
    }

    /// 以当前胶囊右上角为锚点，恢复完整窗口 frame。
    /// 若未保存过完整 frame，则使用默认尺寸并保持在屏幕可见区域内。
    public static func expandedFrame(
        fromMiniFrame miniFrame: CGRect,
        savedNormalFrame: CodableRect?,
        defaultSize: CGSize = defaultNormalSize,
        visibleFrame: CGRect
    ) -> CGRect {
        let normalSize = savedNormalFrame.map { CGSize(width: $0.width, height: $0.height) } ?? defaultSize
        let topRight = CGPoint(x: miniFrame.maxX, y: miniFrame.maxY)
        var frame = CGRect(
            x: topRight.x - normalSize.width,
            y: topRight.y - normalSize.height,
            width: normalSize.width,
            height: normalSize.height
        )
        frame = frameConstrained(to: visibleFrame, frame: frame)
        return frame
    }

    /// 将窗口 frame 限制在屏幕可见区域内，优先保持完整窗口可见；
    /// 若窗口尺寸超过可见区域，则按左上角对齐。
    public static func frameConstrained(
        to visibleFrame: CGRect,
        frame: CGRect
    ) -> CGRect {
        var origin = frame.origin
        let size = frame.size

        if size.width <= visibleFrame.width {
            if origin.x < visibleFrame.minX {
                origin.x = visibleFrame.minX
            }
            if origin.x + size.width > visibleFrame.maxX {
                origin.x = visibleFrame.maxX - size.width
            }
        } else {
            origin.x = visibleFrame.minX
        }

        if size.height <= visibleFrame.height {
            if origin.y < visibleFrame.minY {
                origin.y = visibleFrame.minY
            }
            if origin.y + size.height > visibleFrame.maxY {
                origin.y = visibleFrame.maxY - size.height
            }
        } else {
            origin.y = visibleFrame.minY
        }

        return CGRect(origin: origin, size: size)
    }

    /// 判断 frame 是否完全在屏幕可见区域内。
    public static func isFrameFullyVisible(
        _ frame: CGRect,
        visibleFrame: CGRect
    ) -> Bool {
        visibleFrame.contains(frame)
    }
}
