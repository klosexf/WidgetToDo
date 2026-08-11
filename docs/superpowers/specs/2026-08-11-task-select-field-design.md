# Task Select Field Design

## Goal

Expose the existing optional Notion `select` task property throughout WidgetToDo: let users choose a value while creating or editing a task, persist it through Notion, and show the selected value in the task list.

The experience must use the application's existing task-form and task-row visual language. It must not introduce a separate settings screen or manual field-name configuration.

## Scope

In scope:

- keep the existing auto-resolution rule: exactly one Tasks database `select` property enables the capability
- read that property's display name, existing options, and option colors from the Notion database schema
- add an optional native-style choice control to new-task and edit-task forms
- write a selected value on task create and edit; omit the property when no option is selected
- show selected values in the task-list metadata row
- preserve the full option value for accessibility and hover help when the list value is truncated
- add focused field-mapping, request-body, and rendering tests

Out of scope:

- `multi_select` fields, multiple independent select fields, or manual field mapping
- creating, deleting, renaming, recoloring, or reordering Notion select options
- task-list filtering or sorting changes
- adding a choice badge to the mini capsule
- changing task title, date, duration, completion, Pomodoro, cache, Keychain, or journal behavior

## Existing Context

- `FieldValidator` already resolves a unique Notion `select` property into `TaskDatabaseFieldMapping.priority`.
- `TaskItem.priority` and the Notion client already read a selected option name, but the current task form always submits `nil` and task-list badges were previously removed.
- The Notion database-schema decoder currently receives only property names and types; it must be extended to expose the select option list.
- The current task form uses a large warm-gray card with 68pt rounded input rows and paired bottom actions. The current task row shows title plus inline duration and sync metadata on the left, with timer and overflow controls anchored on the right.

## Design Direction

Treat the unique Notion `select` property as one optional **choice field**. The field label is the database property's actual name (for example, `优先级`), and its menu lists only options already defined in Notion.

The existing `priority` storage and mapping names remain unchanged in this implementation. This preserves existing task sorting and saved-settings compatibility while making the supported select capability visible to the user.

## Field Resolution And Compatibility

Required property rules remain unchanged: one `title`, one `date`, and one `checkbox`.

For the optional `select` capability:

- 0 matching properties: mapping and options are absent; forms and rows have no choice UI.
- 1 matching property: save its name and schema options; enable the field.
- 2 or more matching properties: leave the capability disabled rather than guessing; setup still succeeds.
- existing saved settings decode without a migration. They lack option metadata until the user saves the database configuration again; while metadata is absent, the control remains hidden rather than offering stale or invented options.

## Data And Notion Flow

1. Configuration fetches the Tasks database schema.
2. The schema decoder supplies the resolved property's name and its ordered options (`name`, Notion color identifier).
3. `TaskDatabaseFieldMapping` persists the optional choice property and its option metadata alongside the existing mapping.
4. Task reads retain the selected option name in `TaskItem.priority`.
5. New-task and edit-task forms bind an optional selected option name. No option is selected by default.
6. Create and edit requests include `{ "select": { "name": value } }` only when a value is selected and the mapping is available. Clearing the field sends `select: null` on edit; creation simply omits it.
7. The returned task payload becomes the cached and rendered source of truth.

The repository remains the sole route between ViewModel and Notion client.

## UI Design

### New and edit task forms

- Insert the optional choice field between duration and the action buttons.
- Reuse the existing label size, 68pt input shell, rounded corners, focus border, and button proportions.
- The field label is the real Notion property name; do not hard-code `优先级`.
- The collapsed row shows an option-color dot, selected option name, and chevron. Its empty state reads `未选择`.
- The menu is anchored to the field, lists Notion-defined options, and includes a `未选择` item so edits can clear a prior value.
- When the property is unavailable, the card is visually and behaviorally identical to today's form.

### Task-list metadata

Show a selected value as a small inline metadata capsule below the task title:

`时长 · [option-color dot + selected value] · 已同步`

Rules:

- position it after duration and before sync status; when duration is absent, it becomes the first metadata item
- show it only when the task has a selected value
- do not repeat the field name inside the row; the colored option name carries the meaning
- do not change the right-aligned timer or overflow controls
- completed rows retain the same placement but inherit the existing completed-state de-emphasis

### Long option values

The list row must never wrap because a select value is long.

- choice capsule uses one line and caps at 142pt on the normal widget width; narrow layouts cap it at 112pt
- overflow truncates at the tail with an ellipsis
- duration, sync text, timer, and overflow controls retain their positions
- the full value is exposed in a hover tooltip and accessibility label

## Error Handling

- Failure to read a database schema continues to surface the existing readable setup error.
- A select option that was removed in Notion between setup and submit produces the readable Notion error path; the form remains open and does not claim a successful save.
- Missing/stale option metadata hides the choice control rather than creating an invalid request.

## Implementation Boundary

Expected code and test paths:

- `WidgetToDo/Core/Models/AppSettings.swift`
- `WidgetToDo/Core/Models/TaskItem.swift` only if option display metadata belongs with the task
- `WidgetToDo/Core/Services/FieldValidator.swift`
- `WidgetToDo/Core/Infrastructure/NotionClient.swift`
- `WidgetToDo/Core/Infrastructure/NotionRepository.swift`
- `WidgetToDo/NewTaskViewModel.swift`
- `WidgetToDo/NewTaskFormCard.swift`
- `WidgetToDo/ContentView.swift` for editing and task-row rendering
- `Tests/NotionFloatCoreTests/FieldMappingResolutionTests.swift`
- `Tests/NotionFloatCoreTests/NotionRepositoryTaskMutationTests.swift`

The Notion client schema and mutation contract changes are L3 under the repository instructions. No implementation begins until the user explicitly approves this written design and that L3 impact.

## Verification

Automated:

1. Add tests first for unique-select option resolution, zero/multiple-select fallback, and legacy settings decoding.
2. Add create/update request tests for set, omit, and clear behaviors.
3. Run targeted tests, then `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox`.
4. Run an Xcode Debug build with an isolated DerivedData path.

Manual macOS verification:

1. Configure a database with one select property and visible colored options.
2. Create a task with no value, then one with a selected value; confirm the latter writes to Notion.
3. Edit a selected task, change it, then clear it; confirm each result in Notion and the list.
4. Confirm a long option appears in one row with ellipsis and exposes its full value on hover.
5. Confirm zero/multiple select properties leave the existing form and list unchanged.

## Risks And Rollback

- Schema-option support changes the Notion client contract; API payload tests and actual Notion checks are required.
- Select option changes made in Notion after configuration can make saved metadata stale. Re-saving setup refreshes metadata; failed mutations remain visible rather than silently changing values.
- Rollback is code-only: revert the implementation commit and re-run the existing configuration. Stored settings remain backwards-decodable because added metadata is optional.
