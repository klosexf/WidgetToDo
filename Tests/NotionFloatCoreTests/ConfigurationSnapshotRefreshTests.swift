import Foundation
import XCTest
@testable import NotionFloatCore

final class ConfigurationSnapshotRefreshTests: XCTestCase {
    func testLoadConfigurationSnapshotRefreshesMissingSelectOptionsFromTasksSchema() async throws {
        let directory = try makeTemporaryDirectory()
        let tokenStore = RefreshTokenStore()
        try tokenStore.save(token: "test-token")
        let settingsStore = try SettingsStore(baseURL: directory)
        try await settingsStore.save(
            AppSettings(
                tasksDatabaseID: "tasks-db",
                journalDatabaseID: "journal-db",
                lastValidatedAt: Date(timeIntervalSince1970: 0),
                hasPriorityField: false,
                tasksFieldMapping: TaskDatabaseFieldMapping(
                    title: "Name",
                    date: "日期",
                    done: "Done",
                    priority: nil,
                    priorityOptions: []
                ),
                journalFieldMapping: JournalDatabaseFieldMapping(title: "Name", date: "Date")
            )
        )

        RefreshMockURLProtocol.responseBody = Data("""
        {
          "properties": {
            "Name": { "type": "title", "title": {} },
            "日期": { "type": "date", "date": {} },
            "Done": { "type": "checkbox", "checkbox": {} },
            "优先级": {
              "type": "select",
              "select": { "options": [{ "name": "高", "color": "red" }] }
            }
          }
        }
        """.utf8)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshMockURLProtocol.self]
        let repository = NotionRepository(
            tokenStore: tokenStore,
            settingsStore: settingsStore,
            cache: try SQLiteCache(baseURL: directory),
            notionClient: NotionClient(session: URLSession(configuration: configuration))
        )

        let snapshot = try await repository.loadConfigurationSnapshot()

        XCTAssertEqual(
            snapshot.choiceField,
            TaskChoiceField(name: "优先级", options: [NotionSelectOption(name: "高", color: .red)])
        )
        let savedSettings = try await settingsStore.load()
        let persisted = try XCTUnwrap(savedSettings)
        XCTAssertEqual(persisted.tasksFieldMapping.priority, "优先级")
        XCTAssertEqual(persisted.tasksFieldMapping.priorityOptions, [NotionSelectOption(name: "高", color: .red)])
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }
}

private final class RefreshTokenStore: TokenStore, @unchecked Sendable {
    private var token: String?

    func save(token: String) throws { self.token = token }
    func loadToken() throws -> String? { token }
    func deleteToken() { token = nil }
}

private final class RefreshMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responseBody = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
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
