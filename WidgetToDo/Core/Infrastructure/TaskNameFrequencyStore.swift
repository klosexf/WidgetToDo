import Foundation

/// 高频任务名统计的独立 JSON 持久化。
///
/// 与 `SettingsStore` 同目录（`Application Support/NotionFloat/`）但独立文件，
/// 不触碰 Keychain / SQLite / settings.json 等既有持久化。
///
/// 统计属非关键数据：磁盘读写失败时静默降级为纯内存模式，不影响任务创建流程。
public actor TaskNameFrequencyStore {
    private let fileURL: URL?
    private var entries: [String: TaskNameUsage] = [:]
    private var isLoaded = false
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(baseURL: URL? = nil) {
        if let baseURL {
            fileURL = baseURL.appendingPathComponent("task-name-frequency.json")
        } else if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            fileURL = appSupport
                .appendingPathComponent("NotionFloat", isDirectory: true)
                .appendingPathComponent("task-name-frequency.json")
        } else {
            fileURL = nil
        }

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    /// 记录一次成功创建：去首尾空白后合并同名计数，记录最近使用的类型，并落盘。
    public func record(name: String, priority: String?, now: Date = Date()) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        loadIfNeeded()

        var usage = entries[trimmed] ?? TaskNameUsage(count: 0, lastUsedAt: now, lastPriority: priority)
        usage.count += 1
        usage.lastUsedAt = now
        usage.lastPriority = priority
        entries[trimmed] = usage

        persist()
    }

    /// 按评分降序返回前 `limit` 个高频任务名条目（含最近使用的类型，时间衰减策略见 `TaskNameFrequencyScorer`）。
    public func topEntries(limit: Int, now: Date = Date()) -> [FrequentTaskName] {
        loadIfNeeded()
        return TaskNameFrequencyScorer.topEntries(entries: entries, limit: limit, now: now)
    }

    /// 当前全部统计快照。
    public func snapshot() -> [String: TaskNameUsage] {
        loadIfNeeded()
        return entries
    }

    // MARK: - Private

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true

        guard let fileURL,
              FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([String: TaskNameUsage].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func persist() {
        guard let fileURL else { return }
        guard let data = try? encoder.encode(entries) else { return }
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
