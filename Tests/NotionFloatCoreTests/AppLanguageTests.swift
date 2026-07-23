import XCTest
@testable import NotionFloatCore

final class AppLanguageTests: XCTestCase {
    func testSupportedLanguagesHaveFixedNamesAndSimplifiedChineseDefault() {
        XCTAssertEqual(AppLanguage.allCases, [.simplifiedChinese, .english, .french])
        XCTAssertEqual(AppLanguage.default, .simplifiedChinese)
        XCTAssertEqual(AppLanguage.allCases.map(\.displayName), ["简体中文", "English", "Français"])
    }

    func testEveryLanguageContainsEveryCatalogKey() {
        let expected = Set(AppText.Key.allCases)

        for language in AppLanguage.allCases {
            XCTAssertEqual(AppText.keys(in: language), expected)
            XCTAssertTrue(expected.allSatisfy { !AppText.string($0, language: language).isEmpty })
            XCTAssertEqual(AppText.string(.languageSettingTitle, language: language), "Language")
        }
    }
}
