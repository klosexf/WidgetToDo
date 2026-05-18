import Foundation

public struct JournalEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var title: String
    public var date: Date
    public var contentText: String
    public var url: URL?
    public var syncStatus: SyncStatus

    public init(
        id: String,
        title: String,
        date: Date,
        contentText: String,
        url: URL?,
        syncStatus: SyncStatus
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.contentText = contentText
        self.url = url
        self.syncStatus = syncStatus
    }
}
