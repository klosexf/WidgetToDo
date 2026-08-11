import Foundation

public struct TaskDatabaseFieldMapping: Codable, Equatable, Sendable {
    public let title: String
    public let date: String
    public let done: String
    public let priority: String?
    public let priorityOptions: [NotionSelectOption]
    public let estimatedMinutes: String?

    public static let legacyDefault = TaskDatabaseFieldMapping(
        title: "Name",
        date: "Date",
        done: "Done",
        priority: "Priority",
        estimatedMinutes: nil
    )

    public init(title: String, date: String, done: String, priority: String?, priorityOptions: [NotionSelectOption] = [], estimatedMinutes: String? = nil) {
        self.title = title
        self.date = date
        self.done = done
        self.priority = priority
        self.priorityOptions = priorityOptions
        self.estimatedMinutes = estimatedMinutes
    }

    enum CodingKeys: String, CodingKey { case title, date, done, priority, priorityOptions, estimatedMinutes }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title); date = try c.decode(String.self, forKey: .date); done = try c.decode(String.self, forKey: .done)
        priority = try c.decodeIfPresent(String.self, forKey: .priority); priorityOptions = try c.decodeIfPresent([NotionSelectOption].self, forKey: .priorityOptions) ?? []
        estimatedMinutes = try c.decodeIfPresent(String.self, forKey: .estimatedMinutes)
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
    public let miniModeState: MiniModeState

    enum CodingKeys: String, CodingKey {
        case tasksDatabaseID
        case journalDatabaseID
        case tasksPageURL
        case journalPageURL
        case lastValidatedAt
        case hasPriorityField
        case tasksFieldMapping
        case journalFieldMapping
        case miniModeState
    }

    public init(
        tasksDatabaseID: String,
        journalDatabaseID: String,
        tasksPageURL: URL? = nil,
        journalPageURL: URL? = nil,
        lastValidatedAt: Date,
        hasPriorityField: Bool = true,
        tasksFieldMapping: TaskDatabaseFieldMapping = .legacyDefault,
        journalFieldMapping: JournalDatabaseFieldMapping = .legacyDefault,
        miniModeState: MiniModeState = .default
    ) {
        self.tasksDatabaseID = tasksDatabaseID
        self.journalDatabaseID = journalDatabaseID
        self.tasksPageURL = tasksPageURL
        self.journalPageURL = journalPageURL
        self.lastValidatedAt = lastValidatedAt
        self.hasPriorityField = hasPriorityField
        self.tasksFieldMapping = tasksFieldMapping
        self.journalFieldMapping = journalFieldMapping
        self.miniModeState = miniModeState
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
        miniModeState = try container.decodeIfPresent(MiniModeState.self, forKey: .miniModeState) ?? .default
    }
}
