import XCTest
import CoreGraphics
@testable import NotionFloatCore

/// 覆盖 `MotivationStripLayout` 的纯计算：单行归一化、可用宽度、溢出判定、滚动时长。
final class MotivationStripLayoutTests: XCTestCase {

    // MARK: - 单行归一化

    func testNormalizedQuoteCollapsesNewlinesIntoSingleSpaces() {
        let raw = "先把事做完\n再谈完美\r\n今天推出去"
        XCTAssertEqual(MotivationStripLayout.normalizedQuote(raw), "先把事做完 再谈完美 今天推出去")
    }

    func testNormalizedQuoteCollapsesRepeatedSpaces() {
        XCTAssertEqual(MotivationStripLayout.normalizedQuote("先完成   再完美"), "先完成 再完美")
    }

    func testNormalizedQuoteTrimsOuterWhitespace() {
        XCTAssertEqual(MotivationStripLayout.normalizedQuote("  先完成，再完美。 \n"), "先完成，再完美。")
    }

    func testNormalizedQuoteOfBlankInputIsEmpty() {
        XCTAssertEqual(MotivationStripLayout.normalizedQuote("  \n\t "), "")
    }

    // MARK: - 可用宽度

    /// 回归：可用宽度必须由容器反算，不能读文字元素自身宽度——
    /// 静止态下文字容器会收成文字宽度，用它判定会让任意短句都被误判成需要滚动。
    func testAvailableWidthSubtractsPaddingAndTrailingAllowance() {
        let available = MotivationStripLayout.availableWidth(
            containerWidth: 340,
            horizontalPadding: 14,
            trailingAllowance: 40
        )
        XCTAssertEqual(available, 340 - 14 * 2 - 40)
    }

    // MARK: - 溢出判定

    func testShortQuoteDoesNotScroll() {
        XCTAssertFalse(MotivationStripLayout.shouldScroll(
            textWidth: 112,
            availableWidth: 272,
            gap: MotivationStripLayout.gap
        ))
    }

    func testLongQuoteScrolls() {
        XCTAssertTrue(MotivationStripLayout.shouldScroll(
            textWidth: 412,
            availableWidth: 272,
            gap: MotivationStripLayout.gap
        ))
    }

    /// 边界：文字加间距正好等于可用宽度时不滚动，避免刚好占满的句子白滚。
    func testTextExactlyFillingAvailableWidthDoesNotScroll() {
        let available: CGFloat = 272
        let textWidth = available - MotivationStripLayout.gap
        XCTAssertFalse(MotivationStripLayout.shouldScroll(
            textWidth: textWidth,
            availableWidth: available,
            gap: MotivationStripLayout.gap
        ))
    }

    func testEmptyQuoteNeverScrolls() {
        XCTAssertFalse(MotivationStripLayout.shouldScroll(
            textWidth: 0,
            availableWidth: 272,
            gap: MotivationStripLayout.gap
        ))
    }

    // MARK: - 滚动时长

    /// 时长必须让速度恒定在 pointsPerSecond，与文字长短无关。
    func testScrollDurationKeepsSpeedConstant() {
        for textWidth in [CGFloat(120), 412, 800] {
            let duration = MotivationStripLayout.scrollDuration(textWidth: textWidth, gap: MotivationStripLayout.gap)
            let speed = (textWidth + MotivationStripLayout.gap) / CGFloat(duration)
            XCTAssertEqual(speed, MotivationStripLayout.pointsPerSecond, accuracy: 0.01)
        }
    }

    /// 154 个汉字（约 1950px）滚完一轮必须落在可接受的等待时间内。
    /// 上限 45s 对应 45px/s；速度若退回 26px/s 一轮会变成 76s，这条会失败——它锁的是设计意图，不是常量本身。
    func testLongQuoteCompletesLoopWithinFortyFiveSeconds() {
        let duration = MotivationStripLayout.scrollDuration(
            textWidth: 1950,
            gap: MotivationStripLayout.gap
        )
        XCTAssertLessThanOrEqual(duration, 45, "154 字的话术滚完一轮实际耗时 \(duration)s")
    }

    /// 空文案也要给出正数时长，避免动画时长为 0 造成除零或瞬间跳帧。
    func testScrollDurationStaysPositiveForEmptyText() {
        let duration = MotivationStripLayout.scrollDuration(textWidth: 0, gap: MotivationStripLayout.gap)
        XCTAssertGreaterThan(duration, 0)
    }
}
