import Combine
import Foundation

@MainActor
final class LanguageStore: ObservableObject {
    @Published private(set) var language: AppLanguage = .default

    func apply(_ language: AppLanguage) {
        self.language = language
    }

    func text(_ key: AppText.Key, _ arguments: CVarArg...) -> String {
        AppText.string(key, language: language, arguments)
    }
}
