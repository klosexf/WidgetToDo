import Foundation

public enum SyncStatus: String, Codable, Sendable {
    case synced
    case syncing
    case failed
    case localPending
}

public struct TaskItem: Equatable, Sendable, Identifiable {
    public let id: String
    public var title: String
    public var isDone: Bool
    public var priority: String?
    public var estimatedMinutes: Int?
    public var date: Date
    public var url: URL?
    public var syncStatus: SyncStatus

    public init(
        id: String,
        title: String,
        isDone: Bool,
        priority: String?,
        estimatedMinutes: Int? = nil,
        date: Date,
        url: URL?,
        syncStatus: SyncStatus
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.priority = priority
        self.estimatedMinutes = estimatedMinutes
        self.date = date
        self.url = url
        self.syncStatus = syncStatus
    }
}

public struct PendingTaskItem: Equatable, Sendable, Identifiable {
    public let id: String
    public var title: String
    public var date: Date
    public var priority: String?
    public var estimatedMinutes: Int?
    public var createdAt: Date
    public var isFailed: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        date: Date,
        priority: String?,
        estimatedMinutes: Int? = nil,
        createdAt: Date = Date(),
        isFailed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.priority = priority
        self.estimatedMinutes = estimatedMinutes
        self.createdAt = createdAt
        self.isFailed = isFailed
    }
}

public enum TaskSorting {
    public static func sort(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { lhs, rhs in
            if lhs.isDone != rhs.isDone {
                return !lhs.isDone
            }

            let lhsPriority = priorityRank(lhs.priority)
            let rhsPriority = priorityRank(rhs.priority)
            if lhsPriority != rhsPriority {
                return lhsPriority > rhsPriority
            }

            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func priorityRank(_ priority: String?) -> Int {
        switch priority?.lowercased() {
        case "urgent":
            return 4
        case "high":
            return 3
        case "medium":
            return 2
        case "low":
            return 1
        default:
            return 0
        }
    }
}
