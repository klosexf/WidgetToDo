import XCTest
@testable import NotionFloatCore

final class AppMessageLocalizationTests: XCTestCase {
    func testDeferredMessageRendersUsingTheCurrentLanguage() {
        let message = AppMessage(.taskSyncFailed, arguments: ["offline"])

        XCTAssertEqual(message.string(in: .simplifiedChinese), "任务同步失败：offline")
        XCTAssertEqual(message.string(in: .english), "Task sync failed: offline")
        XCTAssertEqual(message.string(in: .french), "Échec de la synchronisation des tâches : offline")
    }
}
