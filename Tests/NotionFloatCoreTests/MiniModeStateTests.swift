import XCTest
@testable import NotionFloatCore

final class MiniModeStateTests: XCTestCase {
    func testDefaultState() {
        let state = MiniModeState.default
        XCTAssertFalse(state.isMiniMode)
        XCTAssertEqual(state.activeTab, .todo)
        XCTAssertNil(state.normalFrame)
    }

    func testCodableRoundTrip() throws {
        let state = MiniModeState(
            isMiniMode: true,
            activeTab: .journal,
            normalFrame: CodableRect(x: 100, y: 200, width: 340, height: 460)
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(MiniModeState.self, from: data)
        XCTAssertEqual(decoded, state)
    }

    func testCodableRectFromCGRect() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        let codable = CodableRect(rect)
        XCTAssertEqual(codable.x, 10)
        XCTAssertEqual(codable.y, 20)
        XCTAssertEqual(codable.width, 30)
        XCTAssertEqual(codable.height, 40)
        XCTAssertEqual(codable.cgRect, rect)
    }
}
