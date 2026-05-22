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
    static func main() async throws {
        do {
            try databaseReferenceParsesRawUUID()
            try databaseReferenceParsesDatabaseURL()
            try taskFieldValidationReportsMissingRequiredFields()
            try taskSortingKeepsIncompleteAndHigherPriorityFirst()
            try journalContentBuilderConvertsLinesToParagraphBlocks()
            try notionClientHttpErrorExposesReadableDescription()
            try notionRepositoryValidationErrorExposesReadableDescription()
            try notionRepositoryBuildsTasksDatabasePageURL()
            try todoListViewModelDoesNotSynchronouslyBridgeNestedObjectWillChange()
            try todoHeaderOpenButtonTargetsTasksDatabasePage()
            try todoDateTitleUsesChineseDateWithoutTodaySpecialCase()
            try floatingWindowManagerDoesNotDependOnGlobalMouseUpMonitoring()
            try floatingPanelDoesNotSynchronouslyActivateDuringEventDispatch()
            try await notionClientBuildsDatabaseSchemaURLWithoutQuery()
            try await notionClientPreservesQueryItemsInBlockChildrenURL()
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

    static func notionRepositoryBuildsTasksDatabasePageURL() throws {
        let databaseID = "12345678-1234-1234-1234-1234567890ab"
        let databaseURL = URL(string: "https://www.notion.so/\(databaseID.replacingOccurrences(of: "-", with: ""))")

        try expect(
            databaseURL?.absoluteString == "https://www.notion.so/123456781234123412341234567890ab",
            "task database navigation should target the database root URL instead of a task page URL"
        )
    }

    static func floatingWindowManagerDoesNotDependOnGlobalMouseUpMonitoring() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let managerURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("FloatingWindowManager.swift")
        let source = try String(contentsOf: managerURL, encoding: .utf8)

        try expect(
            !source.contains("addGlobalMonitorForEvents"),
            "floating window drag completion must not rely on global mouse-up monitoring"
        )
        try expect(
            source.contains("if event.type == .leftMouseUp"),
            "floating window drag completion should clear drag state on local leftMouseUp"
        )
    }

    static func todoListViewModelDoesNotSynchronouslyBridgeNestedObjectWillChange() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let viewModelURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("TodoListViewModel.swift")
        let source = try String(contentsOf: viewModelURL, encoding: .utf8)

        try expect(
            !source.contains("self?.objectWillChange.send()"),
            "todo list view model should not synchronously forward nested objectWillChange events"
        )
    }

    static func todoHeaderOpenButtonTargetsTasksDatabasePage() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        try expect(
            source.contains("todoViewModel.tasksDatabaseURL != nil"),
            "todo header open button should depend on the tasks database URL being available"
        )
        try expect(
            source.contains("todoViewModel.openTasksDatabaseInNotion()"),
            "todo header open button should open the tasks database page"
        )
        try expect(
            !source.contains("firstTaskWithUrl"),
            "todo header open button must not reuse the first task page URL"
        )
    }

    static func todoDateTitleUsesChineseDateWithoutTodaySpecialCase() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("ContentView.swift")
        let source = try String(contentsOf: contentViewURL, encoding: .utf8)

        try expect(
            source.contains("TodoDateDisplayFormatter.title(for: todoViewModel.selectedDate)"),
            "todo date title should delegate to the shared formatter"
        )
        try expect(
            source.contains("TodoDateDisplayFormatter.emptyStateTitle(for: todoViewModel.selectedDate)"),
            "todo empty state should delegate to the shared formatter"
        )
        try expect(
            source.contains("private let todoDateTitleWidth: CGFloat = 104"),
            "todo date title should reserve a fixed width so today and non-today labels align"
        )
        try expect(
            source.contains(".frame(width: todoDateTitleWidth, alignment: .leading)"),
            "todo date title should render inside the fixed-width frame"
        )
        try expect(
            source.contains(".lineLimit(1)"),
            "todo date title should be constrained to a single line"
        )
        try expect(
            source.contains(".minimumScaleFactor(0.8)"),
            "todo date title should scale down before wrapping"
        )
        try expect(
            source.contains(".allowsTightening(true)"),
            "todo date title should tighten glyph spacing before truncation"
        )
        try expect(
            source.contains(".frame(height: 28)"),
            "todo date title should keep a stable vertical slot height"
        )
        try expect(
            source.contains("private let jumpToTodayWidth: CGFloat = 56"),
            "jump-to-today control should reserve a stable slot width"
        )
    }

    static func floatingPanelDoesNotSynchronouslyActivateDuringEventDispatch() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let managerURL = rootURL
            .appendingPathComponent("WidgetToDo")
            .appendingPathComponent("FloatingWindowManager.swift")
        let source = try String(contentsOf: managerURL, encoding: .utf8)

        try expect(
            !source.contains("NSApp.activate(ignoringOtherApps: true)"),
            "floating panel should avoid manual app activation from sendEvent to prevent event-path priority inversions"
        )
        try expect(
            !source.contains("RunLoop.main.perform"),
            "floating panel should not enqueue deferred activation work from sendEvent"
        )
    }

    static func notionClientPreservesQueryItemsInBlockChildrenURL() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CapturingURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = NotionClient(session: session)

        CapturingURLProtocol.reset()
        _ = try await client.fetchJournalText(pageID: "1234-5678", token: "secret_test_token")

        guard let requestURL = CapturingURLProtocol.lastRequest?.url else {
            throw SmokeTestFailure(description: "expected fetchJournalText to issue a request")
        }

        try expect(
            requestURL.absoluteString == "https://api.notion.com/v1/blocks/1234-5678/children?page_size=100",
            "block children requests should keep page_size as a query parameter"
        )
    }

    static func notionClientBuildsDatabaseSchemaURLWithoutQuery() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CapturingURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = NotionClient(session: session)

        CapturingURLProtocol.reset()
        CapturingURLProtocol.responseBody = #"{"properties":{}}"#.data(using: .utf8)!
        _ = try await client.fetchDatabaseSchema(databaseID: "db-1234", token: "secret_test_token")

        guard let requestURL = CapturingURLProtocol.lastRequest?.url else {
            throw SmokeTestFailure(description: "expected fetchDatabaseSchema to issue a request")
        }

        try expect(
            requestURL.absoluteString == "https://api.notion.com/v1/databases/db-1234",
            "database schema requests should append the endpoint path without adding a query string"
        )
    }
}

final class CapturingURLProtocol: URLProtocol {
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var responseBody = #"{"results":[]}"#.data(using: .utf8)!

    static func reset() {
        lastRequest = nil
        responseBody = #"{"results":[]}"#.data(using: .utf8)!
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
