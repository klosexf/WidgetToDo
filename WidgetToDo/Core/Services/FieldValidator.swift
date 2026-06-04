import Foundation

public enum DataSourceKind: String, Codable, Sendable {
    case tasks
    case journal
}

public struct ValidationIssue: Equatable, Sendable, Identifiable {
    public let id = UUID()
    public let message: String

    public init(message: String) {
        self.message = message
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
        let title = resolveRequiredField(in: properties, type: "title", label: "任务标题", issues: &issues)
        let date = resolveRequiredField(in: properties, type: "date", label: "任务日期", issues: &issues)
        let done = resolveRequiredField(in: properties, type: "checkbox", label: "任务完成状态", issues: &issues)

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
        let title = resolveRequiredField(in: properties, type: "title", label: "日记标题", issues: &issues)
        let date = resolveRequiredField(in: properties, type: "date", label: "日记日期", issues: &issues)

        guard let title, let date, issues.isEmpty else {
            return .failure(issues)
        }

        return .success(.journal(JournalDatabaseFieldMapping(title: title, date: date)))
    }

    private static func resolveRequiredField(
        in properties: [NotionPropertySchema],
        type: String,
        label: String,
        issues: inout [ValidationIssue]
    ) -> String? {
        let candidates = propertyNames(in: properties, matching: type)
        switch candidates.count {
        case 0:
            issues.append(ValidationIssue(message: "缺少必填字段类型：\(type)"))
            return nil
        case 1:
            return candidates[0]
        default:
            issues.append(
                ValidationIssue(
                    message: "存在多个\(label)字段：\(candidates.joined(separator: "、"))，请仅保留一个 \(type) 字段用于\(label)。"
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
