import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public let tasksDatabaseID: String
    public let journalDatabaseID: String
    public let tasksPageURL: URL?
    public let journalPageURL: URL?
    public let lastValidatedAt: Date

    public init(
        tasksDatabaseID: String,
        journalDatabaseID: String,
        tasksPageURL: URL? = nil,
        journalPageURL: URL? = nil,
        lastValidatedAt: Date
    ) {
        self.tasksDatabaseID = tasksDatabaseID
        self.journalDatabaseID = journalDatabaseID
        self.tasksPageURL = tasksPageURL
        self.journalPageURL = journalPageURL
        self.lastValidatedAt = lastValidatedAt
    }
}
