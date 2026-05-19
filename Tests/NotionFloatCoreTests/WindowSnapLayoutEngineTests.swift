import XCTest
@testable import NotionFloatCore

final class WindowSnapLayoutEngineTests: XCTestCase {
    func testHorizontalStrideMatchesWindowWidthPlusGap() {
        let config = WindowSnapLayoutEngine.Configuration(
            horizontalGap: 32,
            verticalGap: 32,
            softSnapRadius: 90,
            hardSnapRadius: 160,
            reanchorDistance: 120
        )

        XCTAssertEqual(config.horizontalStride(for: CGSize(width: 330, height: 560)), 362)
        XCTAssertEqual(config.verticalStride(for: CGSize(width: 330, height: 560)), 592)
    }
}
