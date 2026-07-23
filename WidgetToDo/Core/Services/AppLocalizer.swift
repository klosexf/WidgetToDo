import Foundation

public enum AppText {
    public enum Key: String, CaseIterable, Hashable, Sendable {
        case languageSettingTitle
        case settingsTitle
        case saveSettings
        case savingLanguageFailed
        case toggleWidget
        case quit
        case appTitle
    }

    private static let translations: [AppLanguage: [Key: String]] = [
        .simplifiedChinese: [
            .languageSettingTitle: "Language",
            .settingsTitle: "设置",
            .saveSettings: "保存设置",
            .savingLanguageFailed: "保存语言设置失败，请稍后重试。",
            .toggleWidget: "显示 / 隐藏 Notion 浮窗",
            .quit: "退出",
            .appTitle: "Notion 浮窗"
        ],
        .english: [
            .languageSettingTitle: "Language",
            .settingsTitle: "Settings",
            .saveSettings: "Save Settings",
            .savingLanguageFailed: "Could not save the language setting. Please try again.",
            .toggleWidget: "Show / Hide Notion Widget",
            .quit: "Quit",
            .appTitle: "Notion Widget"
        ],
        .french: [
            .languageSettingTitle: "Language",
            .settingsTitle: "Paramètres",
            .saveSettings: "Enregistrer les paramètres",
            .savingLanguageFailed: "Impossible d’enregistrer le réglage de langue. Réessayez.",
            .toggleWidget: "Afficher / masquer le widget Notion",
            .quit: "Quitter",
            .appTitle: "Widget Notion"
        ]
    ]

    public static func keys(in language: AppLanguage) -> Set<Key> {
        Set(translations[language, default: [:]].keys)
    }

    public static func string(_ key: Key, language: AppLanguage, _ arguments: CVarArg...) -> String {
        guard let format = translations[language]?[key] else {
            preconditionFailure("Missing translation: \(language.rawValue).\(key.rawValue)")
        }
        return arguments.isEmpty
            ? format
            : String(format: format, locale: language.locale, arguments: arguments)
    }
}
