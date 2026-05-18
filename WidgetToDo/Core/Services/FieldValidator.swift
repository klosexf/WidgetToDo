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

public enum FieldValidator {
    public static func validate(_ properties: [NotionPropertySchema], for kind: DataSourceKind) -> [ValidationIssue] {
        let propertyMap = Dictionary(uniqueKeysWithValues: properties.map { ($0.name, $0.type) })

        let requiredFields: [(name: String, type: String)] = switch kind {
        case .tasks:
            [("Name", "title"), ("Date", "date"), ("Done", "checkbox")]
        case .journal:
            [("Name", "title"), ("Date", "date")]
        }

        return requiredFields.compactMap { field in
            guard propertyMap[field.name] != field.type else {
                return nil
            }

            return ValidationIssue(message: "缺少必填字段：\(field.name)(\(field.type))")
        }
    }
}
