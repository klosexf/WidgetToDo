# Task Select Field Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a task database's single optional Notion `select` field be chosen in task forms, synchronized to Notion, and shown safely in the task list without affecting databases that do not provide that field.

**Architecture:** Persist the resolved property name and its Notion-defined options in `TaskDatabaseFieldMapping`. Publish a read-only `TaskChoiceField` through the configuration snapshot to both task form view models and render choice values using that same configuration. Keep the existing `TaskItem.priority` storage column, sorting, completion, duration, and request paths intact; only add the select property when a configured choice value exists or is explicitly cleared during edit.

**Tech Stack:** Swift 6.2, SwiftUI/AppKit, Swift Concurrency, Foundation Codable, Notion REST API, XCTest, SwiftPM.

---

## File Map

- `WidgetToDo/Core/Models/NotionSchema.swift`: value types for a Notion select option and an optional configured choice field.
- `WidgetToDo/Core/Models/AppSettings.swift`: optional Codable select-option metadata in the saved task mapping.
- `WidgetToDo/Core/Services/FieldValidator.swift`: retain one-select-only resolution while attaching that property's options.
- `WidgetToDo/Core/Infrastructure/NotionClient.swift`: decode schema options, preserve selected values, and send select set/clear mutations.
- `WidgetToDo/Core/Infrastructure/NotionRepository.swift`: publish current choice configuration and forward selection values through create/edit methods.
- `WidgetToDo/NewTaskViewModel.swift`, `WidgetToDo/TodoListViewModel.swift`: bind new/edit selection state without changing title, date, duration, or Pomodoro behavior.
- `WidgetToDo/NewTaskFormCard.swift`, `WidgetToDo/ContentView.swift`: render form menus and a capped task-row metadata capsule.
- `Tests/NotionFloatCoreTests/FieldMappingResolutionTests.swift`, `Tests/NotionFloatCoreTests/NotionRepositoryTaskMutationTests.swift`: type-resolution, persistence compatibility, and request-body coverage.
- `progress.md`: final verification evidence and remaining manual UI checks.

### Task 1: Persist a resolved choice field

**Files:**
- Modify: `WidgetToDo/Core/Models/NotionSchema.swift`
- Modify: `WidgetToDo/Core/Models/AppSettings.swift`
- Modify: `WidgetToDo/Core/Services/FieldValidator.swift`
- Test: `Tests/NotionFloatCoreTests/FieldMappingResolutionTests.swift`

- [ ] **Step 1: Add a failing field-resolution test that supplies schema options.**

```swift
let options = [
    NotionSelectOption(name: "高", color: .orange),
    NotionSelectOption(name: "中", color: .yellow)
]
let result = FieldValidator.resolve([
    NotionPropertySchema(name: "任务标题", type: "title"),
    NotionPropertySchema(name: "计划日期", type: "date"),
    NotionPropertySchema(name: "完成", type: "checkbox"),
    NotionPropertySchema(name: "优先级", type: "select", selectOptions: options)
], for: .tasks)

XCTAssertEqual(mapping.priority, "优先级")
XCTAssertEqual(mapping.priorityOptions, options)
```

- [ ] **Step 2: Run the focused test and confirm it fails because schema options and mapping metadata do not exist.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter FieldMappingResolutionTests/testResolveTaskFieldMappingPreservesUniqueSelectOptions`

Expected: compile failure referencing missing `NotionSelectOption`, `selectOptions`, or `priorityOptions`.

- [ ] **Step 3: Add the smallest Codable model extension.**

```swift
public struct NotionSelectOption: Codable, Equatable, Sendable {
    public enum Color: String, Codable, Sendable {
        case `default`, gray, brown, orange, yellow, green, blue, purple, pink, red
    }

    public let name: String
    public let color: Color
}

public struct TaskChoiceField: Equatable, Sendable {
    public let name: String
    public let options: [NotionSelectOption]
}
```

Extend `NotionPropertySchema` with `selectOptions: [NotionSelectOption] = []`. Extend `TaskDatabaseFieldMapping` with `priorityOptions: [NotionSelectOption] = []` and a custom `init(from:)` that decodes it with `decodeIfPresent(...) ?? []`; keep every existing initializer source-compatible through default parameters. Make `FieldValidator.resolveTasks` take the one matching `NotionPropertySchema`, not just its name, so it can save both its name and options. Preserve the existing zero/multiple-select `nil` mapping behavior.

- [ ] **Step 4: Add legacy and ambiguity assertions.**

```swift
XCTAssertEqual(settings.tasksFieldMapping.priorityOptions, [])
XCTAssertNil(mapping.priority)
XCTAssertEqual(mapping.priorityOptions, [])
```

The first assertion belongs in the existing legacy-settings decoding test; the latter two belong in the multiple-select test.

- [ ] **Step 5: Run focused field-mapping tests.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter FieldMappingResolutionTests`

Expected: all field-mapping tests pass, including legacy JSON and zero/multiple-select fallbacks.

- [ ] **Step 6: Commit the model and validator slice.**

```bash
git add WidgetToDo/Core/Models/NotionSchema.swift WidgetToDo/Core/Models/AppSettings.swift WidgetToDo/Core/Services/FieldValidator.swift Tests/NotionFloatCoreTests/FieldMappingResolutionTests.swift
git commit -m "feat: persist task select field options"
```

### Task 2: Read select schema options and write selected values

**Files:**
- Modify: `WidgetToDo/Core/Infrastructure/NotionClient.swift`
- Modify: `WidgetToDo/Core/Infrastructure/NotionRepository.swift`
- Modify: `Tests/NotionFloatCoreTests/NotionRepositoryTaskMutationTests.swift`

- [ ] **Step 1: Write failing request-body tests for select set and clear.**

```swift
_ = try await harness.repository.createTask(
    title: "新任务", date: date, priority: "高", estimatedMinutes: nil, hasPriorityField: true
)
XCTAssertTrue(requestBody.contains(#""优先级":{"select":{"name":"高"}}"#))

_ = try await harness.repository.updateTaskTitle(
    id: task.id, title: task.title, priority: nil, estimatedMinutes: nil
)
XCTAssertTrue(requestBody.contains(#""优先级":{"select":null}"#))
```

- [ ] **Step 2: Run the focused mutation tests and confirm the edit-clear test fails on the missing priority parameter.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter NotionRepositoryTaskMutationTests`

Expected: the new update test does not compile until the repository/client edit signatures accept `priority`.

- [ ] **Step 3: Decode select options and selected colors from Notion responses.**

Decode `DatabaseProperty.select?.options` into `[NotionSelectOption]`; `fetchDatabaseSchema` must pass them into `NotionPropertySchema`. Decode `NotionSelectProperty.color` as optional so task queries continue to accept old/mock payloads that contain only `name`.

```swift
private struct DatabaseProperty: Decodable {
    let type: String
    let select: SelectConfiguration?
}

private struct SelectConfiguration: Decodable {
    let options: [NotionSelectOption]
}
```

- [ ] **Step 4: Make create and edit selection mutations explicit.**

`createTask` keeps omitting the field when `priority == nil`. Extend `updateTaskTitle` in the client and repository with `priority: String?`. If `fields.priority` exists, always emit one property on edit:

```swift
properties[priorityField] = priority.map { ["select": ["name": $0]] } ?? ["select": NSNull()]
```

This is the only new edit mutation; existing title and duration payload construction remains unchanged.

- [ ] **Step 5: Publish a safe choice configuration in the snapshot.**

Add `choiceField: TaskChoiceField?` to `ConfigurationSnapshot`. In `loadConfigurationSnapshot`, derive it only when a saved priority mapping has a nonempty option list; otherwise use `nil`. Root initialization and post-settings refresh use this field instead of inferring options from `hasPriorityField`.

- [ ] **Step 6: Run focused mutation tests.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter NotionRepositoryTaskMutationTests`

Expected: existing title/duration/create tests remain green; new select set and clear request tests pass.

- [ ] **Step 7: Commit the Notion contract slice.**

```bash
git add WidgetToDo/Core/Infrastructure/NotionClient.swift WidgetToDo/Core/Infrastructure/NotionRepository.swift Tests/NotionFloatCoreTests/NotionRepositoryTaskMutationTests.swift
git commit -m "feat: synchronize task select values"
```

### Task 3: Bind selection state to the existing forms

**Files:**
- Modify: `WidgetToDo/NewTaskViewModel.swift`
- Modify: `WidgetToDo/TodoListViewModel.swift`
- Modify: `WidgetToDo/ContentView.swift`
- Modify: `WidgetToDo/NewTaskFormCard.swift`

- [ ] **Step 1: Add choice state without changing form behavior when configuration is absent.**

Add `@Published var choiceField: TaskChoiceField?` and `@Published var selectedPriority: String?` to `NewTaskViewModel`. Reset the value in `openForm`; include it in the optimistic `PendingTaskItem` and `repository.createTask(...)` call. Replace the unused fixed `priorityOptions` array with `choiceField?.options ?? []`.

Add `choiceField`, `editingPriority`, and `configure(choiceField:)` to `TodoListViewModel`. `beginEditing` copies `task.priority`; `cancelEditing` clears local state; `saveTaskEdit` passes `editingPriority` to the repository.

- [ ] **Step 2: Wire the root snapshot only at existing configuration boundaries.**

At the two existing `ContentView` snapshot call sites (bootstrap and settings return), call a single `TodoListViewModel.configure(choiceField:)` method. That method assigns the same field to `newTaskViewModel`. Do not alter refresh, date navigation, Pomodoro, task completion, retry, deletion, or journal control flow.

- [ ] **Step 3: Add a private reusable choice picker view.**

Create a small private SwiftUI view in `NewTaskFormCard.swift` that accepts `TaskChoiceField`, `Binding<String?>`, and `isDisabled`. It uses `Menu` with:

```swift
Button(languageStore.text(.notSelected)) { selection = nil }
ForEach(field.options, id: \.name) { option in
    Button { selection = option.name } label: { optionMenuLabel(option) }
}
```

Render it under duration in both forms only when `choiceField` is nonnil. Reuse `NewTaskFormPalette`, `NewTaskFormMetrics`, 13pt label typography, 34pt field height, and existing disabled handling. Add one localized `notSelected` key in Chinese, English, and French.

- [ ] **Step 4: Run an Xcode Debug build after form compilation changes.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoSelectFieldDerivedData build`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit the form integration.**

```bash
git add WidgetToDo/NewTaskViewModel.swift WidgetToDo/TodoListViewModel.swift WidgetToDo/ContentView.swift WidgetToDo/NewTaskFormCard.swift WidgetToDo/Core/Services/AppLocalizer.swift
git commit -m "feat: add task select controls"
```

### Task 4: Render a non-disruptive task-row choice capsule

**Files:**
- Modify: `WidgetToDo/ContentView.swift`

- [ ] **Step 1: Add a private option-color adapter and capsule.**

Add a `Color` adapter for `NotionSelectOption.Color` using the WidgetToDo warm palette; use neutral `FloatingWidgetPalette.metaText` for `.default`. Add `taskChoiceCapsule(_:)` that receives the selected name and resolved option color.

```swift
Text(priority)
    .lineLimit(1)
    .truncationMode(.tail)
    .frame(maxWidth: 142)
    .help(priority)
    .accessibilityLabel(priority)
```

The capsule contains a color dot plus text, shares the meta-row height, and does not use the removed legacy priority badge styling.

- [ ] **Step 2: Insert the capsule between duration and sync status.**

Resolve the current option from `todoViewModel.choiceField?.options.first { $0.name == task.priority }`. Show it only for a nonempty task priority; fall back to neutral dot if a stored task value no longer exists in current options. Compute separator visibility from the actual visible metadata items so there are no duplicate or leading dots. Keep the row's right-side timer/menu HStack untouched.

- [ ] **Step 3: Run the full automated suite and build.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox`

Expected: all XCTest targets pass with zero failures.

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoSelectFieldDerivedData build`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Perform macOS UI verification.**

Verify one configured single-select database, a database with no select, and one with multiple selects. Check new/edit selection, clearing, Notion sync, unchanged duration and timer controls, list capsule placement, completion-state de-emphasis, long-value ellipsis, and hover full text.

- [ ] **Step 5: Update progress and commit final integration.**

Record exact automated and manual results in `progress.md`; record any newly verified stable risk in `bugs.md` only if requested. Then:

```bash
git add WidgetToDo/ContentView.swift progress.md
git commit -m "feat: show task select metadata"
```

## Plan Self-Review

- Coverage: Tasks 1–2 cover schema, mapping, legacy settings, and Notion set/clear writes; Task 3 covers new/edit forms and localization; Task 4 covers rendering, long text, regression tests, and UI verification.
- Scope: no SQLite schema change is needed because colors resolve from saved mapping metadata; no mini capsule, filtering, sorting, or multi-select code is added.
- Type consistency: `NotionSelectOption` is the persisted schema option, `TaskChoiceField` is the UI-facing resolved configuration, and `priority: String?` remains the task value through model, repository, and client layers.
