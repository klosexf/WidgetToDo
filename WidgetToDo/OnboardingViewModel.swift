import Combine
import Foundation

private struct OnboardingUserFacingError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }

    static func resetConfigurationFailed() -> Self {
        .init(message: "重置配置失败，请稍后重试。")
    }
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var token = ""
    @Published var tasksDatabaseInput = ""
    @Published var journalDatabaseInput = ""
    @Published var statusMessage: AppMessage?
    @Published var statusMessageKey: AppText.Key?
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
            statusMessage = nil
            statusMessageKey = .keychainTokenFound
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
            statusMessageKey = nil
            statusMessage = issues.first?.message
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
            statusMessageKey = nil
            statusMessage = AppMessage(.configurationSaved)
            isErrorState = false
            didFinishSetup?()
        } catch let NotionRepositoryError.validationFailed(issues) {
            statusMessageKey = nil
            statusMessage = issues.first?.message
            isErrorState = true
        } catch let NotionRepositoryError.invalidDatabaseInput(message) {
            statusMessageKey = nil
            statusMessage = AppMessage(.fieldMappingFailed, arguments: [message])
            isErrorState = true
        } catch {
            statusMessageKey = nil
            statusMessage = AppMessage(.fieldMappingFailed, arguments: [error.localizedDescription])
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

    func resetConfigurationForRestart() async throws {
        isWorking = true
        statusMessageKey = nil
        statusMessage = AppMessage(.resettingConfiguration)
        isErrorState = false
        defer { isWorking = false }

        do {
            try await repository.resetConfiguration()
            token = ""
            tasksDatabaseInput = ""
            journalDatabaseInput = ""
            statusMessage = nil
            statusMessageKey = nil
            isErrorState = false
        } catch {
            statusMessage = nil
            statusMessageKey = nil
            isErrorState = false
            throw OnboardingUserFacingError.resetConfigurationFailed()
        }
    }
}
