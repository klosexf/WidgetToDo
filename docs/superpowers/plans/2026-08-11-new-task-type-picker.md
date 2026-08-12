# New Task Type Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the new-task type `Menu` with a searchable, explicitly segmented dropdown while preserving the Notion selection binding.

**Architecture:** Presentation state remains inside private `TaskChoicePicker`: query text, expanded state, and focus. It filters `TaskChoiceField.options` and writes the selected name through its existing `Binding<String?>`; no ViewModel, repository, storage, or API change is needed.

**Tech Stack:** Swift 6.2, SwiftUI/AppKit, SwiftPM source smoke executable, Xcode Debug build.

---

## File structure

- Modify: `WidgetToDo/NewTaskFormCard.swift` — replace private type `Menu` with input, arrow button, and in-card list.
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift` — add a source contract for the new affordances and binding.
- Modify: `progress.md` — record scope and fresh verification evidence.

### Task 1: Add a failing type-picker presentation contract

**Files:**
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift:42-44, 838-983`

- [ ] **Step 1: Add a failing smoke call after `newTaskFormKeepsCreateTaskContract()`**

```swift
try newTaskTypePickerUsesSearchableDropdownContract()
```

- [ ] **Step 2: Add the smoke test before `newTaskFormDoesNotDimTodoPanel()`**

```swift
static func newTaskTypePickerUsesSearchableDropdownContract() throws {
    let rootURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let formURL = rootURL.appendingPathComponent("WidgetToDo/NewTaskFormCard.swift")
    let source = try String(contentsOf: formURL, encoding: .utf8)

    try expect(source.contains("@State private var searchText"), "type picker should keep local search text")
    try expect(source.contains("@State private var isOptionsPresented"), "type picker should keep local dropdown state")
    try expect(source.contains("TextField(\"搜索或选择类型\""), "type picker should expose an input placeholder")
    try expect(source.contains("Image(systemName: \"chevron.down\")"), "type picker should use a down arrow")
    try expect(source.contains("filteredOptions"), "type picker should filter Notion options")
    try expect(source.contains("selection = option.name"), "type picker should preserve the selection binding")
    try expect(source.contains("selection = nil"), "type picker should retain a clear choice")
}
```

- [ ] **Step 3: Run the smoke executable and confirm RED**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests
```

Expected: non-zero exit at `type picker should keep local search text`, because the existing component uses `Menu`.

### Task 2: Implement the segmented searchable type picker

**Files:**
- Modify: `WidgetToDo/NewTaskFormCard.swift:297-326`

- [ ] **Step 1: Add local state and derive filtered options**

```swift
@State private var searchText = ""
@State private var isOptionsPresented = false
@FocusState private var isSearchFocused: Bool

private var filteredOptions: [NotionSelectOption] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return field.options }
    return field.options.filter { $0.name.localizedCaseInsensitiveContains(query) }
}
```

- [ ] **Step 2: Replace the `Menu` with an input and a separated arrow**

```swift
HStack(spacing: 0) {
    Image(systemName: "magnifyingglass")
    TextField("搜索或选择类型", text: $searchText)
        .textFieldStyle(.plain)
        .focused($isSearchFocused)
        .onTapGesture { isOptionsPresented = true }
    Button { isOptionsPresented.toggle() } label: {
        Image(systemName: "chevron.down")
            .frame(width: 34, height: NewTaskFormMetrics.fieldHeight)
    }
    .buttonStyle(.plain)
    .overlay(alignment: .leading) { Divider() }
}
```

Apply existing field fill, radius and border to this `HStack`; use `focusBorder` when focused or open. Keep the existing disabled/saving behavior; do not add a ViewModel property.

- [ ] **Step 3: Render the in-card list with empty state and selection**

```swift
if isOptionsPresented {
    VStack(spacing: 2) {
        Button("未选择") { selection = nil; searchText = ""; isOptionsPresented = false }
        ForEach(filteredOptions, id: \.name) { option in
            Button {
                selection = option.name
                searchText = option.name
                isOptionsPresented = false
            } label: {
                HStack {
                    Circle().fill(TaskChoicePalette.dot(for: option)).frame(width: 8, height: 8)
                    Text(option.name)
                    Spacer()
                }
            }
        }
    }
}
```

Use the existing field visual language; display “没有匹配的类型” when the filtered array is empty. Synchronize query text to an existing selection in `.onAppear` and after selecting, so saved choice and displayed text do not diverge.

- [ ] **Step 4: Run the smoke executable and confirm GREEN**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests
```

Expected: `All smoke tests passed.`

### Task 3: Verify and record the change

**Files:**
- Modify: `progress.md`

- [ ] **Step 1: Run full tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox
```

Expected: all tests pass; report warnings separately.

- [ ] **Step 2: Build the macOS app**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoTypePickerDerivedData build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run the app and manually verify**

Click `+`; verify visual alignment, opening by input and arrow, filtering, select, clear, create, and cancel. Confirm the selected type is visible on the created task.

- [ ] **Step 4: Update `progress.md`**

Record non-targets, exact smoke/test/build results, manual test result or blocker, and rollback point (restore `TaskChoicePicker`).

- [ ] **Step 5: Commit the implementation checkpoint**

```bash
git add WidgetToDo/NewTaskFormCard.swift Tests/NotionFloatCoreSmokeTests/main.swift progress.md
git commit -m "feat: add searchable new task type picker"
```
