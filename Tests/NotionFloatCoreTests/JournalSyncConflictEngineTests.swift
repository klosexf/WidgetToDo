import XCTest
@testable import NotionFloatCore

final class JournalSyncConflictEngineTests: XCTestCase {
    func testNoUnsavedEditsAppliesRemote() {
        let resolution = JournalSyncConflictEngine.resolve(
            context: JournalSyncContext(
                localText: "旧内容",
                remoteText: "云端新内容",
                hasUnsavedEdits: false,
                lastSaveFailed: false
            )
        )
        XCTAssertEqual(resolution, .applyRemote)
    }

    func testNoUnsavedEditsAppliesRemoteEvenWhenTextsMatch() {
        let resolution = JournalSyncConflictEngine.resolve(
            context: JournalSyncContext(
                localText: "一致内容",
                remoteText: "一致内容",
                hasUnsavedEdits: false,
                lastSaveFailed: false
            )
        )
        XCTAssertEqual(resolution, .applyRemote)
    }

    func testUnsavedEditsWithHealthySaveKeepsLocal() {
        // 用户在拉取期间继续输入：本地更新，保存链路健康 → 保留本地，等待自动保存推进。
        let resolution = JournalSyncConflictEngine.resolve(
            context: JournalSyncContext(
                localText: "正在输入的新内容",
                remoteText: "刚保存的基线",
                hasUnsavedEdits: true,
                lastSaveFailed: false
            )
        )
        XCTAssertEqual(resolution, .keepLocal)
    }

    func testFailedSaveWithDivergedRemoteRaisesConflict() {
        // 弱网：本地保存失败，云端已被其他端修改 → 真实冲突，交给用户选择。
        let resolution = JournalSyncConflictEngine.resolve(
            context: JournalSyncContext(
                localText: "本地未保存编辑",
                remoteText: "云端另一版本",
                hasUnsavedEdits: true,
                lastSaveFailed: true
            )
        )
        XCTAssertEqual(resolution, .conflict)
    }

    func testFailedSaveWithMatchingRemoteKeepsLocal() {
        // 写入实际成功但响应超时（云端与本地一致）：无需冲突，保留本地即可。
        let resolution = JournalSyncConflictEngine.resolve(
            context: JournalSyncContext(
                localText: "同一份内容",
                remoteText: "同一份内容",
                hasUnsavedEdits: true,
                lastSaveFailed: true
            )
        )
        XCTAssertEqual(resolution, .keepLocal)
    }

    func testPendingSaveAloneNeverRaisesConflict() {
        // 防抖中的高频输入：只要保存链路未失败，同步永不打断输入。
        let resolution = JournalSyncConflictEngine.resolve(
            context: JournalSyncContext(
                localText: "持续输入",
                remoteText: "任意远端",
                hasUnsavedEdits: true,
                lastSaveFailed: false
            )
        )
        XCTAssertEqual(resolution, .keepLocal)
    }
}
