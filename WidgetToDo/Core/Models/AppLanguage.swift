import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Equatable, Sendable {
    case simplifiedChinese
    case english
    case french

    public static let `default`: Self = .simplifiedChinese

    public var displayName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        case .french: "Français"
        }
    }

    public var locale: Locale {
        switch self {
        case .simplifiedChinese: Locale(identifier: "zh_Hans")
        case .english: Locale(identifier: "en")
        case .french: Locale(identifier: "fr")
        }
    }
}
