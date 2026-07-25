import XCTest
@testable import NotionFloatCore

final class ConfigurationInputNormalizerTests: XCTestCase {
    func testNormalizeDatabaseInputExtractsCanonicalIDFromNotionURL() {
        let normalized = ConfigurationInputNormalizer.normalizeDatabaseInput(
            "https://www.notion.so/workspace/My-Tasks-123456781234123412341234567890AB?v=abcdef"
        )

        XCTAssertEqual(normalized, "12345678-1234-1234-1234-1234567890ab")
    }

    func testNormalizeDatabaseInputPreservesCanonicalUUID() {
        let normalized = ConfigurationInputNormalizer.normalizeDatabaseInput(
            "12345678-1234-1234-1234-1234567890AB"
        )

        XCTAssertEqual(normalized, "12345678-1234-1234-1234-1234567890ab")
    }

    func testNormalizeDatabaseInputReturnsNilForInvalidInput() {
        XCTAssertNil(ConfigurationInputNormalizer.normalizeDatabaseInput(""))
        XCTAssertNil(ConfigurationInputNormalizer.normalizeDatabaseInput("https://www.notion.so/not-a-database"))
    }

    func testValidateReportsLanguageIndependentMessageKeysForMissingAndInvalidFields() {
        let issues = ConfigurationInputNormalizer.validate(
            token: " ",
            tasksInput: "invalid-tasks",
            journalInput: "invalid-journal"
        )

        XCTAssertEqual(
            issues.map(\.message.key),
            [
                .missingToken,
                .invalidTasksDatabaseInput,
                .invalidJournalDatabaseInput
            ]
        )
    }
}
