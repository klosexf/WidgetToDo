import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public let tasksDatabaseID: String
    public let journalDatabaseID: String
    public let tasksPageURL: URL?
    public let journalPageURL: URL?
    public let lastValidatedAt: Date
    public let hasPriorityField: Bool

    enum CodingKeys: String, CodingKey {
        case tasksDatabaseID
        case journalDatabaseID
        case tasksPageURL
        case journalPageURL
        case lastValidatedAt
        case hasPriorityField
    }

    public init(
        tasksDatabaseID: String,
        journalDatabaseID: String,
        tasksPageURL: URL? = nil,
        journalPageURL: URL? = nil,
        lastValidatedAt: Date,
        hasPriorityField: Bool = true
    ) {
        self.tasksDatabaseID = tasksDatabaseID
        self.journalDatabaseID = journalDatabaseID
        self.tasksPageURL = tasksPageURL
        self.journalPageURL = journalPageURL
        self.lastValidatedAt = lastValidatedAt
        self.hasPriorityField = hasPriorityField
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasksDatabaseID = try container.decode(String.self, forKey: .tasksDatabaseID)
        journalDatabaseID = try container.decode(String.self, forKey: .journalDatabaseID)
        tasksPageURL = try container.decodeIfPresent(URL.self, forKey: .tasksPageURL)
        journalPageURL = try container.decodeIfPresent(URL.self, forKey: .journalPageURL)
        lastValidatedAt = try container.decode(Date.self, forKey: .lastValidatedAt)
        hasPriorityField = try container.decodeIfPresent(Bool.self, forKey: .hasPriorityField) ?? true
    }
}
