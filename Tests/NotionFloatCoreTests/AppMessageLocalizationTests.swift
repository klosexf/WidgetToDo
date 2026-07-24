import XCTest
@testable import NotionFloatCore

final class AppMessageLocalizationTests: XCTestCase {
    func testDeferredMessageRendersUsingTheCurrentLanguage() {
        let message = AppMessage(.taskSyncFailed, arguments: ["offline"])

        XCTAssertEqual(message.string(in: .simplifiedChinese), "任务同步失败：offline")
        XCTAssertEqual(message.string(in: .english), "Task sync failed: offline")
        XCTAssertEqual(message.string(in: .french), "Échec de la synchronisation des tâches : offline")
    }

    func testHelpAndTabLabelsRenderInTheSelectedLanguage() {
        XCTAssertEqual(AppText.string(.tasksDatabaseHelpTitle, language: .simplifiedChinese), "获取 Tasks Database 链接")
        XCTAssertEqual(AppText.string(.tasksDatabaseHelpTitle, language: .english), "Get a Tasks Database link")
        XCTAssertEqual(AppText.string(.tasksDatabaseHelpTitle, language: .french), "Obtenir un lien Tasks Database")

        XCTAssertEqual(AppText.string(.todoTab, language: .simplifiedChinese), "待办")
        XCTAssertEqual(AppText.string(.todoTab, language: .english), "Tasks")
        XCTAssertEqual(AppText.string(.todoTab, language: .french), "Tâches")
    }
}
