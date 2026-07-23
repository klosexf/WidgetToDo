import XCTest
import CoreGraphics
@testable import NotionFloatCore

final class MiniModeLayoutEngineTests: XCTestCase {
    func testMiniFrameAnchorsToTopRight() {
        let normalFrame = CGRect(x: 100, y: 200, width: 340, height: 460)
        let miniFrame = MiniModeLayoutEngine.miniFrame(fromNormalFrame: normalFrame)
        XCTAssertEqual(miniFrame.maxX, normalFrame.maxX)
        XCTAssertEqual(miniFrame.maxY, normalFrame.maxY)
        XCTAssertEqual(miniFrame.size, MiniModeLayoutEngine.defaultMiniSize)
    }

    func testExpandedFrameUsesSavedNormalFrame() {
        let miniFrame = CGRect(x: 500, y: 600, width: 220, height: 56)
        let saved = CodableRect(x: 100, y: 200, width: 340, height: 460)
        let visibleFrame = CGRect(x: 0, y: 0, width: 2000, height: 1200)
        let expanded = MiniModeLayoutEngine.expandedFrame(
            fromMiniFrame: miniFrame,
            savedNormalFrame: saved,
            visibleFrame: visibleFrame
        )
        XCTAssertEqual(expanded.size, CGSize(width: 340, height: 460))
        XCTAssertEqual(expanded.maxX, miniFrame.maxX)
        XCTAssertEqual(expanded.maxY, miniFrame.maxY)
    }

    func testExpandedFrameFallsBackToDefaultSize() {
        let miniFrame = CGRect(x: 500, y: 600, width: 220, height: 56)
        let visibleFrame = CGRect(x: 0, y: 0, width: 2000, height: 1200)
        let expanded = MiniModeLayoutEngine.expandedFrame(
            fromMiniFrame: miniFrame,
            savedNormalFrame: nil,
            visibleFrame: visibleFrame
        )
        XCTAssertEqual(expanded.size, MiniModeLayoutEngine.defaultNormalSize)
    }

    func testFrameConstrainedKeepsFullyVisibleFrame() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let frame = CGRect(x: 100, y: 100, width: 340, height: 460)
        let constrained = MiniModeLayoutEngine.frameConstrained(to: visibleFrame, frame: frame)
        XCTAssertEqual(constrained, frame)
    }

    func testFrameConstrainedPushesRightEdgeInside() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 400, height: 600)
        let frame = CGRect(x: 300, y: 100, width: 340, height: 460)
        let constrained = MiniModeLayoutEngine.frameConstrained(to: visibleFrame, frame: frame)
        XCTAssertLessThanOrEqual(constrained.maxX, visibleFrame.maxX)
    }

    func testFrameConstrainedPushesLeftEdgeInside() {
        let visibleFrame = CGRect(x: 100, y: 0, width: 400, height: 600)
        let frame = CGRect(x: 50, y: 100, width: 340, height: 460)
        let constrained = MiniModeLayoutEngine.frameConstrained(to: visibleFrame, frame: frame)
        XCTAssertGreaterThanOrEqual(constrained.minX, visibleFrame.minX)
    }

    func testIsFrameFullyVisible() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let inside = CGRect(x: 100, y: 100, width: 340, height: 460)
        let outside = CGRect(x: -10, y: 100, width: 340, height: 460)
        XCTAssertTrue(MiniModeLayoutEngine.isFrameFullyVisible(inside, visibleFrame: visibleFrame))
        XCTAssertFalse(MiniModeLayoutEngine.isFrameFullyVisible(outside, visibleFrame: visibleFrame))
    }
}
