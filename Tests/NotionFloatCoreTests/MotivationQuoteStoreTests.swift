import XCTest
@testable import NotionFloatCore

/// 覆盖 `MotivationQuoteStore` 的真实磁盘读写：默认值、往返、损坏降级、独立文件。
/// 全部打真临时目录，不 mock 文件系统——降级行为只有在真 I/O 下才可验证。
final class MotivationQuoteStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MotivationQuoteStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testFreshStoreDefaultsToDisabledWithEmptyText() async {
        let store = MotivationQuoteStore(baseURL: directory)
        let quote = await store.snapshot()
        XCTAssertFalse(quote.enabled, "激励话术默认必须是关闭状态")
        XCTAssertEqual(quote.text, "")
    }

    func testFlagsAndTextRoundTripThroughDisk() async {
        let store = MotivationQuoteStore(baseURL: directory)
        await store.setEnabled(true)
        await store.setText("先完成，再完美。")

        // 换一个实例重新读，证明真的落盘而不是留在内存里
        let reopened = MotivationQuoteStore(baseURL: directory)
        let quote = await reopened.snapshot()
        XCTAssertTrue(quote.enabled)
        XCTAssertEqual(quote.text, "先完成，再完美。")
    }

    func testSavedTextIsNormalizedToASingleLine() async {
        let store = MotivationQuoteStore(baseURL: directory)
        await store.setText("  先把事做完\n再谈完美  ")
        let quote = await store.snapshot()
        XCTAssertEqual(quote.text, "先把事做完 再谈完美")
    }

    func testCorruptFileDegradesToDefaultWithoutTrapping() async {
        try? "这不是 json".data(using: .utf8)?
            .write(to: directory.appendingPathComponent("motivation-quote.json"))

        let store = MotivationQuoteStore(baseURL: directory)
        let quote = await store.snapshot()
        XCTAssertFalse(quote.enabled)
        XCTAssertEqual(quote.text, "")
    }

    func testStoreUsesItsOwnDedicatedFile() async {
        let sentinel = directory.appendingPathComponent("settings.json")
        try? "{\"untouched\":true}".data(using: .utf8)?.write(to: sentinel)

        let store = MotivationQuoteStore(baseURL: directory)
        await store.setEnabled(true)

        XCTAssertEqual(
            String(data: try! Data(contentsOf: sentinel), encoding: .utf8),
            "{\"untouched\":true}",
            "不得写入或覆盖 settings.json"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: directory.appendingPathComponent("motivation-quote.json").path)
        )
    }

    /// 关闭开关只是不显示，绝不能清空用户写过的话术：
    /// 重新开启时必须还能看到原文。
    func testDisablingKeepsSavedTextForNextEnable() async {
        let store = MotivationQuoteStore(baseURL: directory)
        await store.setText("先完成，再完美。")
        await store.setEnabled(true)
        await store.setEnabled(false)

        let reopened = MotivationQuoteStore(baseURL: directory)
        let quote = await reopened.snapshot()
        XCTAssertFalse(quote.enabled)
        XCTAssertEqual(quote.text, "先完成，再完美。", "关闭激励话术不得清空已保存的文案")
    }

    /// 空文案时保存空串不应把已存内容顶掉——只有显式写入才覆盖。
    func testEnablingTwiceDoesNotDropText() async {
        let store = MotivationQuoteStore(baseURL: directory)
        await store.setText("打怪在给你升级")
        await store.setEnabled(true)
        await store.setEnabled(false)
        await store.setEnabled(true)

        let quote = await store.snapshot()
        XCTAssertTrue(quote.enabled)
        XCTAssertEqual(quote.text, "打怪在给你升级")
    }
}
