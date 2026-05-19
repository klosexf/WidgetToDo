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
        let slots = [
            WindowSnapLayoutEngine.Slot(
                offset: CGPoint(x: 0, y: 0),
                panelFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
                isValid: true
            ),
            WindowSnapLayoutEngine.Slot(
                offset: CGPoint(x: 1, y: 0),
                panelFrame: CGRect(x: 200, y: 0, width: 300, height: 300),
                isValid: true
            )
        ]

        let draggedFrame = CGRect(x: 120, y: 0, width: 100, height: 100)
        let selection = WindowSnapLayoutEngine.selectNearestSlot(
            for: draggedFrame,
            from: slots,
            configuration: config
        )

        XCTAssertEqual(selection.slot?.offset, CGPoint(x: 0, y: 0))
        XCTAssertTrue(selection.isWithinSoftRadius)
        XCTAssertTrue(selection.isWithinHardRadius)
    }

    func testNearestSlotReportsOutOfHardSnapRadius() {
        let slots = [
            WindowSnapLayoutEngine.Slot(
                offset: CGPoint(x: 0, y: 0),
                panelFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
                isValid: true
            ),
            WindowSnapLayoutEngine.Slot(
                offset: CGPoint(x: 1, y: 0),
                panelFrame: CGRect(x: 200, y: 0, width: 300, height: 300),
                isValid: true
            )
        ]

        let draggedFrame = CGRect(x: 1_000, y: 1_000, width: 100, height: 100)
        let selection = WindowSnapLayoutEngine.selectNearestSlot(
            for: draggedFrame,
            from: slots,
            configuration: config
        )

        XCTAssertFalse(selection.isWithinSoftRadius)
        XCTAssertFalse(selection.isWithinHardRadius)
    }

    func testNearestSlotIgnoresInvalidCandidatesAndReportsNoValidSlot() {
        let slots = [
            WindowSnapLayoutEngine.Slot(
                offset: CGPoint(x: 0, y: 0),
                panelFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
                isValid: false
            ),
            WindowSnapLayoutEngine.Slot(
                offset: CGPoint(x: 1, y: 0),
                panelFrame: CGRect(x: 200, y: 0, width: 300, height: 300),
                isValid: false
            )
        ]

        let draggedFrame = CGRect(x: 120, y: 0, width: 100, height: 100)
        let selection = WindowSnapLayoutEngine.selectNearestSlot(
            for: draggedFrame,
            from: slots,
            configuration: config
        )

        XCTAssertNil(selection.slot)
        XCTAssertFalse(selection.isWithinSoftRadius)
        XCTAssertFalse(selection.isWithinHardRadius)
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
