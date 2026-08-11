import Foundation

public struct NotionSelectOption: Codable, Equatable, Sendable {
    public enum Color: String, Codable, Sendable { case `default`, gray, brown, orange, yellow, green, blue, purple, pink, red }
    public let name: String
    public let color: Color
    public init(name: String, color: Color) { self.name = name; self.color = color }
}

public struct TaskChoiceField: Equatable, Sendable {
    public let name: String
    public let options: [NotionSelectOption]
    public init(name: String, options: [NotionSelectOption]) { self.name = name; self.options = options }
}

public struct NotionPropertySchema: Equatable, Sendable {
    public let name: String
    public let type: String
    public let selectOptions: [NotionSelectOption]

    public init(name: String, type: String, selectOptions: [NotionSelectOption] = []) {
        self.name = name
        self.type = type
        self.selectOptions = selectOptions
    }
}
