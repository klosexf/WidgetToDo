import Foundation

public struct NewTaskDraft: Codable, Equatable, Sendable {
    public var title: String
    public var date: Date
    public var priority: String
    public var createdAt: Date

    public init(title: String, date: Date, priority: String, createdAt: Date = Date()) {
        self.title = title
        self.date = date
        self.priority = priority
        self.createdAt = createdAt
    }

    public var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > 60
    }
}
