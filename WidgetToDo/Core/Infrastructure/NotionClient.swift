import Foundation

public actor NotionClient {
    private let session: URLSession
    private let baseURL = URL(string: "https://api.notion.com/v1")!
    private let apiVersion = "2022-06-28"
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchDatabaseSchema(databaseID: String, token: String) async throws -> [NotionPropertySchema] {
        let request = try makeRequest(path: "databases/\(databaseID)", method: "GET", token: token)
        let response: DatabaseResponse = try await perform(request)
        return response.properties.map { NotionPropertySchema(name: $0.key, type: $0.value.type, selectOptions: $0.value.select?.options ?? []) }
    }

    public func queryTasks(on date: Date, databaseID: String, fields: TaskDatabaseFieldMapping, token: String) async throws -> [TaskItem] {
        let dateString = Self.dayFormatter.string(from: date)
        let body: [String: Any] = [
            "filter": [
                "property": fields.date,
                "date": [
                    "equals": dateString
                ]
            ],
            "page_size": 100
        ]

        let request = try makeRequest(
            path: "databases/\(databaseID)/query",
            method: "POST",
            token: token,
            body: body
        )
        let response: QueryResponse = try await perform(request)
        return try response.results.map { try Self.mapTask(page: $0, fields: fields) }
    }

    public func updateTaskCheckbox(pageID: String, isDone: Bool, fields: TaskDatabaseFieldMapping, token: String) async throws {
        let body: [String: Any] = [
            "properties": [
                fields.done: [
                    "checkbox": isDone
                ]
            ]
        ]
        let request = try makeRequest(path: "pages/\(pageID)", method: "PATCH", token: token, body: body)
        let _: PageResponse = try await perform(request)
    }

    public func updateTaskTitle(
        pageID: String,
        title: String,
        priority: String?,
        estimatedMinutes: Int?,
        fields: TaskDatabaseFieldMapping,
        token: String
    ) async throws -> TaskItem {
        var properties: [String: Any] = [
            fields.title: [
                "title": [
                    [
                        "type": "text",
                        "text": [
                            "content": title
                        ]
                    ]
                ]
            ]
        ]
        if let estimatedMinutesField = fields.estimatedMinutes, let estimatedMinutes {
            properties[estimatedMinutesField] = [
                "number": estimatedMinutes
            ]
        }
        if let priorityField = fields.priority {
            properties[priorityField] = priority.map { ["select": ["name": $0]] } ?? ["select": NSNull()]
        }
        let body: [String: Any] = ["properties": properties]
        let request = try makeRequest(path: "pages/\(pageID)", method: "PATCH", token: token, body: body)
        let page: PageResponse = try await perform(request)
        return try Self.mapTask(page: page, fields: fields)
    }

    public func deleteTask(pageID: String, token: String) async throws {
        let body: [String: Any] = ["archived": true]
        let request = try makeRequest(path: "pages/\(pageID)", method: "PATCH", token: token, body: body)
        let _: PageResponse = try await perform(request)
    }

    public func createTask(
        databaseID: String,
        title: String,
        date: Date,
        priority: String?,
        estimatedMinutes: Int?,
        hasPriorityField: Bool,
        fields: TaskDatabaseFieldMapping,
        token: String
    ) async throws -> TaskItem {
        let dateString = Self.dayFormatter.string(from: date)
        var properties: [String: Any] = [
            fields.title: [
                "title": [
                    [
                        "type": "text",
                        "text": [
                            "content": title
                        ]
                    ]
                ]
            ],
            fields.date: [
                "date": [
                    "start": dateString
                ]
            ],
            fields.done: [
                "checkbox": false
            ]
        ]
        if hasPriorityField, let priorityField = fields.priority, let priority {
            properties[priorityField] = [
                "select": [
                    "name": priority
                ]
            ]
        }
        if let estimatedMinutesField = fields.estimatedMinutes, let estimatedMinutes {
            properties[estimatedMinutesField] = [
                "number": estimatedMinutes
            ]
        }
        let body: [String: Any] = [
            "parent": [
                "database_id": databaseID
            ],
            "properties": properties
        ]
        let request = try makeRequest(path: "pages", method: "POST", token: token, body: body)
        let page: PageResponse = try await perform(request)
        return try Self.mapTask(page: page, fields: fields)
    }

    public func findJournalPage(databaseID: String, fields: JournalDatabaseFieldMapping, token: String, date: Date) async throws -> JournalEntry? {
        let dateString = Self.dayFormatter.string(from: date)
        let body: [String: Any] = [
            "filter": [
                "property": fields.date,
                "date": [
                    "equals": dateString
                ]
            ],
            "page_size": 1
        ]

        let request = try makeRequest(
            path: "databases/\(databaseID)/query",
            method: "POST",
            token: token,
            body: body
        )
        let response: QueryResponse = try await perform(request)
        guard let first = response.results.first else {
            return nil
        }

        var entry = try Self.mapJournal(page: first, fields: fields, fallbackDate: date)
        entry.contentText = try await fetchJournalText(pageID: entry.id, token: token)
        return entry
    }

    public func createJournalPage(databaseID: String, fields: JournalDatabaseFieldMapping, token: String, date: Date) async throws -> JournalEntry {
        let dateString = Self.dayFormatter.string(from: date)
        let journalTitle = "日记 \(Self.journalTitleDateFormatter.string(from: date))"
        let body: [String: Any] = [
            "parent": [
                "database_id": databaseID
            ],
            "properties": [
                fields.title: [
                    "title": [
                        [
                            "type": "text",
                            "text": [
                                "content": journalTitle
                            ]
                        ]
                    ]
                ],
                fields.date: [
                    "date": [
                        "start": dateString
                    ]
                ]
            ]
        ]

        let request = try makeRequest(path: "pages", method: "POST", token: token, body: body)
        let page: PageResponse = try await perform(request)
        return try Self.mapJournal(page: page, fields: fields, fallbackDate: date)
    }

    public func fetchJournalText(pageID: String, token: String) async throws -> String {
        let request = try makeRequest(
            path: "blocks/\(pageID)/children",
            method: "GET",
            token: token,
            queryItems: [URLQueryItem(name: "page_size", value: "100")]
        )
        let response: BlockChildrenResponse = try await perform(request)
        let lines = response.results.compactMap { block -> String? in
            guard block.type == "paragraph" else { return nil }
            return block.paragraph?.richText.map(\.plainText).joined()
        }
        return lines.joined(separator: "\n")
    }

    public func replaceJournalText(pageID: String, text: String, token: String) async throws {
        let existingRequest = try makeRequest(
            path: "blocks/\(pageID)/children",
            method: "GET",
            token: token,
            queryItems: [URLQueryItem(name: "page_size", value: "100")]
        )
        let existing: BlockChildrenResponse = try await perform(existingRequest)

        for block in existing.results {
            let deleteRequest = try makeRequest(path: "blocks/\(block.id)", method: "DELETE", token: token)
            let _: DeletedBlockResponse = try await perform(deleteRequest)
        }

        let children = JournalContentBuilder.makeParagraphPayloads(from: text)
        guard !children.isEmpty else {
            return
        }

        let appendBody: [String: Any] = [
            "children": children
        ]
        let appendRequest = try makeRequest(path: "blocks/\(pageID)/children", method: "PATCH", token: token, body: appendBody)
        let _: BlockChildrenResponse = try await perform(appendRequest)
    }

    private func makeRequest(
        path: String,
        method: String,
        token: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil
    ) throws -> URLRequest {
        let url = try endpointURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private func endpointURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw NotionClientError.invalidResponse
        }
        components.path += "/\(path)"
        guard !queryItems.isEmpty else {
            guard let resolvedURL = components.url else {
                throw NotionClientError.invalidResponse
            }
            return resolvedURL
        }
        components.queryItems = queryItems

        guard let resolvedURL = components.url else {
            throw NotionClientError.invalidResponse
        }

        return resolvedURL
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionClientError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "未知响应"
            throw NotionClientError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        return try jsonDecoder.decode(Response.self, from: data)
    }

    private static func mapTask(page: PageResponse, fields: TaskDatabaseFieldMapping) throws -> TaskItem {
        let title = page.properties[fields.title]?.title?.first?.plainText ?? "未命名"
        let dateString = page.properties[fields.date]?.date?.start ?? dayFormatter.string(from: Date())
        let date = try parseNotionDate(dateString)
        let priority = fields.priority.flatMap { page.properties[$0]?.select?.name }
        let estimatedMinutes = fields.estimatedMinutes.flatMap { page.properties[$0]?.number }.flatMap { Int($0) }
        let isDone = page.properties[fields.done]?.checkbox ?? false
        return TaskItem(
            id: page.id,
            title: title,
            isDone: isDone,
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            date: date,
            url: page.url.flatMap(URL.init(string:)),
            syncStatus: .synced
        )
    }

    private static func mapJournal(page: PageResponse, fields: JournalDatabaseFieldMapping, fallbackDate: Date) throws -> JournalEntry {
        let title = page.properties[fields.title]?.title?.first?.plainText ?? "日记"
        let dateString = page.properties[fields.date]?.date?.start
        let date = try dateString.map(parseNotionDate) ?? fallbackDate
        return JournalEntry(
            id: page.id,
            title: title,
            date: date,
            contentText: "",
            url: page.url.flatMap(URL.init(string:)),
            syncStatus: .synced
        )
    }

    private static func parseNotionDate(_ raw: String) throws -> Date {
        if let date = dayFormatter.date(from: raw) {
            return date
        }
        if let date = ISO8601DateFormatter().date(from: raw) {
            return date
        }
        throw NotionClientError.invalidDate(raw)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let journalTitleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()
}

public enum NotionClientError: Error {
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case invalidDate(String)
}

extension NotionClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Notion 响应无效。"
        case let .httpError(statusCode, message):
            let readableMessage = Self.extractReadableMessage(from: message)
            return "Notion 请求失败（HTTP \(statusCode)）：\(readableMessage)"
        case let .invalidDate(raw):
            return "Notion 返回了无法识别的日期：\(raw)"
        }
    }

    private static func extractReadableMessage(from rawMessage: String) -> String {
        guard let data = rawMessage.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = object["message"] as? String,
              !message.isEmpty else {
            return rawMessage
        }

        if message.contains("Could not find property with name or id:") ||
            message.contains("is not a property that exists") {
            return "数据库字段可能已改名或已删除，请重新进入初始化配置并保存一次数据库设置。"
        }

        return message
    }
}

private struct DatabaseResponse: Decodable {
    let properties: [String: DatabaseProperty]
}

private struct DatabaseProperty: Decodable {
    let type: String
    let select: SelectConfiguration?
}

private struct SelectConfiguration: Decodable { let options: [NotionSelectOption] }

private struct QueryResponse: Decodable {
    let results: [PageResponse]
}

private struct PageResponse: Decodable {
    let id: String
    let url: String?
    let properties: [String: PageProperty]
}

private struct PageProperty: Decodable {
    let checkbox: Bool?
    let date: NotionDateProperty?
    let number: Double?
    let select: NotionSelectProperty?
    let title: [NotionRichText]?
}

private struct NotionDateProperty: Decodable {
    let start: String
}

private struct NotionSelectProperty: Decodable {
    let name: String
}

private struct NotionRichText: Decodable {
    let plainText: String

    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
    }
}

private struct BlockChildrenResponse: Decodable {
    let results: [BlockResponse]
}

private struct BlockResponse: Decodable {
    let id: String
    let type: String
    let paragraph: ParagraphBlock?
}

private struct ParagraphBlock: Decodable {
    let richText: [NotionRichText]

    enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
    }
}

private struct DeletedBlockResponse: Decodable {
    let archived: Bool
}
