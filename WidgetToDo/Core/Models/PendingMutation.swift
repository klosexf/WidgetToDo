import Foundation

public enum PendingMutationTarget: String, Codable, Sendable {
    case task
    case journal
}

public enum PendingMutationType: String, Codable, Sendable {
    case toggleCheckbox
    case replaceJournalText
    case createTask
}

public enum PendingMutationStatus: String, Codable, Sendable {
    case queued
    case synced
    case failed
}

public struct PendingMutation: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let target: PendingMutationTarget
    public let targetID: String
    public let type: PendingMutationType
    public let payload: String
    public var retryCount: Int
    public var status: PendingMutationStatus
    public var lastError: String?
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        target: PendingMutationTarget,
        targetID: String,
        type: PendingMutationType,
        payload: String,
        retryCount: Int = 0,
        status: PendingMutationStatus = .queued,
        lastError: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.target = target
        self.targetID = targetID
        self.type = type
        self.payload = payload
        self.retryCount = retryCount
        self.status = status
        self.lastError = lastError
        self.createdAt = createdAt
    }
}
