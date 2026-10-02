import Foundation

/// 激励话术的独立 JSON 持久化。
///
/// 与 `SettingsStore` 同目录（`Application Support/NotionFloat/`）但独立文件 `motivation-quote.json`，
/// 不触碰 Keychain / SQLite / settings.json 等既有持久化。
///
/// 属非关键数据：磁盘读写失败时静默降级为纯内存模式，不影响任务与日记流程。
public actor MotivationQuoteStore {
    private let fileURL: URL?
    private var cache = MotivationQuote()
    private var isLoaded = false
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(baseURL: URL? = nil) {
        if let baseURL {
            fileURL = baseURL.appendingPathComponent("motivation-quote.json")
        } else if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            fileURL = appSupport
                .appendingPathComponent("NotionFloat", isDirectory: true)
                .appendingPathComponent("motivation-quote.json")
        } else {
            fileURL = nil
        }
    }

    /// 当前快照。未落盘或文件损坏时返回默认值（关闭 + 空文案）。
    public func snapshot() -> MotivationQuote {
        loadIfNeeded()
        return cache
    }

    /// 只切换显示开关，**不触碰已保存的文案**：
    /// 用户关闭后再开启，必须还能看到原来写的内容。
    public func setEnabled(_ enabled: Bool) {
        loadIfNeeded()
        guard cache.enabled != enabled else { return }
        cache.enabled = enabled
        persist()
    }

    /// 保存文案，落盘前统一压成单行。
    public func setText(_ raw: String) {
        loadIfNeeded()
        let normalized = MotivationStripLayout.normalizedQuote(raw)
        guard cache.text != normalized else { return }
        cache.text = normalized
        persist()
    }

    // MARK: - Private

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true

        guard let fileURL,
              FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode(MotivationQuote.self, from: data) else {
            return
        }
        cache = decoded
    }

    private func persist() {
        guard let fileURL, let data = try? encoder.encode(cache) else { return }
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
