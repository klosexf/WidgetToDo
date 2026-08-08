import XCTest
@testable import NotionFloatCore

final class AppMessageLocalizationTests: XCTestCase {
    func testDeferredMessageRendersUsingTheCurrentLanguage() {
        let message = AppMessage(.taskSyncFailed, arguments: ["offline"])

        XCTAssertEqual(message.string(in: .simplifiedChinese), "任务同步失败：offline")
        XCTAssertEqual(message.string(in: .english), "Task sync failed: offline")
        XCTAssertEqual(message.string(in: .french), "Échec de la synchronisation des tâches : offline")
    }

    func testHelpAndTabLabelsRenderInTheSelectedLanguage() {
        XCTAssertEqual(AppText.string(.tasksDatabaseHelpTitle, language: .simplifiedChinese), "获取 Tasks Database 链接")
        XCTAssertEqual(AppText.string(.tasksDatabaseHelpTitle, language: .english), "Get a Tasks Database link")
        XCTAssertEqual(AppText.string(.tasksDatabaseHelpTitle, language: .french), "Obtenir un lien Tasks Database")

        XCTAssertEqual(AppText.string(.todoTab, language: .simplifiedChinese), "待办")
        XCTAssertEqual(AppText.string(.todoTab, language: .english), "Tasks")
        XCTAssertEqual(AppText.string(.todoTab, language: .french), "Tâches")
    }

    func testConfigurationAndJournalPromptsRenderInTheSelectedLanguage() {
        XCTAssertEqual(AppText.string(.keychainTokenFound, language: .english), "A token saved in Keychain was found.")
        XCTAssertEqual(AppText.string(.keychainTokenFound, language: .french), "Un jeton enregistré dans le trousseau a été détecté.")
        XCTAssertEqual(AppText.string(.journalReadyToWrite, language: .english), "Start writing")
        XCTAssertEqual(AppText.string(.journalReadyToWrite, language: .french), "Vous pouvez commencer à écrire")
        XCTAssertEqual(AppText.string(.workspaceSynced, language: .english), "Just synced")
        XCTAssertEqual(AppText.string(.workspaceSynced, language: .french), "Synchronisé à l’instant")
    }

    func testTaskUpdateFailureKeepsRawDetailWhileLocalizingItsWrapper() {
        let message = AppMessage(.taskUpdateFailed, arguments: ["HTTP 401"])

        XCTAssertEqual(message.string(in: .simplifiedChinese), "任务更新失败：HTTP 401")
        XCTAssertEqual(message.string(in: .english), "Task update failed: HTTP 401")
        XCTAssertEqual(message.string(in: .french), "Échec de la mise à jour de la tâche : HTTP 401")
    }

    func testPomodoroAccumulationCopyRendersInAllLanguages() {
        let zh = AppText.string(.pomodoroRoundCompleteCopy, language: .simplifiedChinese, arguments: ["25"])
        let en = AppText.string(.pomodoroRoundCompleteCopy, language: .english, arguments: ["25"])
        let fr = AppText.string(.pomodoroRoundCompleteCopy, language: .french, arguments: ["25"])

        XCTAssertEqual(zh, "已将 25 分钟累计到“时长”。")
        XCTAssertEqual(en, "25 minutes were added to “Duration”.")
        XCTAssertEqual(fr, "25 minutes ont été ajoutées à « Durée ».")
    }

    func testPomodoroStartDialogCopyKeepsTaskStatusHint() {
        XCTAssertEqual(AppText.string(.pomodoroStartDialogCopy, language: .simplifiedChinese), "结束后本次时长将累计到“时长”。")
        XCTAssertEqual(AppText.string(.pomodoroStartDialogHint, language: .simplifiedChinese), "不会修改任务状态")
        XCTAssertEqual(AppText.string(.pomodoroStartDialogHint, language: .english), "Task status will not change")
        XCTAssertEqual(AppText.string(.pomodoroStartDialogHint, language: .french), "Le statut de la tâche ne change pas")
    }

    func testPomodoroTaskDurationLabelUsesCumulativePlaceholder() {
        XCTAssertEqual(AppText.string(.pomodoroTaskDurationLabel, language: .simplifiedChinese, arguments: ["70"]), "时长 70 分钟")
        XCTAssertEqual(AppText.string(.pomodoroTaskDurationLabel, language: .english, arguments: ["70"]), "Duration 70 min")
        XCTAssertEqual(AppText.string(.pomodoroTaskDurationLabel, language: .french, arguments: ["70"]), "Durée 70 min")
    }

    func testPomodoroCompleteTaskToggleDefaultsToOffCopyIsAvailable() {
        // 默认关闭语义必须在中英法三语都存在，避免 UI 误用开启态文案。
        let keys: [AppText.Key] = [
            .pomodoroCompleteTaskToggle,
            .pomodoroCompleteTaskToggleOffHint,
            .pomodoroCompleteTaskToggleOnHint,
            .pomodoroKeepIncomplete,
            .pomodoroCompleteTask
        ]
        for key in keys {
            for language in [AppLanguage.simplifiedChinese, .english, .french] {
                let value = AppText.string(key, language: language)
                XCTAssertFalse(value.isEmpty, "pomodoro key \(key.rawValue) must exist in \(language.rawValue)")
            }
        }
    }

    func testCVarArgIntArgumentsAreNotWrappedInBrackets() {
        // AppText.string 的 CVarArg 重载不应把整型参数变成数组描述（如 "[1]"）。
        XCTAssertEqual(AppText.string(.minutesValue, language: .simplifiedChinese, 1), "1 分钟")
        XCTAssertEqual(AppText.string(.minutesValue, language: .english, 1), "1 min")
        XCTAssertEqual(AppText.string(.minutesValue, language: .french, 1), "1 min")

        XCTAssertEqual(AppText.string(.pomodoroStartDialogBegin, language: .simplifiedChinese, 25), "开始 25 分钟专注")
        XCTAssertEqual(AppText.string(.pomodoroEndFocusDialogCopy, language: .simplifiedChinese, 1), "确认后，将 1 分钟累计到“时长”。剩余时间不会计入时长。")
        XCTAssertEqual(AppText.string(.pomodoroSuccessIncomplete, language: .simplifiedChinese, 1), "已将 1 分钟累计到“时长”。任务保持未完成。")
    }

}
