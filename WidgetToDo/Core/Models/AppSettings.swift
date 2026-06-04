import Foundation

public struct TaskDatabaseFieldMapping: Codable, Equatable, Sendable {
    public let title: String
    public let date: String
    public let done: String
    public let priority: String?
    public let estimatedMinutes: String?

    public static let legacyDefault = TaskDatabaseFieldMapping(
        title: "Name",
        date: "Date",
        done: "Done",
        priority: "Priority",
        estimatedMinutes: nil
    )

    public init(title: String, date: String, done: String, priority: String?, estimatedMinutes: String? = nil) {
        self.title = title
        self.date = date
        self.done = done
        self.priority = priority
        self.estimatedMinutes = estimatedMinutes
    }
}

public struct JournalDatabaseFieldMapping: Codable, Equatable, Sendable {
    public let title: String
    public let date: String

    public static let legacyDefault = JournalDatabaseFieldMapping(
        title: "Name",
        date: "Date"
    )

    public init(title: String, date: String) {
        self.title = title
        self.date = date
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public let tasksDatabaseID: String
    public let journalDatabaseID: String
    public let tasksPageURL: URL?
    public let journalPageURL: URL?
    public let lastValidatedAt: Date
    public let hasPriorityField: Bool
    public let tasksFieldMapping: TaskDatabaseFieldMapping
    public let journalFieldMapping: JournalDatabaseFieldMapping

    enum CodingKeys: String, CodingKey {
        case tasksDatabaseID
        case journalDatabaseID
        case tasksPageURL
        case journalPageURL
        case lastValidatedAt
        case hasPriorityField
        case tasksFieldMapping
        case journalFieldMapping
    }

    public init(
        tasksDatabaseID: String,
        journalDatabaseID: String,
        tasksPageURL: URL? = nil,
        journalPageURL: URL? = nil,
        lastValidatedAt: Date,
        hasPriorityField: Bool = true,
        tasksFieldMapping: TaskDatabaseFieldMapping = .legacyDefault,
        journalFieldMapping: JournalDatabaseFieldMapping = .legacyDefault
    ) {
        self.tasksDatabaseID = tasksDatabaseID
        self.journalDatabaseID = journalDatabaseID
        self.tasksPageURL = tasksPageURL
        self.journalPageURL = journalPageURL
        self.lastValidatedAt = lastValidatedAt
        self.hasPriorityField = hasPriorityField
        self.tasksFieldMapping = tasksFieldMapping
        self.journalFieldMapping = journalFieldMapping
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasksDatabaseID = try container.decode(String.self, forKey: .tasksDatabaseID)
        journalDatabaseID = try container.decode(String.self, forKey: .journalDatabaseID)
        tasksPageURL = try container.decodeIfPresent(URL.self, forKey: .tasksPageURL)
        journalPageURL = try container.decodeIfPresent(URL.self, forKey: .journalPageURL)
        lastValidatedAt = try container.decode(Date.self, forKey: .lastValidatedAt)
        hasPriorityField = try container.decodeIfPresent(Bool.self, forKey: .hasPriorityField) ?? true
        tasksFieldMapping = try container.decodeIfPresent(TaskDatabaseFieldMapping.self, forKey: .tasksFieldMapping) ?? .legacyDefault
        journalFieldMapping = try container.decodeIfPresent(JournalDatabaseFieldMapping.self, forKey: .journalFieldMapping) ?? .legacyDefault
    }
}
