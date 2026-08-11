import Combine
import Foundation
import SwiftUI

enum NewTaskFormState: Equatable {
    case idle
    case validating
    case validationFailed
    case submitting
}

@MainActor
final class NewTaskViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var taskDate: Date = Date()
    @Published var priority: String?
    @Published var estimatedMinutesText: String = ""
    @Published var estimatedMinutesError: AppMessage?
    @Published var formState: NewTaskFormState = .idle
    @Published var showForm: Bool = false
    @Published var shakeAttempts: CGFloat = 0

    let priorityOptions = ["Low", "Medium", "High"]

    private let repository: NotionRepository
    @Published var hasPriorityField: Bool
    @Published var choiceField: TaskChoiceField?

    var onSubmit: ((PendingTaskItem) -> Void)?
    var onCreateSuccess: ((TaskItem) -> Void)?
    var onCreateFailure: ((PendingTaskItem, String) -> Void)?

    init(repository: NotionRepository, hasPriorityField: Bool) {
        self.repository = repository
        self.hasPriorityField = hasPriorityField
    }

    func openForm(defaultDate: Date) {
        title = ""
        taskDate = defaultDate
        priority = nil
        estimatedMinutesText = ""
        formState = .idle
        estimatedMinutesError = nil
        showForm = true
    }

    func dismissForm() {
        showForm = false
        formState = .idle
        estimatedMinutesError = nil
    }

    func submit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            formState = .validationFailed
            withAnimation(.easeInOut(duration: 0.2)) {
                shakeAttempts += 1
            }
            return
        }
        let parsedEstimatedMinutes = parseEstimatedMinutes()
        if !estimatedMinutesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, parsedEstimatedMinutes == nil {
            estimatedMinutesError = AppMessage(.estimatedMinutesInvalid)
            return
        }
        estimatedMinutesError = nil
        let estimatedMinutes = parsedEstimatedMinutes

        let pendingItem = PendingTaskItem(
            title: trimmedTitle,
            date: taskDate,
            priority: priority,
            estimatedMinutes: estimatedMinutes
        )
        dismissForm()
        onSubmit?(pendingItem)

        Task {
            do {
                let task = try await repository.createTask(
                    title: trimmedTitle,
                    date: taskDate,
                    priority: priority,
                    estimatedMinutes: estimatedMinutes,
                    hasPriorityField: choiceField != nil
                )
                onCreateSuccess?(task)
            } catch {
                onCreateFailure?(pendingItem, error.localizedDescription)
            }
        }
    }

    private func parseEstimatedMinutes() -> Int? {
        let trimmed = estimatedMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        guard let parsed = Int(trimmed), parsed > 0 else {
            return nil
        }
        return parsed
    }
}
