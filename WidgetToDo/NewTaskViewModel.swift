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
    @Published var priority: String = "Medium"
    @Published var formState: NewTaskFormState = .idle
    @Published var showForm: Bool = false
    @Published var shakeAttempts: CGFloat = 0

    let priorityOptions = ["Low", "Medium", "High"]

    private let repository: NotionRepository
    @Published var hasPriorityField: Bool
    @AppStorage("lastFailedDraft") private var lastFailedDraftData: Data?

    var onSubmit: ((PendingTaskItem) -> Void)?
    var onCreateSuccess: ((TaskItem) -> Void)?
    var onCreateFailure: ((PendingTaskItem, String) -> Void)?

    init(repository: NotionRepository, hasPriorityField: Bool) {
        self.repository = repository
        self.hasPriorityField = hasPriorityField
    }

    func openForm(defaultDate: Date) {
        restoreDraftIfNeeded()
        if title.isEmpty {
            taskDate = defaultDate
            priority = "Medium"
        }
        formState = .idle
        showForm = true
    }

    func dismissForm() {
        showForm = false
        formState = .idle
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

        let pendingItem = PendingTaskItem(
            title: trimmedTitle,
            date: taskDate,
            priority: nil
        )
        dismissForm()
        onSubmit?(pendingItem)

        Task {
            do {
                let task = try await repository.createTask(
                    title: trimmedTitle,
                    date: taskDate,
                    priority: nil,
                    hasPriorityField: false
                )
                onCreateSuccess?(task)
            } catch {
                saveDraft()
                onCreateFailure?(pendingItem, error.localizedDescription)
            }
        }
    }

    private func saveDraft() {
        let draft = NewTaskDraft(
            title: title,
            date: taskDate,
            priority: priority
        )
        lastFailedDraftData = try? JSONEncoder().encode(draft)
    }

    private func restoreDraftIfNeeded() {
        guard let data = lastFailedDraftData,
              let draft = try? JSONDecoder().decode(NewTaskDraft.self, from: data),
              !draft.isExpired else {
            lastFailedDraftData = nil
            return
        }
        title = draft.title
        taskDate = draft.date
        priority = draft.priority
        lastFailedDraftData = nil
    }
}
