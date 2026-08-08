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
        case taskUpdateFailed
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
        case keychainTokenFound
        case journalReadyToWrite
        case journalSynced
        case journalSavingSoon
        case journalSavedToNotion
        case journalAutosaveHint
        case noTasksToday
        case noTasksOnDate
        case workspaceSynced
        case appLoading
        case startupFailed
        case settingsLoadFailed
        case welcomeTitle
        case welcomePrefix
        case welcomeNotion
        case welcomeSuffix
        case welcomeTagline
        case startConfiguration
        case initialConfiguration
        case connectNotion
        case connectNotionSubtitle
        case onboardingDescription
        case notionToken
        case howToGet
        case tokenPrompt
        case tokenStoredSettings
        case tokenStoredOnboarding
        case pasteFullURL
        case tasksDatabaseID
        case tasksDatabase
        case journalDatabaseID
        case journalDatabase
        case tasksDatabasePrompt
        case journalDatabasePrompt
        case resetConfiguration
        case resetConfigurationDescription
        case resetConfigurationConfirmation
        case configurationSaved
        case resettingConfiguration
        case resetConfigurationFailed
        case verifyAndContinue
        case cancel
        case deleteTask
        case deleteTaskConfirmation
        case deleteTaskArchiveMessage
        case backToToday
        case loadingTasks
        case loadingJournal
        case retry
        case editTask
        case newTask
        case taskLabel
        case taskTitleRequired
        case dateLabel
        case estimatedMinutesLabel
        case minutesLabel
        case estimatedMinutesInvalid
        case create
        case save
        case taskUpdated
        case taskDeleted
        case taskCreated
        case taskCreateFailed
        case taskDeleteFailed
        case taskRetryFailed
        case journalSyncFailed
        case journalSaveFailed
        case syncSynced
        case syncSyncing
        case syncFailed
        case syncPending
        case todayTasks
        case completedTasksCount
        case todayJournal
        case wordCount
        case minutesValue
        case settingsSceneHint
        case missingToken
        case invalidTasksDatabaseInput
        case invalidJournalDatabaseInput
        case missingRequiredFieldType
        case duplicateRequiredField
        case fieldMappingFailed
        case pomodoroTaskStartAction
        case pomodoroStartDialogTitle
        case pomodoroStartDialogCopy
        case pomodoroStartDialogHint
        case pomodoroStartDialogCancel
        case pomodoroStartDialogBegin
        case pomodoroStartDialogBeginGeneric
        case pomodoroDurationFieldLabel
        case pomodoroDurationPreset25
        case pomodoroDurationPreset45
        case pomodoroDurationCustom
        case pomodoroDurationCustomPlaceholder
        case pomodoroDurationUnit
        case pomodoroDurationError
        case pomodoroFocusCardMeta
        case pomodoroFocusCardPausedMeta
        case pomodoroAbandon
        case pomodoroPause
        case pomodoroComplete
        case pomodoroPauseDialogTitle
        case pomodoroPauseDialogCopy
        case pomodoroPauseAbandonRound
        case pomodoroResumeFocus
        case pomodoroAbandonDialogTitle
        case pomodoroAbandonDialogCopy
        case pomodoroConfirmAbandon
        case pomodoroEndFocusKicker
        case pomodoroEndFocusDialogCopy
        case pomodoroRecordDuration
        case pomodoroRecordAndComplete
        case pomodoroRoundComplete
        case pomodoroRoundCompleteCopy
        case pomodoroRoundCompleteHint
        case pomodoroKeepIncomplete
        case pomodoroCompleteTask
        case pomodoroDurationAdded
        case pomodoroCompleteTaskToggle
        case pomodoroCompleteTaskToggleOffHint
        case pomodoroCompleteTaskToggleOnHint
        case pomodoroSuccessCompleted
        case pomodoroSuccessIncomplete
        case pomodoroDone
        case pomodoroTaskDurationLabel
        case pomodoroDurationWriteFailed
        case pomodoroRetryDurationWrite
        case pomodoroLater
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
            .taskUpdateFailed: "任务更新失败：%@",
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
            .tasksHelpStep4: "4. 如果你还希望在应用里使用时长，可以额外准备 number 字段；只有当任务数据库里恰好只有 1 个 number 字段时，应用才会自动把它当作时长。",
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
            .journalTab: "日记",
            .keychainTokenFound: "已检测到保存在钥匙串中的令牌。",
            .journalReadyToWrite: "可以开始记录了",
            .journalSynced: "日记已同步",
            .journalSavingSoon: "即将保存...",
            .journalSavedToNotion: "已保存到 Notion",
            .journalAutosaveHint: "2 秒后自动保存",
            .noTasksToday: "今天没有任务",
            .noTasksOnDate: "%@ 没有任务",
            .workspaceSynced: "刚刚同步完成",
            .appLoading: "正在加载 Notion Float...",
            .startupFailed: "启动 Notion Float 失败：%@",
            .settingsLoadFailed: "读取设置失败：%@",
            .welcomeTitle: "欢迎使用 WidgetToDo",
            .welcomePrefix: "一个常驻桌面的",
            .welcomeNotion: "Notion",
            .welcomeSuffix: "小窗口",
            .welcomeTagline: "待办 · 日记 · 一目了然",
            .startConfiguration: "开始配置",
            .initialConfiguration: "初始配置",
            .connectNotion: "连接 Notion",
            .connectNotionSubtitle: "使用你的 Notion 工作区\n同步任务与日记内容",
            .onboardingDescription: "这个版本需要一个 Notion 集成令牌，以及一个任务数据库和一个日记数据库。",
            .notionToken: "Notion Token",
            .howToGet: "如何获取？",
            .tokenPrompt: "输入你的 Notion Token",
            .tokenStoredSettings: "令牌只保存在本机钥匙串。",
            .tokenStoredOnboarding: "令牌只保存在本机钥匙串中，安全加密存储。",
            .pasteFullURL: "粘贴整个 URL 自动提取",
            .tasksDatabaseID: "Tasks Database ID",
            .tasksDatabase: "Tasks Database",
            .journalDatabaseID: "Journal Database ID",
            .journalDatabase: "Journal Database",
            .tasksDatabasePrompt: "任务数据库 ID",
            .journalDatabasePrompt: "日记数据库 ID",
            .resetConfiguration: "初始化配置",
            .resetConfigurationDescription: "清空当前保存的 Notion Token 与数据库配置，完成后返回欢迎页。不会清除本地缓存的任务和日记内容。",
            .resetConfigurationConfirmation: "这会清空当前配置，不会清除本地缓存的任务和日记内容，完成后返回欢迎页。",
            .configurationSaved: "配置已保存。",
            .resettingConfiguration: "正在重置配置...",
            .resetConfigurationFailed: "重置配置失败，请稍后重试。",
            .verifyAndContinue: "验证并继续",
            .cancel: "取消",
            .deleteTask: "删除任务",
            .deleteTaskConfirmation: "删除这个任务？",
            .deleteTaskArchiveMessage: "删除后会在 Notion 中归档该任务，无法在这里直接恢复。",
            .backToToday: "回到今天",
            .loadingTasks: "正在加载任务...",
            .loadingJournal: "正在加载日记...",
            .retry: "重试",
            .editTask: "编辑任务",
            .newTask: "新建任务",
            .taskLabel: "任务",
            .taskTitleRequired: "任务标题不能为空。",
            .dateLabel: "日期",
            .estimatedMinutesLabel: "时长",
            .minutesLabel: "分钟",
            .estimatedMinutesInvalid: "时长需填写为大于 0 的分钟数",
            .create: "创建",
            .save: "保存",
            .taskUpdated: "任务已更新",
            .taskDeleted: "任务已删除",
            .taskCreated: "已同步到 Notion",
            .taskCreateFailed: "创建失败：%@",
            .taskDeleteFailed: "任务删除失败：%@",
            .taskRetryFailed: "重试失败：%@",
            .journalSyncFailed: "日记同步失败：%@",
            .journalSaveFailed: "日记保存失败：%@",
            .syncSynced: "已同步",
            .syncSyncing: "同步中",
            .syncFailed: "失败",
            .syncPending: "待同步",
            .todayTasks: "今日待办",
            .completedTasksCount: "%@/%@ 已完成",
            .todayJournal: "今日日记",
            .wordCount: "%@ 字",
            .minutesValue: "%@ 分钟",
            .settingsSceneHint: "使用菜单栏图标来显示或隐藏悬浮面板。",
            .missingToken: "请填写 Notion Token。",
            .invalidTasksDatabaseInput: "Tasks Database ID 或 URL 无效。",
            .invalidJournalDatabaseInput: "Journal Database ID 或 URL 无效。",
            .missingRequiredFieldType: "缺少必填字段类型：%@",
            .duplicateRequiredField: "存在多个%@字段：%@；请仅保留一个 %@ 字段。",
            .fieldMappingFailed: "数据库字段映射解析失败。",
            .pomodoroTaskStartAction: "计时",
            .pomodoroStartDialogTitle: "开始进行专注",
            .pomodoroStartDialogCopy: "结束后本次时长将累计到“时长”。",
            .pomodoroStartDialogHint: "不会修改任务状态",
            .pomodoroStartDialogCancel: "取消",
            .pomodoroStartDialogBegin: "开始 %@ 分钟专注",
            .pomodoroStartDialogBeginGeneric: "开始专注",
            .pomodoroDurationFieldLabel: "本轮时长",
            .pomodoroDurationPreset25: "25 分钟",
            .pomodoroDurationPreset45: "45 分钟",
            .pomodoroDurationCustom: "自定义",
            .pomodoroDurationCustomPlaceholder: "输入分钟数（1–480）",
            .pomodoroDurationUnit: "分钟",
            .pomodoroDurationError: "请输入 1 到 480 之间的整数分钟数",
            .pomodoroFocusCardMeta: "专注中 · 本轮 %@ 分钟",
            .pomodoroFocusCardPausedMeta: "已暂停 · 计时不会继续",
            .pomodoroAbandon: "放弃",
            .pomodoroPause: "暂停",
            .pomodoroComplete: "完成",
            .pomodoroPauseDialogTitle: "专注已暂停",
            .pomodoroPauseDialogCopy: "计时已暂停，当前任务仍保持未完成。你可以继续专注，或选择放弃本轮。",
            .pomodoroPauseAbandonRound: "放弃本轮",
            .pomodoroResumeFocus: "继续专注",
            .pomodoroAbandonDialogTitle: "确认放弃？",
            .pomodoroAbandonDialogCopy: "放弃后，本轮专注不会记录任何时长，任务会继续保留在列表中。",
            .pomodoroConfirmAbandon: "确认放弃",
            .pomodoroEndFocusKicker: "结束专注",
            .pomodoroEndFocusDialogCopy: "确认后，将 %@ 分钟累计到“时长”。剩余时间不会计入时长。",
            .pomodoroRecordDuration: "记录时长",
            .pomodoroRecordAndComplete: "记录并完成任务",
            .pomodoroRoundComplete: "本轮已完成",
            .pomodoroRoundCompleteCopy: "已将 %@ 分钟累计到“时长”。",
            .pomodoroRoundCompleteHint: "可同时完成任务，或保持未完成继续后续专注",
            .pomodoroKeepIncomplete: "保持未完成",
            .pomodoroCompleteTask: "完成任务",
            .pomodoroDurationAdded: "已将 %@ 分钟累计到“时长”。",
            .pomodoroCompleteTaskToggle: "同时完成任务",
            .pomodoroCompleteTaskToggleOffHint: "关闭则只记录本轮时长，任务保持未完成",
            .pomodoroCompleteTaskToggleOnHint: "开启则记录时长，且任务设为已完成",
            .pomodoroSuccessCompleted: "已将 %@ 分钟累计到“时长”。任务已完成。",
            .pomodoroSuccessIncomplete: "已将 %@ 分钟累计到“时长”。任务保持未完成。",
            .pomodoroDone: "知道了",
            .pomodoroTaskDurationLabel: "时长 %@ 分钟",
            .pomodoroDurationWriteFailed: "本轮已结束，但时长未能写入。",
            .pomodoroRetryDurationWrite: "重试写入",
            .pomodoroLater: "稍后决定"
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
            .taskUpdateFailed: "Task update failed: %@",
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
            .tasksHelpStep4: "4. To use duration, add a number property. The app uses it only when the Tasks Database has exactly one number property.",
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
            .journalTab: "Journal",
            .keychainTokenFound: "A token saved in Keychain was found.",
            .journalReadyToWrite: "Start writing",
            .journalSynced: "Journal synced",
            .journalSavingSoon: "Saving soon...",
            .journalSavedToNotion: "Saved to Notion",
            .journalAutosaveHint: "Auto-saves in 2 seconds",
            .noTasksToday: "No tasks today",
            .noTasksOnDate: "No tasks on %@",
            .workspaceSynced: "Just synced",
            .appLoading: "Loading Notion Float...",
            .startupFailed: "Could not start Notion Float: %@",
            .settingsLoadFailed: "Could not load settings: %@",
            .welcomeTitle: "Welcome to WidgetToDo",
            .welcomePrefix: "A desktop",
            .welcomeNotion: "Notion",
            .welcomeSuffix: "widget",
            .welcomeTagline: "Tasks · Journal · At a glance",
            .startConfiguration: "Get started",
            .initialConfiguration: "Initial Setup",
            .connectNotion: "Connect Notion",
            .connectNotionSubtitle: "Use your Notion workspace\nto sync tasks and journal entries",
            .onboardingDescription: "This version needs a Notion integration token, a tasks database, and a journal database.",
            .notionToken: "Notion Token",
            .howToGet: "How to get it?",
            .tokenPrompt: "Enter your Notion Token",
            .tokenStoredSettings: "Your token is stored only in the local Keychain.",
            .tokenStoredOnboarding: "Your token is stored only in the local Keychain with secure encryption.",
            .pasteFullURL: "Paste a full URL to extract it",
            .tasksDatabaseID: "Tasks Database ID",
            .tasksDatabase: "Tasks Database",
            .journalDatabaseID: "Journal Database ID",
            .journalDatabase: "Journal Database",
            .tasksDatabasePrompt: "Tasks Database ID",
            .journalDatabasePrompt: "Journal Database ID",
            .resetConfiguration: "Reset Configuration",
            .resetConfigurationDescription: "Clear the saved Notion Token and database configuration, then return to the welcome page. Local task and journal caches are not deleted.",
            .resetConfigurationConfirmation: "This clears the current configuration and returns to the welcome page. Local task and journal caches are not deleted.",
            .configurationSaved: "Configuration saved.",
            .resettingConfiguration: "Resetting configuration...",
            .resetConfigurationFailed: "Could not reset configuration. Please try again.",
            .verifyAndContinue: "Verify and continue",
            .cancel: "Cancel",
            .deleteTask: "Delete Task",
            .deleteTaskConfirmation: "Delete this task?",
            .deleteTaskArchiveMessage: "This archives the task in Notion and it cannot be restored here.",
            .backToToday: "Today",
            .loadingTasks: "Loading tasks...",
            .loadingJournal: "Loading journal...",
            .retry: "Retry",
            .editTask: "Edit Task",
            .newTask: "New Task",
            .taskLabel: "Task",
            .taskTitleRequired: "Task title is required.",
            .dateLabel: "Date",
            .estimatedMinutesLabel: "Duration",
            .minutesLabel: "minutes",
            .estimatedMinutesInvalid: "Duration must be a positive number of minutes",
            .create: "Create",
            .save: "Save",
            .taskUpdated: "Task updated",
            .taskDeleted: "Task deleted",
            .taskCreated: "Synced to Notion",
            .taskCreateFailed: "Could not create task: %@",
            .taskDeleteFailed: "Could not delete task: %@",
            .taskRetryFailed: "Retry failed: %@",
            .journalSyncFailed: "Journal sync failed: %@",
            .journalSaveFailed: "Could not save journal: %@",
            .syncSynced: "Synced",
            .syncSyncing: "Syncing",
            .syncFailed: "Failed",
            .syncPending: "Waiting to sync",
            .todayTasks: "Today's tasks",
            .completedTasksCount: "%@/%@ completed",
            .todayJournal: "Today's journal",
            .wordCount: "%@ words",
            .minutesValue: "%@ min",
            .settingsSceneHint: "Use the menu bar icon to show or hide the floating panel.",
            .missingToken: "Enter a Notion Token.",
            .invalidTasksDatabaseInput: "The Tasks Database ID or URL is invalid.",
            .invalidJournalDatabaseInput: "The Journal Database ID or URL is invalid.",
            .missingRequiredFieldType: "Missing required property type: %@",
            .duplicateRequiredField: "Multiple %@ properties were found: %@. Keep exactly one %@ property.",
            .fieldMappingFailed: "Could not resolve the database field mapping.",
            .pomodoroTaskStartAction: "Timer",
            .pomodoroStartDialogTitle: "Start a focus round",
            .pomodoroStartDialogCopy: "When this round ends, its time will be added to “Duration”.",
            .pomodoroStartDialogHint: "Task status will not change",
            .pomodoroStartDialogCancel: "Cancel",
            .pomodoroStartDialogBegin: "Start a %@-minute focus",
            .pomodoroStartDialogBeginGeneric: "Start focus",
            .pomodoroDurationFieldLabel: "Round duration",
            .pomodoroDurationPreset25: "25 minutes",
            .pomodoroDurationPreset45: "45 minutes",
            .pomodoroDurationCustom: "Custom",
            .pomodoroDurationCustomPlaceholder: "Enter minutes (1–480)",
            .pomodoroDurationUnit: "minutes",
            .pomodoroDurationError: "Enter a whole number of minutes between 1 and 480",
            .pomodoroFocusCardMeta: "Focusing · %@ min this round",
            .pomodoroFocusCardPausedMeta: "Paused · the timer is not running",
            .pomodoroAbandon: "Abandon",
            .pomodoroPause: "Pause",
            .pomodoroComplete: "Done",
            .pomodoroPauseDialogTitle: "Focus paused",
            .pomodoroPauseDialogCopy: "The timer is paused and the task stays incomplete. You can resume the round or abandon it.",
            .pomodoroPauseAbandonRound: "Abandon round",
            .pomodoroResumeFocus: "Resume focus",
            .pomodoroAbandonDialogTitle: "Abandon this round?",
            .pomodoroAbandonDialogCopy: "Abandoning stops the timer without recording any time. The task stays in the list.",
            .pomodoroConfirmAbandon: "Abandon",
            .pomodoroEndFocusKicker: "End focus",
            .pomodoroEndFocusDialogCopy: "%@ minutes will be added to “Duration”. Remaining time is not counted.",
            .pomodoroRecordDuration: "Record time",
            .pomodoroRecordAndComplete: "Record and complete task",
            .pomodoroRoundComplete: "Round complete",
            .pomodoroRoundCompleteCopy: "%@ minutes were added to “Duration”.",
            .pomodoroRoundCompleteHint: "You can also complete the task, or keep it incomplete for another round",
            .pomodoroKeepIncomplete: "Keep incomplete",
            .pomodoroCompleteTask: "Complete task",
            .pomodoroDurationAdded: "%@ minutes were added to “Duration”.",
            .pomodoroCompleteTaskToggle: "Also complete the task",
            .pomodoroCompleteTaskToggleOffHint: "Off records only this round’s time and keeps the task incomplete",
            .pomodoroCompleteTaskToggleOnHint: "On records the time and marks the task complete",
            .pomodoroSuccessCompleted: "%@ minutes were added to “Duration”. The task is complete.",
            .pomodoroSuccessIncomplete: "%@ minutes were added to “Duration”. The task stays incomplete.",
            .pomodoroDone: "Got it",
            .pomodoroTaskDurationLabel: "Duration %@ min",
            .pomodoroDurationWriteFailed: "The round ended, but the time could not be saved.",
            .pomodoroRetryDurationWrite: "Retry save",
            .pomodoroLater: "Decide later"
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
            .taskUpdateFailed: "Échec de la mise à jour de la tâche : %@",
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
            .tasksHelpStep4: "4. Pour utiliser une durée, ajoutez une propriété number. L’app ne l’utilise que si la base Tasks contient exactement une propriété number.",
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
            .journalTab: "Journal",
            .keychainTokenFound: "Un jeton enregistré dans le trousseau a été détecté.",
            .journalReadyToWrite: "Vous pouvez commencer à écrire",
            .journalSynced: "Journal synchronisé",
            .journalSavingSoon: "Enregistrement imminent…",
            .journalSavedToNotion: "Enregistré dans Notion",
            .journalAutosaveHint: "Enregistrement automatique dans 2 secondes",
            .noTasksToday: "Aucune tâche aujourd’hui",
            .noTasksOnDate: "Aucune tâche le %@",
            .workspaceSynced: "Synchronisé à l’instant",
            .appLoading: "Chargement de Notion Float…",
            .startupFailed: "Impossible de démarrer Notion Float : %@",
            .settingsLoadFailed: "Impossible de charger les paramètres : %@",
            .welcomeTitle: "Bienvenue dans WidgetToDo",
            .welcomePrefix: "Un widget",
            .welcomeNotion: "Notion",
            .welcomeSuffix: "pour le bureau",
            .welcomeTagline: "Tâches · Journal · En un coup d’œil",
            .startConfiguration: "Commencer la configuration",
            .initialConfiguration: "Configuration initiale",
            .connectNotion: "Connecter Notion",
            .connectNotionSubtitle: "Utilisez votre espace Notion\npour synchroniser tâches et journal",
            .onboardingDescription: "Cette version nécessite un jeton d’intégration Notion, une base de tâches et une base de journal.",
            .notionToken: "Jeton Notion",
            .howToGet: "Comment l’obtenir ?",
            .tokenPrompt: "Saisissez votre jeton Notion",
            .tokenStoredSettings: "Votre jeton est stocké uniquement dans le trousseau local.",
            .tokenStoredOnboarding: "Votre jeton est stocké uniquement dans le trousseau local, de façon chiffrée.",
            .pasteFullURL: "Collez une URL complète pour l’extraire",
            .tasksDatabaseID: "ID de la base Tasks",
            .tasksDatabase: "Base Tasks",
            .journalDatabaseID: "ID de la base Journal",
            .journalDatabase: "Base Journal",
            .tasksDatabasePrompt: "ID de la base Tasks",
            .journalDatabasePrompt: "ID de la base Journal",
            .resetConfiguration: "Réinitialiser la configuration",
            .resetConfigurationDescription: "Efface le jeton Notion et la configuration des bases, puis revient à l’accueil. Les caches locaux des tâches et du journal ne sont pas supprimés.",
            .resetConfigurationConfirmation: "Cette action efface la configuration actuelle puis revient à l’accueil. Les caches locaux des tâches et du journal ne sont pas supprimés.",
            .configurationSaved: "Configuration enregistrée.",
            .resettingConfiguration: "Réinitialisation de la configuration…",
            .resetConfigurationFailed: "Impossible de réinitialiser la configuration. Réessayez.",
            .verifyAndContinue: "Vérifier et continuer",
            .cancel: "Annuler",
            .deleteTask: "Supprimer la tâche",
            .deleteTaskConfirmation: "Supprimer cette tâche ?",
            .deleteTaskArchiveMessage: "La tâche sera archivée dans Notion et ne pourra pas être restaurée ici.",
            .backToToday: "Aujourd’hui",
            .loadingTasks: "Chargement des tâches…",
            .loadingJournal: "Chargement du journal…",
            .retry: "Réessayer",
            .editTask: "Modifier la tâche",
            .newTask: "Nouvelle tâche",
            .taskLabel: "Tâche",
            .taskTitleRequired: "Le titre de la tâche est obligatoire.",
            .dateLabel: "Date",
            .estimatedMinutesLabel: "Durée",
            .minutesLabel: "minutes",
            .estimatedMinutesInvalid: "La durée doit être un nombre positif de minutes",
            .create: "Créer",
            .save: "Enregistrer",
            .taskUpdated: "Tâche mise à jour",
            .taskDeleted: "Tâche supprimée",
            .taskCreated: "Synchronisé avec Notion",
            .taskCreateFailed: "Impossible de créer la tâche : %@",
            .taskDeleteFailed: "Impossible de supprimer la tâche : %@",
            .taskRetryFailed: "Échec de la nouvelle tentative : %@",
            .journalSyncFailed: "Échec de la synchronisation du journal : %@",
            .journalSaveFailed: "Impossible d’enregistrer le journal : %@",
            .syncSynced: "Synchronisé",
            .syncSyncing: "Synchronisation",
            .syncFailed: "Échec",
            .syncPending: "En attente de synchronisation",
            .todayTasks: "Tâches du jour",
            .completedTasksCount: "%@/%@ terminées",
            .todayJournal: "Journal du jour",
            .wordCount: "%@ mots",
            .minutesValue: "%@ min",
            .settingsSceneHint: "Utilisez l’icône de la barre des menus pour afficher ou masquer le panneau flottant.",
            .missingToken: "Saisissez un jeton Notion.",
            .invalidTasksDatabaseInput: "L’ID ou l’URL de la base Tasks est invalide.",
            .invalidJournalDatabaseInput: "L’ID ou l’URL de la base Journal est invalide.",
            .missingRequiredFieldType: "Type de propriété requis manquant : %@",
            .duplicateRequiredField: "Plusieurs propriétés %@ ont été trouvées : %@. Conservez exactement une propriété %@.",
            .fieldMappingFailed: "Impossible de résoudre le mappage des champs de la base.",
            .pomodoroTaskStartAction: "Minuteur",
            .pomodoroStartDialogTitle: "Démarrer une session de concentration",
            .pomodoroStartDialogCopy: "À la fin de la session, sa durée sera ajoutée à « Durée ».",
            .pomodoroStartDialogHint: "Le statut de la tâche ne change pas",
            .pomodoroStartDialogCancel: "Annuler",
            .pomodoroStartDialogBegin: "Démarrer %@ min de concentration",
            .pomodoroStartDialogBeginGeneric: "Démarrer la concentration",
            .pomodoroDurationFieldLabel: "Durée de la session",
            .pomodoroDurationPreset25: "25 minutes",
            .pomodoroDurationPreset45: "45 minutes",
            .pomodoroDurationCustom: "Personnalisé",
            .pomodoroDurationCustomPlaceholder: "Saisir les minutes (1–480)",
            .pomodoroDurationUnit: "minutes",
            .pomodoroDurationError: "Saisissez un nombre entier de minutes entre 1 et 480",
            .pomodoroFocusCardMeta: "Concentration · %@ min cette session",
            .pomodoroFocusCardPausedMeta: "En pause · le minuteur ne tourne plus",
            .pomodoroAbandon: "Abandonner",
            .pomodoroPause: "Pause",
            .pomodoroComplete: "Terminer",
            .pomodoroPauseDialogTitle: "Concentration en pause",
            .pomodoroPauseDialogCopy: "Le minuteur est en pause et la tâche reste incomplète. Vous pouvez reprendre la session ou l’abandonner.",
            .pomodoroPauseAbandonRound: "Abandonner la session",
            .pomodoroResumeFocus: "Reprendre la concentration",
            .pomodoroAbandonDialogTitle: "Abandonner cette session ?",
            .pomodoroAbandonDialogCopy: "Abandonner arrête le minuteur sans enregistrer de durée. La tâche reste dans la liste.",
            .pomodoroConfirmAbandon: "Abandonner",
            .pomodoroEndFocusKicker: "Fin de la concentration",
            .pomodoroEndFocusDialogCopy: "%@ minutes seront ajoutées à « Durée ». Le temps restant n’est pas compté.",
            .pomodoroRecordDuration: "Enregistrer la durée",
            .pomodoroRecordAndComplete: "Enregistrer et terminer la tâche",
            .pomodoroRoundComplete: "Session terminée",
            .pomodoroRoundCompleteCopy: "%@ minutes ont été ajoutées à « Durée ».",
            .pomodoroRoundCompleteHint: "Vous pouvez aussi terminer la tâche, ou la laisser incomplète pour une autre session",
            .pomodoroKeepIncomplete: "Laisser incomplète",
            .pomodoroCompleteTask: "Terminer la tâche",
            .pomodoroDurationAdded: "%@ minutes ont été ajoutées à « Durée ».",
            .pomodoroCompleteTaskToggle: "Terminer aussi la tâche",
            .pomodoroCompleteTaskToggleOffHint: "Désactivé : seule la durée de la session est enregistrée, la tâche reste incomplète",
            .pomodoroCompleteTaskToggleOnHint: "Activé : enregistre la durée et marque la tâche comme terminée",
            .pomodoroSuccessCompleted: "%@ minutes ont été ajoutées à « Durée ». La tâche est terminée.",
            .pomodoroSuccessIncomplete: "%@ minutes ont été ajoutées à « Durée ». La tâche reste incomplète.",
            .pomodoroDone: "J’ai compris",
            .pomodoroTaskDurationLabel: "Durée %@ min",
            .pomodoroDurationWriteFailed: "La session est terminée, mais la durée n’a pas pu être enregistrée.",
            .pomodoroRetryDurationWrite: "Réessayer l’enregistrement",
            .pomodoroLater: "Décider plus tard"
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
