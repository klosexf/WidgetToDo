import Combine
import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var token = ""
    @Published var tasksDatabaseInput = ""
    @Published var journalDatabaseInput = ""
    @Published var statusMessage: String?
    @Published var isWorking = false
    @Published var isErrorState = false

    var didFinishSetup: (@MainActor () -> Void)?

    private let repository: NotionRepository

    init(repository: NotionRepository) {
        self.repository = repository
    }

    func loadSnapshot() async throws -> ConfigurationSnapshot {
        let snapshot = try await repository.loadConfigurationSnapshot()
        token = snapshot.token ?? ""
        tasksDatabaseInput = snapshot.tasksDatabaseID ?? ""
        journalDatabaseInput = snapshot.journalDatabaseID ?? ""
        if snapshot.hasToken {
            statusMessage = "已检测到保存在钥匙串中的令牌。"
            isErrorState = false
        }
        return snapshot
    }

    func validateAndSave() async {
        let issues = ConfigurationInputNormalizer.validate(
            token: token,
            tasksInput: tasksDatabaseInput,
            journalInput: journalDatabaseInput
        )
        guard issues.isEmpty else {
            statusMessage = issues.map(\.message).joined(separator: "\n")
            isErrorState = true
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            _ = try await repository.saveConfiguration(
                token: token,
                tasksInput: tasksDatabaseInput,
                journalInput: journalDatabaseInput
            )
            statusMessage = "配置已保存。"
            isErrorState = false
            didFinishSetup?()
        } catch let NotionRepositoryError.validationFailed(issues) {
            statusMessage = issues.map(\.message).joined(separator: "\n")
            isErrorState = true
        } catch let NotionRepositoryError.invalidDatabaseInput(message) {
            statusMessage = message
            isErrorState = true
        } catch {
            statusMessage = error.localizedDescription
            isErrorState = true
        }
    }

    func normalizeTasksDatabaseInput() {
        guard let normalized = ConfigurationInputNormalizer.normalizeDatabaseInput(tasksDatabaseInput),
              normalized != tasksDatabaseInput
        else {
            return
        }
        tasksDatabaseInput = normalized
    }

    func normalizeJournalDatabaseInput() {
        guard let normalized = ConfigurationInputNormalizer.normalizeDatabaseInput(journalDatabaseInput),
              normalized != journalDatabaseInput
        else {
            return
        }
        journalDatabaseInput = normalized
    }
}
