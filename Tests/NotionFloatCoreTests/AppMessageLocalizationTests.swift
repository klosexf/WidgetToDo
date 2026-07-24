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

    func testConfigurationAndJournalPromptsRenderInTheSelectedLanguage() {
        XCTAssertEqual(AppText.string(.keychainTokenFound, language: .english), "A token saved in Keychain was found.")
        XCTAssertEqual(AppText.string(.keychainTokenFound, language: .french), "Un jeton enregistré dans le trousseau a été détecté.")
        XCTAssertEqual(AppText.string(.journalReadyToWrite, language: .english), "Start writing")
        XCTAssertEqual(AppText.string(.journalReadyToWrite, language: .french), "Vous pouvez commencer à écrire")
        XCTAssertEqual(AppText.string(.workspaceSynced, language: .english), "Just synced")
        XCTAssertEqual(AppText.string(.workspaceSynced, language: .french), "Synchronisé à l’instant")
    }
}
