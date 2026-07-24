import Foundation

public struct AppMessage: Equatable, Sendable {
    public let key: AppText.Key
    public let arguments: [String]

    public init(_ key: AppText.Key, arguments: [String] = []) {
        self.key = key
        self.arguments = arguments
    }

    public func string(in language: AppLanguage) -> String {
        AppText.string(key, language: language, arguments: arguments)
    }
}
