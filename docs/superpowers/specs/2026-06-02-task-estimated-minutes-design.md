# Task Estimated Minutes Design

## Goal

Add an optional `预计时长` field to tasks in the todo tab so a user can record the estimated time needed to complete a task.

The field must:

- use **minutes** as the only unit
- remain optional for both existing and new tasks
- preserve current task behavior when the field is absent
- support future aggregation and analysis by storing a numeric value rather than presentation text
- visually match the duration treatment already shown in [WidgetToDo-Welcome-Modal.html](/Users/chenxiaofeng/Documents/Tare%20code%20file/widgets%20for%20notion/WidgetToDo-Welcome-Modal.html) inside the journal modal's todo tab

## Scope

In scope:

- task model support for optional estimated minutes
- new-task form support for optional minute input
- Notion task field mapping for an optional `number` field
- task query / create flows reading and writing the estimated minutes field
- pending-task UI and synced-task UI showing duration in the same position and style family as the HTML reference
- validation rules for optional numeric input
- backward compatibility for existing saved settings and tasks without the field

Out of scope:

- journal data model or UI
- task sorting changes based on estimated minutes
- total-duration statistics UI
- editing estimated minutes for an existing task after creation
- new settings UI for manual field-name mapping
- changing persistence backends, token handling, or cache ownership boundaries

## Existing Context

Relevant current behavior:

- `TaskItem` and `PendingTaskItem` do not contain any duration field
- `NewTaskDraft` persists failed create-task retries, but only stores title, date, priority, and created time
- `NewTaskViewModel` creates tasks through `NotionRepository.createTask(...)`
- `TaskDatabaseFieldMapping` currently resolves required `title/date/checkbox` fields and optional unique `select` for priority
- `FieldValidator.resolve(...)` follows a type-based auto-mapping strategy rather than fixed field names
- `PendingTodoRowView` already renders task metadata rows with priority and date
- the HTML reference already defines a duration token:
  - positioned after priority
  - rendered as a small meta label with a clock icon
  - text format `60min`

This means the feature should extend the existing type-based mapping system rather than introduce a separate manual mapping concept.

## Design Direction

Recommended direction: **optional integer minutes backed by an optional Notion `number` field**

Why:

- integer minutes are the cleanest unit for later statistics and aggregation
- they match the existing visual copy in the HTML reference
- `number` is the correct Notion type for computation and filtering later
- keeping the field optional preserves compatibility with existing databases that do not have a duration field

Rejected alternatives:

- free-form text such as `1h` / `30min`
  - poor for aggregation and validation
- hours as floating-point values
  - less aligned with the reference UI and more awkward for common short tasks
- field-name-based mapping
  - conflicts with the current type-driven configuration design

## Data Model

### Task value model

Add `estimatedMinutes: Int?` to:

- `TaskItem`
- `PendingTaskItem`
- `NewTaskDraft`

Semantics:

- `nil` means the user did not provide an estimated duration
- positive integer means the task has an estimated duration in minutes

The field must never store unit suffixes such as `min` in the model.

### Saved configuration model

Extend `TaskDatabaseFieldMapping` with:

- `estimatedMinutes: String?`

Semantics:

- `nil` means the connected Tasks database does not expose a usable estimated-minutes field
- a string value means the saved mapping resolved a single Notion `number` property name that should be used for task duration

Backward compatibility:

- existing `settings.json` payloads must still decode successfully
- legacy payloads should default `estimatedMinutes` to `nil`
- no migration should be required from the user

## Notion Mapping Rules

### Supported field type

The Notion field for `预计时长` must be:

- type: `number`
- stored value: whole minutes

No other Notion type is in scope for this feature.

### Resolution strategy

`FieldValidator.resolveTasks(...)` should continue to auto-resolve fields by type.

Required fields remain unchanged:

- exactly one `title`
- exactly one `date`
- exactly one `checkbox`

Optional fields:

- priority: unique `select`, otherwise disabled
- estimated minutes: unique `number`, otherwise disabled

Recommended behavior for estimated minutes resolution:

- `0` matching `number` fields: set mapping to `nil`, do not fail configuration
- `1` matching `number` field: save that property name into `TaskDatabaseFieldMapping.estimatedMinutes`
- `2+` matching `number` fields: set mapping to `nil`, do not fail configuration

This mirrors the current tolerance strategy used for optional priority fields: optional capabilities should not break the entire setup.

## Input And Validation

### New-task form input

Add an optional input to the create-task card for estimated minutes.

Recommended field behavior:

- label / placeholder communicates optionality and fixed unit
- user enters digits only
- empty value is allowed

Accepted values:

- empty string -> `nil`
- positive integer -> `Int`

Rejected values:

- non-numeric characters
- `0`
- negative numbers
- decimal numbers

Validation behavior:

- invalid estimated-minutes input blocks submit
- error messaging remains readable Chinese text
- empty estimated-minutes input does not trigger an error

The title-required validation and existing form behavior remain unchanged.

## Read / Write Flow

### Task query

When loading tasks from Notion:

- if `tasksFieldMapping.estimatedMinutes` is present, read the mapped `number` value
- if absent or missing in the page payload, map to `nil`

### Task creation

When creating a task:

- if the user left estimated minutes empty, do not send the duration property
- if the user entered a valid positive integer and `tasksFieldMapping.estimatedMinutes` exists, send the Notion `number` property with that integer minute value
- if the user entered a valid value but the mapping is `nil`, keep the task creation flow successful and simply omit the property

This keeps the field optional at both the database and user-input layers.

### Pending task state

The optimistic pending task shown before Notion sync should carry the same `estimatedMinutes` value so the temporary row and the final synced row render consistently.

## UI Design

### New-task form

Add the estimated-minutes input to `NewTaskFormCard` without changing the card's overall visual language introduced in the recent redesign.

Design constraints:

- preserve the current card structure and typography family
- place the new input in a way that still feels compact
- keep the field clearly secondary to the required title input
- communicate that the unit is fixed to minutes

Recommended placement:

- below the date row
- above the action row

Recommended visual treatment:

- same shell language as the title field
- compact numeric entry appearance
- no extra dropdown or unit selector
- suffix is expressed by helper/placeholder copy or inline `min` text, but the stored model remains numeric only

### Todo row display

Todo rows should visually follow the duration pattern from the HTML reference.

Required display rules:

- show duration after the priority badge
- show sync-status metadata after duration
- show the separator dot only when both adjacent meta items exist
- if duration is `nil`, omit the entire duration token cleanly

Required visual characteristics:

- same hierarchy level as other task metadata
- small muted meta color
- inline clock icon
- text format `\(minutes)min`

The SwiftUI rendering does not need pixel-for-pixel CSS translation, but the placement, scale, and hierarchy must match the reference closely enough that the todo row reads as the same design.

## Behavioral Constraints

The feature must not:

- bypass `NotionRepository`
- require manual field-name entry from the user
- break existing databases that do not contain a `number` field for estimated minutes
- alter task sorting
- alter existing task edit, delete, toggle, retry, or journal behavior

## Implementation Boundary

Primary files likely involved:

- `WidgetToDo/WidgetToDo/Core/Models/TaskItem.swift`
- `WidgetToDo/WidgetToDo/Core/Models/NewTaskDraft.swift`
- `WidgetToDo/WidgetToDo/Core/Models/AppSettings.swift`
- `WidgetToDo/WidgetToDo/Core/Services/FieldValidator.swift`
- `WidgetToDo/WidgetToDo/Core/Infrastructure/NotionRepository.swift`
- `WidgetToDo/WidgetToDo/Core/Infrastructure/NotionClient.swift`
- `WidgetToDo/WidgetToDo/NewTaskViewModel.swift`
- `WidgetToDo/WidgetToDo/NewTaskFormCard.swift`
- `WidgetToDo/WidgetToDo/PendingTodoRowView.swift`
- `WidgetToDo/WidgetToDo/ContentView.swift`

Likely test surfaces:

- `WidgetToDo/Tests/NotionFloatCoreTests/FieldMappingResolutionTests.swift`
- `WidgetToDo/Tests/NotionFloatCoreTests/NotionRepositoryTaskMutationTests.swift`
- `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift`

## Testing And Verification

### Test-first expectations

Before production edits, add failing coverage for:

- optional `number` field resolution
- legacy settings decode compatibility with `estimatedMinutes == nil`
- task request payload including `number` minutes when present
- task response mapping reading `number` minutes
- source-level smoke guard for new-task form duration input and todo-row duration display contract

### Required verification

1. `swift test --filter FieldMappingResolutionTests`
2. `swift test --filter NotionRepositoryTaskMutationTests`
3. `swift run NotionFloatCoreSmokeTests`
4. `swift test`

If the local environment still blocks `swift test` because of the existing `XCTest` issue, record the exact blocker and do not claim a full green automated run.

### UI verification

Manual runtime verification should confirm:

1. new-task popup accepts empty duration and creates normally
2. new-task popup accepts positive integer minutes and creates normally
3. invalid duration blocks submission with readable Chinese feedback
4. todo rows render duration in the same position and style hierarchy as the HTML reference
5. tasks without duration still render cleanly without broken separators

If local desktop runtime verification is unavailable, that blocker must be stated explicitly.

## Risks

### 1. Optional-field ambiguity

If a Tasks database contains multiple `number` fields, the system could pick the wrong one.

Constraint:

- do not auto-pick when multiple `number` fields exist
- disable estimated-minutes mapping instead of guessing

### 2. Validation drift between form and model

If UI validation allows values the model or Notion layer does not support, behavior will be inconsistent.

Constraint:

- centralize parsing to a single positive-integer rule

### 3. Metadata layout regression

Adding another meta token can easily break separator logic or cause cramped rows.

Constraint:

- treat duration as an optional token in the same metadata pipeline as priority and sync state
- hide separators when adjacent tokens are absent

## Recommended Implementation Approach

1. Extend tests to describe the optional-number-field behavior and UI contract.
2. Extend task models and saved field mappings with `estimatedMinutes`.
3. Update field resolution and Notion read/write mapping.
4. Update new-task form parsing and optimistic pending-task creation.
5. Restyle todo metadata rows to include the HTML-aligned duration token.
6. Run automated verification and record any existing environment blockers.
