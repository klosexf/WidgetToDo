import XCTest
@testable import NotionFloatCore

final class AppLanguagePreferenceTests: XCTestCase {
    func testMissingLanguagePreferenceDefaultsToSimplifiedChinese() async throws {
        let directory = try makeTemporaryDirectory()
        let store = try SettingsStore(baseURL: directory)

        let language = try await store.loadAppLanguage()
        XCTAssertEqual(language, .simplifiedChinese)
    }

    func testLanguagePreferenceRoundTripsEachSupportedValue() async throws {
        let directory = try makeTemporaryDirectory()
        let store = try SettingsStore(baseURL: directory)

        for language in AppLanguage.allCases {
            try await store.saveAppLanguage(language)
            let persistedLanguage = try await store.loadAppLanguage()
            XCTAssertEqual(persistedLanguage, language)
        }
    }

    func testResetConfigurationDoesNotDeleteLanguagePreference() async throws {
        let directory = try makeTemporaryDirectory()
        let tokenStore = TestTokenStore()
        let settingsStore = try SettingsStore(baseURL: directory)
        let repository = NotionRepository(
            tokenStore: tokenStore,
            settingsStore: settingsStore,
            cache: try SQLiteCache(baseURL: directory),
            notionClient: NotionClient()
        )

        try await repository.saveAppLanguage(.french)
        try tokenStore.save(token: "test-token")
        try await repository.resetConfiguration()

        XCTAssertNil(try tokenStore.loadToken())
        let language = try await repository.loadAppLanguage()
        XCTAssertEqual(language, .french)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }
}

private final class TestTokenStore: TokenStore, @unchecked Sendable {
    private var token: String?

    func save(token: String) throws { self.token = token }
    func loadToken() throws -> String? { token }
    func deleteToken() { token = nil }
}
