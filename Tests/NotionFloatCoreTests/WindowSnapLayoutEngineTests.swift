import XCTest
@testable import NotionFloatCore

final class WindowSnapLayoutEngineTests: XCTestCase {
    private let config = WindowSnapLayoutEngine.Configuration(
        horizontalGap: 32,
        verticalGap: 32,
        softSnapRadius: 90,
        hardSnapRadius: 160,
        reanchorDistance: 120
    )

    func testHorizontalStrideMatchesWindowWidthPlusGap() {
        XCTAssertEqual(config.horizontalStride(for: CGSize(width: 330, height: 560)), 362)
        XCTAssertEqual(config.verticalStride(for: CGSize(width: 330, height: 560)), 592)
    }

    func testGenerateSlotsReturnsNineSlotsInOpenSpace() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1600, height: 1200)
        let panelFrame = CGRect(x: 500, y: 300, width: 330, height: 560)

        let result = WindowSnapLayoutEngine.generateSlots(
            around: panelFrame,
            visibleFrame: visibleFrame,
            configuration: config
        )

        XCTAssertEqual(result.slots.count, 9)
        XCTAssertEqual(result.slots.filter(\.isValid).count, 9)
        XCTAssertEqual(result.anchorOrigin, CGPoint(x: 362, y: 592))
    }

    func testGenerateSlotsFiltersInvalidFramesNearTopRightEdge() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let panelFrame = CGRect(x: 850, y: 280, width: 330, height: 560)

        let result = WindowSnapLayoutEngine.generateSlots(
            around: panelFrame,
            visibleFrame: visibleFrame,
            configuration: config
        )

        XCTAssertLessThan(result.slots.filter(\.isValid).count, 9)
        XCTAssertTrue(result.slots.contains(where: { !$0.isValid }))
        XCTAssertTrue(result.slots.filter(\.isValid).allSatisfy { visibleFrame.contains($0.panelFrame) })
    }

    func testNearestSlotUsesPanelCenterDistance() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1600, height: 1200)
        let panelFrame = CGRect(x: 500, y: 300, width: 330, height: 560)

        let result = WindowSnapLayoutEngine.generateSlots(
            around: panelFrame,
            visibleFrame: visibleFrame,
            configuration: config
        )

        let draggedFrame = CGRect(x: 730, y: 310, width: 330, height: 560)
        let selection = WindowSnapLayoutEngine.selectNearestSlot(
            for: draggedFrame,
            from: result.slots,
            configuration: config
        )

        XCTAssertEqual(selection.slot?.offset, CGPoint(x: 1, y: 0))
        XCTAssertTrue(selection.isWithinHardRadius)
    }

    func testClampPanelOriginKeepsWindowInsideVisibleFrame() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let clamped = WindowSnapLayoutEngine.clampPanelOrigin(
            CGPoint(x: 990, y: 500),
            panelSize: CGSize(width: 330, height: 560),
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(clamped, CGPoint(x: 870, y: 340))
    }
}
