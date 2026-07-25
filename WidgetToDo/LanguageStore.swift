import Combine
import Foundation

@MainActor
final class LanguageStore: ObservableObject {
    static let shared = LanguageStore()

    @Published private(set) var language: AppLanguage = .default

    func apply(_ language: AppLanguage) {
        self.language = language
    }

    func text(_ key: AppText.Key, _ arguments: CVarArg...) -> String {
        AppText.string(key, language: language, arguments)
    }

    func text(_ message: AppMessage) -> String {
        message.string(in: language)
    }
}
