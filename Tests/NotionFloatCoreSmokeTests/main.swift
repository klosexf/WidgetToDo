import Foundation
import NotionFloatCore

struct SmokeTestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw SmokeTestFailure(description: message)
    }
}

@main
struct NotionFloatCoreSmokeTestsRunner {
    static func main() throws {
        do {
            try databaseReferenceParsesRawUUID()
            try databaseReferenceParsesDatabaseURL()
            try taskFieldValidationReportsMissingRequiredFields()
            try taskSortingKeepsIncompleteAndHigherPriorityFirst()
            try journalContentBuilderConvertsLinesToParagraphBlocks()
            try notionClientHttpErrorExposesReadableDescription()
            try notionRepositoryValidationErrorExposesReadableDescription()
            print("All smoke tests passed.")
        } catch {
            fputs("Smoke test failed: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }

    static func databaseReferenceParsesRawUUID() throws {
        let parsed = NotionDatabaseReference.parse("12345678-1234-1234-1234-1234567890ab")
        try expect(
            parsed == NotionDatabaseReference(rawValue: "12345678-1234-1234-1234-1234567890ab"),
            "raw UUID parsing should preserve canonical database ID"
        )
    }

    static func databaseReferenceParsesDatabaseURL() throws {
        let parsed = NotionDatabaseReference.parse("https://www.notion.so/My-Tasks-123456781234123412341234567890ab?v=abcdef")
        try expect(
            parsed == NotionDatabaseReference(rawValue: "12345678-1234-1234-1234-1234567890ab"),
            "database URL parsing should extract a canonical UUID"
        )
    }

    static func taskFieldValidationReportsMissingRequiredFields() throws {
        let issues = FieldValidator.validate(
            [
                NotionPropertySchema(name: "Name", type: "title"),
                NotionPropertySchema(name: "Done", type: "checkbox")
            ],
            for: .tasks
        )

        try expect(
            issues.map(\.message) == ["缺少必填字段：Date(date)"],
            "task schema validation should report only the missing required field"
        )
    }

    static func taskSortingKeepsIncompleteAndHigherPriorityFirst() throws {
        let formatter = ISO8601DateFormatter()
        let tasks = [
            TaskItem(
                id: "done-low",
                title: "done low",
                isDone: true,
                priority: "Low",
                date: formatter.date(from: "2026-05-17T12:00:00Z")!,
                url: nil,
                syncStatus: .synced
            ),
            TaskItem(
                id: "todo-medium",
                title: "todo medium",
                isDone: false,
                priority: "Medium",
                date: formatter.date(from: "2026-05-17T09:00:00Z")!,
                url: nil,
                syncStatus: .synced
            ),
            TaskItem(
                id: "todo-high",
                title: "todo high",
                isDone: false,
                priority: "High",
                date: formatter.date(from: "2026-05-17T10:00:00Z")!,
                url: nil,
                syncStatus: .synced
            )
        ]

        try expect(
            TaskSorting.sort(tasks).map(\.id) == ["todo-high", "todo-medium", "done-low"],
            "task sorting should prioritize incomplete tasks, then higher priority, then earlier date"
        )
    }

    static func journalContentBuilderConvertsLinesToParagraphBlocks() throws {
        let payloads = JournalContentBuilder.makeParagraphPayloads(from: "Line 1\n\nLine 3")
        let jsonData = try JSONSerialization.data(withJSONObject: payloads)
        guard let json = String(data: jsonData, encoding: .utf8) else {
            throw SmokeTestFailure(description: "journal payload should be valid UTF-8 JSON")
        }

        try expect(json.contains("\"type\":\"paragraph\""), "journal payload should contain paragraph blocks")
        try expect(json.contains("Line 1"), "journal payload should contain the first line")
        try expect(json.contains("Line 3"), "journal payload should contain the later line")
        try expect(payloads.count == 2, "journal payload should drop blank lines and emit two paragraphs")
    }

    static func notionClientHttpErrorExposesReadableDescription() throws {
        let error = NotionClientError.httpError(
            statusCode: 401,
            message: #"{"object":"error","status":401,"code":"unauthorized","message":"API token is invalid."}"#
        )

        try expect(
            error.localizedDescription == "Notion 请求失败（HTTP 401）：API token is invalid.",
            "HTTP errors should surface the status code and Notion message"
        )
    }

    static func notionRepositoryValidationErrorExposesReadableDescription() throws {
        let error = NotionRepositoryError.validationFailed(
            [
                ValidationIssue(message: "缺少必填字段：Name(title)"),
                ValidationIssue(message: "缺少必填字段：Date(date)")
            ]
        )

        try expect(
            error.localizedDescription == "数据库字段校验失败：缺少必填字段：Name(title)；缺少必填字段：Date(date)",
            "repository validation errors should join validation issues into one readable message"
        )
    }
}
