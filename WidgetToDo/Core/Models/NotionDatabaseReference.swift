import Foundation

public struct NotionDatabaseReference: Equatable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func parse(_ input: String) -> NotionDatabaseReference? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return nil
        }

        if let canonical = canonicalUUID(from: trimmed) {
            return NotionDatabaseReference(rawValue: canonical)
        }

        return nil
    }

    private static func canonicalUUID(from input: String) -> String? {
        let compact = input.replacingOccurrences(of: "-", with: "")
        let candidate: String
        if compact.count == 32, compact.range(of: #"^[0-9a-fA-F]{32}$"#, options: .regularExpression) != nil {
            candidate = compact
        } else if let range = compact.range(of: #"[0-9a-fA-F]{32}"#, options: .regularExpression) {
            candidate = String(compact[range])
        } else {
            return nil
        }

        if candidate.count == 32 {
            return [
                candidate.prefix(8),
                candidate.dropFirst(8).prefix(4),
                candidate.dropFirst(12).prefix(4),
                candidate.dropFirst(16).prefix(4),
                candidate.dropFirst(20).prefix(12)
            ]
            .map(String.init)
            .joined(separator: "-")
            .lowercased()
        }

        return nil
    }
}
