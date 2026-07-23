import Foundation

public actor SettingsStore {
    private let fileURL: URL
    private let preferencesURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(baseURL: URL? = nil) throws {
        let rootURL = try Self.resolveRootURL(baseURL: baseURL)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        fileURL = rootURL.appendingPathComponent("settings.json")
        preferencesURL = rootURL.appendingPathComponent("app-preferences.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> AppSettings? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(AppSettings.self, from: data)
    }

    public func save(_ settings: AppSettings) throws {
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: fileURL)
    }

    public func loadAppLanguage() throws -> AppLanguage {
        guard FileManager.default.fileExists(atPath: preferencesURL.path) else {
            return .default
        }

        let data = try Data(contentsOf: preferencesURL)
        return (try? decoder.decode(AppPreferences.self, from: data))?.language ?? .default
    }

    public func saveAppLanguage(_ language: AppLanguage) throws {
        let data = try encoder.encode(AppPreferences(language: language))
        try data.write(to: preferencesURL, options: .atomic)
    }

    private static func resolveRootURL(baseURL: URL?) throws -> URL {
        if let baseURL {
            return baseURL
        }

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return appSupport.appendingPathComponent("NotionFloat", isDirectory: true)
    }
}

private struct AppPreferences: Codable, Sendable {
    let language: AppLanguage
}
