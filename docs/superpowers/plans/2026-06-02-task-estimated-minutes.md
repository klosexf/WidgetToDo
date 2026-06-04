# Task Estimated Minutes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional task `预计时长` field stored as integer minutes, sync it through the existing Notion task pipeline when a unique `number` field exists, and render it in the todo tab with the same visual placement as the HTML reference.

**Architecture:** Extend the existing task model and type-based field mapping rather than introducing manual field configuration. Keep the optional-field behavior tolerant: if the Tasks database does not expose exactly one usable `number` field, duration support is disabled while the rest of the task flow continues unchanged. UI work stays inside the existing create-task card and todo-row metadata pipeline.

**Tech Stack:** SwiftUI, Swift Concurrency, SwiftPM smoke tests, XCTest-based unit tests, Notion HTTP payload mapping

---

## File Map

- Modify: `WidgetToDo/Tests/NotionFloatCoreTests/FieldMappingResolutionTests.swift`
  - Add failing coverage for optional `number` field resolution and legacy decode compatibility.
- Modify: `WidgetToDo/Tests/NotionFloatCoreTests/NotionRepositoryTaskMutationTests.swift`
  - Add failing coverage for create-task payloads and task mapping with estimated minutes.
- Modify: `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift`
  - Add a source-level guard for the new-task duration field and todo-row duration token.
- Modify: `WidgetToDo/WidgetToDo/Core/Models/TaskItem.swift`
  - Extend synced and pending task value models with `estimatedMinutes`.
- Modify: `WidgetToDo/WidgetToDo/Core/Models/NewTaskDraft.swift`
  - Persist optional minute values for failed create-task draft recovery.
- Modify: `WidgetToDo/WidgetToDo/Core/Models/AppSettings.swift`
  - Extend `TaskDatabaseFieldMapping` with optional estimated-minutes mapping while keeping legacy decode compatibility.
- Modify: `WidgetToDo/WidgetToDo/Core/Services/FieldValidator.swift`
  - Resolve a unique optional `number` field for task estimated minutes.
- Modify: `WidgetToDo/WidgetToDo/Core/Infrastructure/NotionRepository.swift`
  - Thread optional estimated minutes through task creation.
- Modify: `WidgetToDo/WidgetToDo/Core/Infrastructure/NotionClient.swift`
  - Read and write optional Notion `number` duration values.
- Modify: `WidgetToDo/WidgetToDo/NewTaskViewModel.swift`
  - Add form-state storage, validation, and draft persistence for estimated minutes.
- Modify: `WidgetToDo/WidgetToDo/NewTaskFormCard.swift`
  - Add the optional minute input using the existing card language.
- Modify: `WidgetToDo/WidgetToDo/PendingTodoRowView.swift`
  - Render pending task duration token.
- Modify: `WidgetToDo/WidgetToDo/ContentView.swift`
  - Render synced task duration token and update previews.
- Modify: `progress.md`
  - Record implementation status and verification evidence.

## Task 1: Add failing test coverage for estimated-minutes mapping and UI contract

**Files:**
- Modify: `WidgetToDo/Tests/NotionFloatCoreTests/FieldMappingResolutionTests.swift`
- Modify: `WidgetToDo/Tests/NotionFloatCoreTests/NotionRepositoryTaskMutationTests.swift`
- Modify: `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] **Step 1: Add failing field-resolution tests**

Add tests that assert:

```swift
func testResolveTaskFieldMappingUsesUniqueOptionalNumberAsEstimatedMinutes()
func testResolveTaskFieldMappingDisablesEstimatedMinutesWhenMultipleNumberFieldsExist()
```

Expected mapping snippet:

```swift
TaskDatabaseFieldMapping(
    title: "任务标题",
    date: "计划日期",
    done: "已完成",
    priority: "任务优先级",
    estimatedMinutes: "预计时长"
)
```

- [ ] **Step 2: Add failing repository/client task mutation coverage**

Add assertions that create-task requests include:

```json
"预计时长": {
  "number": 60
}
```

when the draft contains minutes and the mapping exists, and omit the property when the input is empty.

- [ ] **Step 3: Add failing smoke guard**

Add a narrow source-level smoke guard that checks:

```swift
source.contains("estimatedMinutes")
source.contains("min")
source.contains("clock")
```

across `NewTaskFormCard.swift`, `PendingTodoRowView.swift`, and the synced row rendering in `ContentView.swift`.

- [ ] **Step 4: Run targeted tests and confirm RED**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift test --filter FieldMappingResolutionTests
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift test --filter NotionRepositoryTaskMutationTests
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift run NotionFloatCoreSmokeTests
```

Expected:

- unit tests fail because `estimatedMinutes` does not exist yet
- smoke fails because the new UI contract is absent
- if `swift test` is still blocked by the known `XCTest` environment issue, record that exact blocker and rely on smoke for RED confirmation

## Task 2: Extend task models and optional field mapping

**Files:**
- Modify: `WidgetToDo/WidgetToDo/Core/Models/TaskItem.swift`
- Modify: `WidgetToDo/WidgetToDo/Core/Models/NewTaskDraft.swift`
- Modify: `WidgetToDo/WidgetToDo/Core/Models/AppSettings.swift`
- Modify: `WidgetToDo/WidgetToDo/Core/Services/FieldValidator.swift`

- [ ] **Step 1: Add `estimatedMinutes: Int?` to task models**

Extend both synced and pending task initializers and stored properties with:

```swift
public var estimatedMinutes: Int?
```

- [ ] **Step 2: Persist optional draft minutes**

Extend `NewTaskDraft` with:

```swift
public var estimatedMinutes: Int?
```

and update its initializer accordingly.

- [ ] **Step 3: Extend saved task field mapping**

Add:

```swift
public let estimatedMinutes: String?
```

to `TaskDatabaseFieldMapping`, update `legacyDefault`, `init`, and legacy decode defaults so old payloads still decode with `estimatedMinutes == nil`.

- [ ] **Step 4: Resolve a unique optional `number` field**

Update `FieldValidator.resolveTasks(...)` so:

```swift
let estimatedMinutesCandidates = propertyNames(in: properties, matching: "number")
estimatedMinutes: estimatedMinutesCandidates.count == 1 ? estimatedMinutesCandidates[0] : nil
```

- [ ] **Step 5: Re-run focused field-resolution tests and make them GREEN**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift test --filter FieldMappingResolutionTests
```

Expected:

- new mapping tests pass
- legacy decode compatibility remains green
- if blocked by `XCTest`, note the blocker and verify via smoke / source inspection instead

## Task 3: Thread estimated minutes through Notion read/write

**Files:**
- Modify: `WidgetToDo/WidgetToDo/Core/Infrastructure/NotionRepository.swift`
- Modify: `WidgetToDo/WidgetToDo/Core/Infrastructure/NotionClient.swift`

- [ ] **Step 1: Extend repository create-task API**

Change the signature to carry:

```swift
public func createTask(title: String, date: Date, priority: String?, estimatedMinutes: Int?, hasPriorityField: Bool) async throws -> TaskItem
```

- [ ] **Step 2: Extend Notion client create-task API and payload**

When both mapping and value exist, add:

```swift
properties[estimatedMinutesField] = [
    "number": estimatedMinutes
]
```

- [ ] **Step 3: Read estimated minutes from task page mapping**

Update `mapTask(...)` to read:

```swift
let estimatedMinutes = fields.estimatedMinutes.flatMap { page.properties[$0]?.number }.flatMap(Int.init)
```

or the equivalent numeric conversion that fits the existing Notion response model.

- [ ] **Step 4: Re-run task mutation tests and make them GREEN**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift test --filter NotionRepositoryTaskMutationTests
```

Expected:

- create-task payload assertions pass
- task mapping assertions pass

## Task 4: Add create-form parsing and optimistic pending-task support

**Files:**
- Modify: `WidgetToDo/WidgetToDo/NewTaskViewModel.swift`
- Modify: `WidgetToDo/WidgetToDo/Core/Models/NewTaskDraft.swift`

- [ ] **Step 1: Add raw form state for estimated minutes**

Add a new published property:

```swift
@Published var estimatedMinutesText: String = ""
```

- [ ] **Step 2: Add one positive-integer parser**

Introduce a local helper used by submit and draft restore:

```swift
private func parseEstimatedMinutes() -> Int?
```

Rules:

- empty string => `nil`
- positive integer => parsed value
- everything else => validation failure

- [ ] **Step 3: Block submit on invalid minutes**

If parsing fails, set a readable Chinese error state and do not dismiss the form.

- [ ] **Step 4: Carry parsed minutes into pending and synced create flow**

Update pending item creation and repository call to pass the parsed `estimatedMinutes`.

- [ ] **Step 5: Persist and restore failed draft minutes**

Save and restore `estimatedMinutesText` using `NewTaskDraft.estimatedMinutes`.

## Task 5: Render the optional field in the create-task card and todo rows

**Files:**
- Modify: `WidgetToDo/WidgetToDo/NewTaskFormCard.swift`
- Modify: `WidgetToDo/WidgetToDo/PendingTodoRowView.swift`
- Modify: `WidgetToDo/WidgetToDo/ContentView.swift`

- [ ] **Step 1: Add the optional duration input to the card**

Place it below the date row and above the actions using the same shell language as the title input. The field should communicate fixed-minute units and optionality.

- [ ] **Step 2: Add a reusable duration meta token in pending rows**

Render:

```swift
Image(systemName: "clock")
Text("\\(minutes)min")
```

with the same muted 10pt metadata style used elsewhere.

- [ ] **Step 3: Mirror the same duration token in synced todo rows**

Keep placement:

- priority badge
- duration token
- separator dot
- sync status

and omit the duration token cleanly when `estimatedMinutes == nil`.

- [ ] **Step 4: Re-run smoke tests and make them GREEN**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift run NotionFloatCoreSmokeTests
```

Expected:

- new duration contract passes
- if the suite still stops at the known unrelated smoke failure, record the exact blocker

## Task 6: Final verification and progress sync

**Files:**
- Modify: `progress.md`

- [ ] **Step 1: Run full verification**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift test
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build
```

Expected:

- `swift test` passes, or the known `XCTest` blocker is recorded exactly
- `xcodebuild` succeeds

- [ ] **Step 2: Perform UI verification if runtime access is available**

Check:

- empty duration create works
- valid minute create works
- invalid minute input blocks submit with Chinese feedback
- pending and synced rows both show duration in the HTML-aligned position
- rows without duration show no broken separators

- [ ] **Step 3: Update `progress.md`**

Record:

- current task goal and status
- exact commands run
- exact pass / fail / blocker outcomes
- whether UI runtime verification was completed or blocked
