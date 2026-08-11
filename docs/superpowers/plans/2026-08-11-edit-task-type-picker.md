# Edit Task Type Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the edit-task type field the same searchable segmented dropdown and overflow scrolling behavior as the new-task form.

**Architecture:** Keep all presentation state private to `EditTaskFormCard`; filter existing `TaskChoiceField.options` and bind the result directly to `TodoListViewModel.editingPriority`. Wrap the card body in a vertically scrolling form constrained by the shared new-task card height, so an expanded type list never obscures the action buttons.

**Tech Stack:** Swift 6.2, SwiftUI/AppKit, SwiftPM source smoke executable, Xcode Debug build.

---

## File structure

- Modify: `WidgetToDo/ContentView.swift:2062-2213` — replace the edit form `Menu` with a searchable segmented picker and apply in-card scrolling.
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift` — add a source contract for edit-picker affordances and edit-card scroll containment.
- Modify: `progress.md` — record scope and fresh verification evidence.

### Task 1: Add a failing edit-form presentation contract

**Files:**
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] Add `editTaskTypePickerUsesSearchableDropdownContract()` and call it from the smoke executable. It reads `WidgetToDo/ContentView.swift` and asserts the form has local type search and expanded state, `TextField("搜索或选择类型")`, `chevron.down`, filtered options, clear/select bindings, explicit option-list height, and an outer vertical scroll view.
- [ ] Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests`; verify RED at the missing local type search state.

### Task 2: Implement the edit-form segmented picker

**Files:**
- Modify: `WidgetToDo/ContentView.swift:2062-2213`

- [ ] Add `typeSearchText`, `isTypeOptionsPresented`, `isTypeSearchFocused`, a trimmed case-insensitive `filteredTypeOptions` computation, and a capped `typeOptionsListHeight` calculation.
- [ ] Replace the current `Menu` with a type field that contains a color dot or magnifier, input text, separator, and a 34pt `chevron.down` button. Use existing form palette, height, focus border and disabled-saving behavior.
- [ ] Render “未选择”, filtered color-dot options, selection checkmark and “没有匹配的类型” inside an in-flow, fixed-height inner scroll view. Selection assigns `viewModel.editingPriority = option.name`; clear assigns `viewModel.editingPriority = nil`; both restore text and close the list.
- [ ] Wrap the edit form’s existing content in `ScrollView(.vertical, showsIndicators: true)` and use `NewTaskFormMetrics.cardMaxHeight`, preserving all title, duration and save/cancel behavior.
- [ ] Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests`; verify GREEN.

### Task 3: Verify and record the change

**Files:**
- Modify: `progress.md`

- [ ] Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox`; expect no test failures.
- [ ] Build with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoEditTaskTypePickerDerivedData build`; expect `BUILD SUCCEEDED`.
- [ ] Manually test an existing task’s editor: input-open, arrow-open, filter, select, clear, expanded-list scrolling and cancel. Avoid a Notion write.
- [ ] Update `progress.md` with scope, non-targets, commands, hand-test evidence, risk and rollback point; commit the implementation checkpoint.
