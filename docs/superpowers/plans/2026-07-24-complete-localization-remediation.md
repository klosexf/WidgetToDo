# Complete Localization Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every app-owned user-facing string switch immediately between Simplified Chinese, English, and French, while retaining fixed `Language` and native language-option labels.

**Architecture:** Expand the typed Core `AppText` catalog and add `AppMessage`, a deferred catalog key plus string arguments. SwiftUI and AppKit resolve from `LanguageStore`; view models retain `AppMessage` rather than a rendered Chinese value. Core validation/errors expose semantic keys with raw contextual parameters.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Swift Concurrency, XCTest, SwiftPM, Xcode.

---

## File map

- Create `WidgetToDo/Core/Models/AppMessage.swift` and `Tests/NotionFloatCoreTests/AppMessageLocalizationTests.swift`.
- Modify `AppLocalizer.swift`, `LanguageStore.swift`, core validation/error producers, all visible views/view models, `StatusBarController.swift`, `AppDelegate.swift`, `WidgetToDoApp.swift`, existing tests, smoke tests, and `progress.md`.
- Do not modify `Package.swift`, project configuration, Keychain/cache data, or remote Notion data.

### Task 1: Add deferred messages and a complete catalog

**Files:**
- Create: `WidgetToDo/Core/Models/AppMessage.swift`
- Modify: `WidgetToDo/Core/Services/AppLocalizer.swift`
- Modify: `Tests/NotionFloatCoreTests/AppLanguageTests.swift`
- Create: `Tests/NotionFloatCoreTests/AppMessageLocalizationTests.swift`

- [ ] **Step 1: Write failing completeness and rendering tests.**

```swift
func testEveryLanguageHasEveryAppTextKeyAndNoEmptyValue() {
    let expected = Set(AppText.Key.allCases)
    for language in AppLanguage.allCases {
        XCTAssertEqual(AppText.keys(in: language), expected)
        XCTAssertTrue(expected.allSatisfy { !AppText.string($0, language: language).isEmpty })
    }
}

func testDeferredMessageRendersUsingTheCurrentLanguage() {
    let message = AppMessage(.taskSyncFailed, arguments: ["offline"])
    XCTAssertEqual(message.string(in: .english), "Task sync failed: offline")
    XCTAssertEqual(message.string(in: .french), "Échec de la synchronisation des tâches : offline")
}
```

- [ ] **Step 2: Verify RED.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter 'AppLanguageTests|AppMessageLocalizationTests'`

Expected: compilation fails because `AppMessage` and `.taskSyncFailed` do not exist.

- [ ] **Step 3: Implement the primitive and all three language tables.**

```swift
public struct AppMessage: Equatable, Sendable {
    public let key: AppText.Key
    public let arguments: [String]
    public init(_ key: AppText.Key, arguments: [String] = []) { self.key = key; self.arguments = arguments }
    public func string(in language: AppLanguage) -> String { AppText.string(key, language: language, arguments: arguments) }
}
```

Add matching keys for app shell/loading; settings/onboarding inputs; token/database prompts; reset flow; welcome; all three help-sheet titles, links and numbered steps; todo/journal states; menu actions; confirmation dialogs; retry/toasts; new/edit task form; duration/date labels; accessibility labels; validation and operation-error framing. Keep `.languageSettingTitle` as `Language`, and keep `AppLanguage.displayName` unchanged. Missing keys must fail, never fall back to English.

- [ ] **Step 4: Verify GREEN and commit.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter 'AppLanguageTests|AppMessageLocalizationTests'`

Expected: focused tests pass.

```bash
git add WidgetToDo/Core/Models/AppMessage.swift WidgetToDo/Core/Services/AppLocalizer.swift Tests/NotionFloatCoreTests/AppLanguageTests.swift Tests/NotionFloatCoreTests/AppMessageLocalizationTests.swift && git commit -m "feat: add deferred localization messages"
```

### Task 2: Convert Core validation and errors to semantic messages

**Files:**
- Modify: `WidgetToDo/Core/Services/ConfigurationInputNormalizer.swift`
- Modify: `WidgetToDo/Core/Services/FieldValidator.swift`
- Modify: `WidgetToDo/Core/Infrastructure/NotionRepository.swift`
- Modify: `WidgetToDo/Core/Infrastructure/NotionClient.swift`
- Modify: `Tests/NotionFloatCoreTests/ConfigurationInputNormalizerTests.swift`
- Modify: `Tests/NotionFloatCoreTests/FieldMappingResolutionTests.swift`
- Create: `Tests/NotionFloatCoreTests/AppErrorLocalizationTests.swift`

- [ ] **Step 1: Write failing semantic-error tests.**

```swift
func testConfigurationIssuesRenderInEachLanguage() {
    let issues = ConfigurationInputNormalizer.validate(token: "", tasksInput: "bad", journalInput: "bad")
    XCTAssertEqual(issues[0].message.string(in: .english), "Enter a Notion Token.")
    XCTAssertEqual(issues[1].message.string(in: .french), "ID ou URL de la base Tasks non valide.")
}

func testHTTPErrorLocalizesFramingButPreservesServerDetail() {
    let error = NotionClientError.httpError(statusCode: 401, message: "API token is invalid.")
    XCTAssertEqual(error.appMessage.string(in: .english), "Notion request failed (HTTP 401): API token is invalid.")
}
```

- [ ] **Step 2: Verify RED.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter 'AppErrorLocalizationTests|ConfigurationInputNormalizerTests|FieldMappingResolutionTests'`

Expected: compilation fails because validation/client errors expose rendered Chinese strings.

- [ ] **Step 3: Store a semantic key plus raw context.**

```swift
public struct ValidationIssue: Equatable, Sendable { public let message: AppMessage }

extension NotionClientError {
    var appMessage: AppMessage {
        switch self {
        case let .httpError(statusCode, message): return AppMessage(.notionRequestFailed, arguments: [String(statusCode), message])
        case .invalidResponse: return AppMessage(.unknownResponse)
        }
    }
}
```

Use semantic keys for invalid token/database input, missing/duplicate fields, mapping failure, cache record failures, and missing configuration/token. Preserve field names, HTTP status, and raw Notion detail only as message arguments. Move validation-message joining to the selected-language display boundary.

- [ ] **Step 4: Verify GREEN and commit.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter 'AppErrorLocalizationTests|ConfigurationInputNormalizerTests|FieldMappingResolutionTests|NotionRepositoryTaskMutationTests'`

Expected: selected tests pass in all three language expectations.

```bash
git add WidgetToDo/Core/Services/ConfigurationInputNormalizer.swift WidgetToDo/Core/Services/FieldValidator.swift WidgetToDo/Core/Infrastructure/NotionRepository.swift WidgetToDo/Core/Infrastructure/NotionClient.swift Tests/NotionFloatCoreTests && git commit -m "feat: localize validation and repository errors"
```

### Task 3: Migrate live view-model state and formatting

**Files:**
- Modify: `WidgetToDo/LanguageStore.swift`
- Modify: `WidgetToDo/OnboardingViewModel.swift`
- Modify: `WidgetToDo/TodoListViewModel.swift`
- Modify: `WidgetToDo/NewTaskViewModel.swift`
- Modify: `WidgetToDo/JournalViewModel.swift`
- Modify: `WidgetToDo/Core/Models/TodoDateDisplayFormatter.swift`
- Modify: `Tests/NotionFloatCoreTests/TaskDateSelectionTests.swift`

- [ ] **Step 1: Write failing live-refresh and date-copy tests.**

```swift
func testLanguageStoreRendersAnExistingMessageAfterSwitch() async {
    let store = await MainActor.run { LanguageStore() }
    let message = AppMessage(.journalSavedToNotion)
    XCTAssertEqual(await MainActor.run { store.text(message) }, "已保存到 Notion")
    await MainActor.run { store.apply(.english) }
    XCTAssertEqual(await MainActor.run { store.text(message) }, "Saved to Notion")
}

func testTodoEmptyStateUsesChosenLanguage() {
    XCTAssertEqual(TodoDateDisplayFormatter.emptyState(for: today, referenceDate: today, language: .english), "No tasks today")
}
```

- [ ] **Step 2: Verify RED.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter 'AppMessageLocalizationTests|TaskDateSelectionTests'`

Expected: compilation fails because the store cannot render an `AppMessage` and the formatter lacks a language argument.

- [ ] **Step 3: Store app-owned status/error text as `AppMessage`.**

```swift
func text(_ message: AppMessage) -> String { message.string(in: language) }
```

Migrate app-owned `statusMessage`, `errorMessage`, `bannerMessage`, estimated-duration validation, and toast payloads. Add an explicit `language: AppLanguage` to UI date/empty-state formatting. Do not translate task titles, journal content, priorities, field names, or raw remote error details.

- [ ] **Step 4: Verify GREEN and commit.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter 'AppMessageLocalizationTests|TaskDateSelectionTests|NotionRepositoryTaskMutationTests'`

Expected: selected tests pass and existing displayed feedback resolves in the new language after a switch.

```bash
git add WidgetToDo/LanguageStore.swift WidgetToDo/OnboardingViewModel.swift WidgetToDo/TodoListViewModel.swift WidgetToDo/NewTaskViewModel.swift WidgetToDo/JournalViewModel.swift WidgetToDo/Core/Models/TodoDateDisplayFormatter.swift Tests/NotionFloatCoreTests && git commit -m "feat: render live feedback in selected language"
```

### Task 4: Localize configuration, help, welcome, and app shell

**Files:**
- Modify: `WidgetToDo/ContentView.swift`
- Modify: `WidgetToDo/WelcomeView.swift`
- Modify: `WidgetToDo/WidgetToDoApp.swift`
- Modify: `WidgetToDo/AppDelegate.swift`
- Modify: `WidgetToDo/StatusBarController.swift`
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] **Step 1: Add failing smoke checks for the five supplied screenshot regions.**

```swift
try expect(source.contains("languageStore.text(.notionTokenHelpTitle)"), "Token help must be catalog-backed")
try expect(source.contains("languageStore.text(.tasksDatabaseHelpTitle)"), "Tasks help must be catalog-backed")
try expect(source.contains("languageStore.text(.journalDatabaseHelpTitle)"), "Journal help must be catalog-backed")
try expect(source.contains("languageStore.text(.resetConfiguration)"), "reset configuration must be catalog-backed")
try expect(!source.contains("Text(\"获取 Notion Token\")"), "hard-coded Token help title must be removed")
```

- [ ] **Step 2: Verify RED.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run NotionFloatCoreSmokeTests --disable-sandbox`

Expected: at least one supplied-surface assertion fails.

- [ ] **Step 3: Replace shell/configuration literals through `LanguageStore`.**

Localize loading, Settings/onboarding titles and intro, token/database labels and prompts, keychain explanations, accessibility labels, save/validate actions, reset card/confirmation, all help title/instruction/button/link text, welcome CTA/tagline, app Settings scene, startup alert, status-bar menu, and tooltip. Add `@EnvironmentObject` to nested views where needed. Preserve only `Text("Language")` and `Text(language.displayName)` in the language row.

- [ ] **Step 4: Verify GREEN and commit.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run NotionFloatCoreSmokeTests --disable-sandbox`

Expected: `All smoke tests passed.`

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`

Expected: `** BUILD SUCCEEDED **`.

```bash
git add WidgetToDo/ContentView.swift WidgetToDo/WelcomeView.swift WidgetToDo/WidgetToDoApp.swift WidgetToDo/AppDelegate.swift WidgetToDo/StatusBarController.swift Tests/NotionFloatCoreSmokeTests/main.swift && git commit -m "feat: localize setup and help surfaces"
```

### Task 5: Localize todo, journal, mini, forms, and toast

**Files:**
- Modify: `WidgetToDo/ContentView.swift`
- Modify: `WidgetToDo/NewTaskFormCard.swift`
- Modify: `WidgetToDo/PendingTodoRowView.swift`
- Modify: `WidgetToDo/MiniCapsuleViews.swift`
- Modify: `WidgetToDo/ToastHostView.swift`
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] **Step 1: Add a failing literal audit.**

```swift
for literal in ["新建任务", "编辑任务", "删除任务", "重试", "回到今天", "正在加载任务...", "正在加载日记...", "2 秒后自动保存"] {
    try expect(!source.contains("Text(\"\\(literal)\")") && !source.contains("Button(\"\\(literal)\")"), "\(literal) must be catalog-backed")
}
```

- [ ] **Step 2: Verify RED.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run NotionFloatCoreSmokeTests --disable-sandbox`

Expected: literal audit identifies remaining todo, journal, or form copy.

- [ ] **Step 3: Migrate remaining app-owned display text.**

Localize tabs, loading/empty/sync states, retry/edit/delete/back actions, delete confirmation, journal autosave state, task-form labels/prompts/errors/buttons, duration unit, mini-capsule status, pending-row status, and toast text. Render Task 3 messages with `languageStore.text(message)`. Keep `task.title`, `priority`, `entry.contentText`, and Notion-returned values unchanged.

- [ ] **Step 4: Verify GREEN and commit.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run NotionFloatCoreSmokeTests --disable-sandbox`

Expected: `All smoke tests passed.`

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter 'TaskDateSelectionTests|NotionRepositoryTaskMutationTests|AppMessageLocalizationTests'`

Expected: selected tests pass.

```bash
git add WidgetToDo/ContentView.swift WidgetToDo/NewTaskFormCard.swift WidgetToDo/PendingTodoRowView.swift WidgetToDo/MiniCapsuleViews.swift WidgetToDo/ToastHostView.swift Tests/NotionFloatCoreSmokeTests/main.swift && git commit -m "feat: localize task and journal surfaces"
```

### Task 6: Run final audit and update project status

**Files:**
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift`
- Modify: `progress.md`

- [ ] **Step 1: Expand the source audit.**

Audit `ContentView.swift`, `WelcomeView.swift`, `NewTaskFormCard.swift`, `PendingTodoRowView.swift`, `MiniCapsuleViews.swift`, and `StatusBarController.swift`. Permit only `Language`, `AppLanguage.displayName`, system-image names, preview fixtures, external URLs, and user/Notion-provided values as non-catalog strings.

- [ ] **Step 2: Run all automated verification.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox`

Expected: all tests pass with zero failures.

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run NotionFloatCoreSmokeTests --disable-sandbox`

Expected: `All smoke tests passed.`

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Perform actual desktop verification.**

Switch `简体中文`, `English`, and `Français`; inspect the five supplied screenshot regions, welcome, menu bar, todo/journal, new/edit form, delete confirmation, toast, and mini capsule. Relaunch and verify language is applied before the first visible screen. Reset configuration and verify the language remains selected.

- [ ] **Step 4: Record results and commit.**

Record exact command outcomes and desktop test result in `progress.md`; if desktop testing is blocked, state that blocker rather than claiming completion.

```bash
git add Tests/NotionFloatCoreSmokeTests/main.swift progress.md && git commit -m "test: audit complete application localization"
```
