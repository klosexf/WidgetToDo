import Foundation

public enum DataSourceKind: String, Codable, Sendable {
    case tasks
    case journal
}

public struct ValidationIssue: Equatable, Sendable, Identifiable {
    public let id = UUID()
    public let message: AppMessage

    public init(_ key: AppText.Key, arguments: [String] = []) {
        message = AppMessage(key, arguments: arguments)
    }
}

public enum ResolvedDatabaseFields: Equatable, Sendable {
    case tasks(TaskDatabaseFieldMapping)
    case journal(JournalDatabaseFieldMapping)
}

public enum FieldResolution: Equatable, Sendable {
    case success(ResolvedDatabaseFields)
    case failure([ValidationIssue])
}

public enum FieldValidator {
    public static func resolve(_ properties: [NotionPropertySchema], for kind: DataSourceKind) -> FieldResolution {
        switch kind {
        case .tasks:
            return resolveTasks(properties)
        case .journal:
            return resolveJournal(properties)
        }
    }

    private static func resolveTasks(_ properties: [NotionPropertySchema]) -> FieldResolution {
        var issues: [ValidationIssue] = []
        let title = resolveRequiredField(in: properties, type: "title", issues: &issues)
        let date = resolveRequiredField(in: properties, type: "date", issues: &issues)
        let done = resolveRequiredField(in: properties, type: "checkbox", issues: &issues)

        guard let title, let date, let done, issues.isEmpty else {
            return .failure(issues)
        }

        let priorityCandidates = propertyNames(in: properties, matching: "select")
        let estimatedMinutesCandidates = propertyNames(in: properties, matching: "number")
        let mapping = TaskDatabaseFieldMapping(
            title: title,
            date: date,
            done: done,
            priority: priorityCandidates.count == 1 ? priorityCandidates[0] : nil,
            estimatedMinutes: estimatedMinutesCandidates.count == 1 ? estimatedMinutesCandidates[0] : nil
        )
        return .success(.tasks(mapping))
    }

    private static func resolveJournal(_ properties: [NotionPropertySchema]) -> FieldResolution {
        var issues: [ValidationIssue] = []
        let title = resolveRequiredField(in: properties, type: "title", issues: &issues)
        let date = resolveRequiredField(in: properties, type: "date", issues: &issues)

        guard let title, let date, issues.isEmpty else {
            return .failure(issues)
        }

        return .success(.journal(JournalDatabaseFieldMapping(title: title, date: date)))
    }

    private static func resolveRequiredField(
        in properties: [NotionPropertySchema],
        type: String,
        issues: inout [ValidationIssue]
    ) -> String? {
        let candidates = propertyNames(in: properties, matching: type)
        switch candidates.count {
        case 0:
            issues.append(ValidationIssue(.missingRequiredFieldType, arguments: [type]))
            return nil
        case 1:
            return candidates[0]
        default:
            issues.append(
                ValidationIssue(
                    .duplicateRequiredField,
                    arguments: [type, candidates.joined(separator: ", "), type]
                )
            )
            return nil
        }
    }

    private static func propertyNames(in properties: [NotionPropertySchema], matching type: String) -> [String] {
        properties.compactMap { property in
            property.type == type ? property.name : nil
        }
    }
}
