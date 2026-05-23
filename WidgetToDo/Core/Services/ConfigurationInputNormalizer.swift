import Foundation

public enum ConfigurationInputNormalizer {
    public static func normalizeDatabaseInput(_ input: String) -> String? {
        NotionDatabaseReference.parse(input)?.rawValue
    }

    public static func validate(token: String, tasksInput: String, journalInput: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ValidationIssue(message: "请填写 Notion Token。"))
        }

        if normalizeDatabaseInput(tasksInput) == nil {
            issues.append(ValidationIssue(message: "Tasks Database ID 或 URL 无效。"))
        }

        if normalizeDatabaseInput(journalInput) == nil {
            issues.append(ValidationIssue(message: "Journal Database ID 或 URL 无效。"))
        }

        return issues
    }
}
