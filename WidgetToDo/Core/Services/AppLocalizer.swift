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
        case taskSyncFailed
        case close
        case openNotion
        case openNotionIntegrations
        case notionTokenHelpTitle
        case tokenHelpStep1
        case tokenHelpStep2
        case tokenHelpStep3
        case tokenHelpStep4
        case tasksDatabaseHelpTitle
        case tasksHelpStep1
        case tasksHelpStep2
        case tasksHelpStep3
        case tasksHelpStep4
        case tasksHelpStep5
        case tasksHelpStep6
        case journalDatabaseHelpTitle
        case journalHelpStep1
        case journalHelpStep2
        case journalHelpStep3
        case journalHelpStep4
        case journalHelpStep5
        case journalHelpStep6
        case journalHelpStep7
        case todoTab
        case journalTab
    }

    private static let translations: [AppLanguage: [Key: String]] = [
        .simplifiedChinese: [
            .languageSettingTitle: "Language",
            .settingsTitle: "设置",
            .saveSettings: "保存设置",
            .savingLanguageFailed: "保存语言设置失败，请稍后重试。",
            .toggleWidget: "显示 / 隐藏 Notion 浮窗",
            .quit: "退出",
            .appTitle: "Notion 浮窗",
            .taskSyncFailed: "任务同步失败：%@",
            .close: "关闭",
            .openNotion: "打开 Notion",
            .openNotionIntegrations: "打开 Notion integrations",
            .notionTokenHelpTitle: "获取 Notion Token",
            .tokenHelpStep1: "1. 打开 Notion 的 My integrations，创建一个 Internal Integration。",
            .tokenHelpStep2: "2. 在该 integration 的 Configuration 页面复制 Installation access token。",
            .tokenHelpStep3: "3. 打开 Tasks 和 Journal 数据库右上角菜单，把这个 integration 添加到 Connections。",
            .tokenHelpStep4: "4. 回到这里粘贴 token，并把两个数据库的完整 URL 粘贴到对应输入框。",
            .tasksDatabaseHelpTitle: "获取 Tasks Database 链接",
            .tasksHelpStep1: "1. 在 Notion 中打开你的 Tasks Database，确保进入的是这个任务数据库本身，而不是某个单独页面。",
            .tasksHelpStep2: "2. 如果当前看到的是嵌入在页面里的数据库视图，先点击数据库标题或“Open as full page”，切到数据库完整页面。",
            .tasksHelpStep3: "3. 这个任务数据库至少需要这些字段类型：1 个 title、1 个 date、1 个 checkbox。字段名可以自定义，但每种必填类型只能有 1 个，否则应用无法判断该用哪个字段。",
            .tasksHelpStep4: "4. 如果你还希望在应用里使用预计时长，可以额外准备 number 字段；只有当任务数据库里恰好只有 1 个 number 字段时，应用才会自动把它当作预计时长。",
            .tasksHelpStep5: "5. 在右上角点击“分享”或页面菜单，选择“复制链接”。也可以直接复制浏览器地址栏中的完整链接。",
            .tasksHelpStep6: "6. 把完整链接粘贴到 Tasks Database ID 输入框，应用会自动提取其中的数据库 ID。",
            .journalDatabaseHelpTitle: "获取 Journal Database 链接",
            .journalHelpStep1: "1. 在 Notion 中打开你的 Journal Database，确认这是用于保存日记条目的数据库。",
            .journalHelpStep2: "2. 如果你现在看到的是某个日记页面里的 linked database，先打开数据库原始页面，避免复制错普通页面链接。",
            .journalHelpStep3: "3. 这个日记数据库至少需要这些字段类型：1 个 title、1 个 date。字段名可以自定义，但每种必填类型只能有 1 个，否则应用无法判断该用哪个字段。",
            .journalHelpStep4: "4. 日记正文会自动保存到对应日记页面中，不需要额外创建文本字段。",
            .journalHelpStep5: "5. 日记推荐使用画廊视图展示，便于浏览和回顾。",
            .journalHelpStep6: "6. 通过右上角“分享”里的“复制链接”，或直接复制地址栏中的完整链接，拿到 Journal Database 的 URL。",
            .journalHelpStep7: "7. 把这个完整链接粘贴到 Journal Database ID 输入框，应用会自动解析并填入正确的数据库 ID。",
            .todoTab: "待办",
            .journalTab: "日记"
        ],
        .english: [
            .languageSettingTitle: "Language",
            .settingsTitle: "Settings",
            .saveSettings: "Save Settings",
            .savingLanguageFailed: "Could not save the language setting. Please try again.",
            .toggleWidget: "Show / Hide Notion Widget",
            .quit: "Quit",
            .appTitle: "Notion Widget",
            .taskSyncFailed: "Task sync failed: %@",
            .close: "Close",
            .openNotion: "Open Notion",
            .openNotionIntegrations: "Open Notion integrations",
            .notionTokenHelpTitle: "Get a Notion Token",
            .tokenHelpStep1: "1. Open Notion My integrations and create an Internal Integration.",
            .tokenHelpStep2: "2. Copy the Installation access token from that integration’s Configuration page.",
            .tokenHelpStep3: "3. Open the top-right menu of the Tasks and Journal databases, then add this integration under Connections.",
            .tokenHelpStep4: "4. Paste the token here, then paste each database’s full URL into its corresponding field.",
            .tasksDatabaseHelpTitle: "Get a Tasks Database link",
            .tasksHelpStep1: "1. Open your Tasks Database in Notion and make sure you are on the database itself, not an individual page.",
            .tasksHelpStep2: "2. If it is an embedded database view, select the database title or “Open as full page” to open the full database.",
            .tasksHelpStep3: "3. The Tasks Database needs one title, one date, and one checkbox property. Names may be customized, but there must be exactly one of each required type.",
            .tasksHelpStep4: "4. To use estimated time, add a number property. The app uses it only when the Tasks Database has exactly one number property.",
            .tasksHelpStep5: "5. Use Share or the page menu in the upper-right corner and choose Copy link. You can also copy the full browser URL.",
            .tasksHelpStep6: "6. Paste the full link into Tasks Database ID; the app extracts the database ID automatically.",
            .journalDatabaseHelpTitle: "Get a Journal Database link",
            .journalHelpStep1: "1. Open your Journal Database in Notion and confirm it stores journal entries.",
            .journalHelpStep2: "2. If you see a linked database inside a journal page, open the original database first to avoid copying a page link.",
            .journalHelpStep3: "3. The Journal Database needs one title and one date property. Names may be customized, but there must be exactly one of each required type.",
            .journalHelpStep4: "4. Journal text is saved in the corresponding Notion page; no extra text property is needed.",
            .journalHelpStep5: "5. A gallery view is recommended for easier browsing and review.",
            .journalHelpStep6: "6. Use Copy link in Share, or copy the full browser URL, to get the Journal Database URL.",
            .journalHelpStep7: "7. Paste the full link into Journal Database ID; the app extracts and fills the correct database ID.",
            .todoTab: "Tasks",
            .journalTab: "Journal"
        ],
        .french: [
            .languageSettingTitle: "Language",
            .settingsTitle: "Paramètres",
            .saveSettings: "Enregistrer les paramètres",
            .savingLanguageFailed: "Impossible d’enregistrer le réglage de langue. Réessayez.",
            .toggleWidget: "Afficher / masquer le widget Notion",
            .quit: "Quitter",
            .appTitle: "Widget Notion",
            .taskSyncFailed: "Échec de la synchronisation des tâches : %@",
            .close: "Fermer",
            .openNotion: "Ouvrir Notion",
            .openNotionIntegrations: "Ouvrir les intégrations Notion",
            .notionTokenHelpTitle: "Obtenir un jeton Notion",
            .tokenHelpStep1: "1. Ouvrez My integrations dans Notion et créez une intégration interne.",
            .tokenHelpStep2: "2. Copiez le jeton d’accès d’installation dans la page Configuration de cette intégration.",
            .tokenHelpStep3: "3. Ouvrez le menu en haut à droite des bases Tasks et Journal, puis ajoutez cette intégration dans Connections.",
            .tokenHelpStep4: "4. Collez le jeton ici, puis l’URL complète de chaque base dans le champ correspondant.",
            .tasksDatabaseHelpTitle: "Obtenir un lien Tasks Database",
            .tasksHelpStep1: "1. Ouvrez votre base Tasks dans Notion et vérifiez que vous êtes sur la base elle-même, et non sur une page individuelle.",
            .tasksHelpStep2: "2. S’il s’agit d’une vue de base intégrée, ouvrez le titre de la base ou « Open as full page » pour accéder à la base complète.",
            .tasksHelpStep3: "3. La base Tasks requiert une propriété title, date et checkbox. Les noms sont libres, mais il doit y avoir exactement une propriété de chaque type requis.",
            .tasksHelpStep4: "4. Pour utiliser une durée estimée, ajoutez une propriété number. L’app ne l’utilise que si la base Tasks contient exactement une propriété number.",
            .tasksHelpStep5: "5. Dans Share ou le menu de page en haut à droite, choisissez Copier le lien. Vous pouvez aussi copier l’URL complète du navigateur.",
            .tasksHelpStep6: "6. Collez le lien complet dans Tasks Database ID ; l’app extrait automatiquement l’identifiant de la base.",
            .journalDatabaseHelpTitle: "Obtenir un lien Journal Database",
            .journalHelpStep1: "1. Ouvrez votre base Journal dans Notion et confirmez qu’elle stocke les entrées de journal.",
            .journalHelpStep2: "2. Si vous voyez une base liée dans une page de journal, ouvrez d’abord la base d’origine afin de ne pas copier un lien de page.",
            .journalHelpStep3: "3. La base Journal requiert une propriété title et date. Les noms sont libres, mais il doit y avoir exactement une propriété de chaque type requis.",
            .journalHelpStep4: "4. Le texte du journal est enregistré dans la page Notion correspondante ; aucune propriété de texte supplémentaire n’est nécessaire.",
            .journalHelpStep5: "5. Une vue galerie est recommandée pour faciliter la consultation.",
            .journalHelpStep6: "6. Utilisez Copier le lien dans Share, ou copiez l’URL complète du navigateur, pour obtenir l’URL de la base Journal.",
            .journalHelpStep7: "7. Collez le lien complet dans Journal Database ID ; l’app extrait et renseigne l’identifiant correct.",
            .todoTab: "Tâches",
            .journalTab: "Journal"
        ]
    ]

    public static func keys(in language: AppLanguage) -> Set<Key> {
        Set(translations[language, default: [:]].keys)
    }

    public static func string(_ key: Key, language: AppLanguage, _ arguments: CVarArg...) -> String {
        string(key, language: language, arguments: arguments.map { String(describing: $0) })
    }

    public static func string(_ key: Key, language: AppLanguage, arguments: [String]) -> String {
        guard let format = translations[language]?[key] else {
            preconditionFailure("Missing translation: \(language.rawValue).\(key.rawValue)")
        }
        return arguments.isEmpty
            ? format
            : String(format: format, locale: language.locale, arguments: arguments)
    }
}
