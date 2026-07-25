import Foundation

public enum ConfigurationInputNormalizer {
    public static func normalizeDatabaseInput(_ input: String) -> String? {
        NotionDatabaseReference.parse(input)?.rawValue
    }

    public static func validate(token: String, tasksInput: String, journalInput: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ValidationIssue(.missingToken))
        }

        if normalizeDatabaseInput(tasksInput) == nil {
            issues.append(ValidationIssue(.invalidTasksDatabaseInput))
        }

        if normalizeDatabaseInput(journalInput) == nil {
            issues.append(ValidationIssue(.invalidJournalDatabaseInput))
        }

        return issues
    }
}
