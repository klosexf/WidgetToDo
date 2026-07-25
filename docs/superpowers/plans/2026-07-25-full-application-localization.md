# Full Application Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure every application-owned visible label, action, status, validation message, toast, menu item, alert, and date string changes immediately between Simplified Chinese, English, and French while keeping `Language`, `简体中文`, `English`, and `Français` fixed.

**Architecture:** Extend the existing typed `AppText.Key` catalogue and `AppMessage` so views resolve text only at render time through the shared `LanguageStore`. Replace view-model-owned raw strings with `AppMessage` values, preserving raw Notion responses as arguments rather than translating user or remote data. Keep core validation semantic where possible and map it to localized UI messages at the application boundary; do not change Notion property names, Notion values, URLs, or persisted user content.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, XCTest, SwiftPM, Xcode.

---

## Scope boundary

- Included: all app-authored UI labels and accessibility labels; configuration/help/status/error/confirmation copy; task and journal controls; toast copy; menu-bar and native Settings scene text; mini-capsule text; app-generated date and duration formatting.
- Excluded: user-entered task titles and journal bodies; Notion field names/priority values and raw Notion error details; URLs; SQL/API literals; SF Symbol names; Xcode previews; the title assigned to a newly-created Notion journal page (external persisted data, requiring a separate Notion API/persistence approval).
- Fixed labels: the selector title stays `Language` and language option names stay `简体中文`, `English`, `Français` in every language.

## File map

| File | Responsibility in this change |
| --- | --- |
| `WidgetToDo/Core/Services/AppLocalizer.swift` | Authoritative complete Chinese/English/French text catalogue and format strings. |
| `WidgetToDo/Core/Models/AppMessage.swift` | Deferred, language-independent message plus optional raw arguments. |
| `WidgetToDo/LanguageStore.swift` | Render `AppMessage` from the current language. |
| `WidgetToDo/Core/Services/ConfigurationInputNormalizer.swift` | Return semantic configuration validation codes rather than Chinese user copy. |
| `WidgetToDo/Core/Services/FieldValidator.swift` | Return structured field-validation issues that can be localized at the UI boundary. |
| `WidgetToDo/Core/Infrastructure/NotionRepository.swift` | Preserve raw Notion errors; replace repository-authored Chinese wrappers with typed error cases/messages. |
| `WidgetToDo/OnboardingViewModel.swift`, `WidgetToDo/TodoListViewModel.swift`, `WidgetToDo/NewTaskViewModel.swift`, `WidgetToDo/JournalViewModel.swift` | Publish deferred `AppMessage` state, including toast and validation states. |
| `WidgetToDo/ContentView.swift`, `WidgetToDo/WelcomeView.swift`, `WidgetToDo/NewTaskFormCard.swift`, `WidgetToDo/MiniCapsuleViews.swift`, `WidgetToDo/PendingTodoRowView.swift`, `WidgetToDo/ToastHostView.swift` | Resolve all visual text through `LanguageStore`; format duration/date text for the selected language. |
| `WidgetToDo/AppDelegate.swift`, `WidgetToDo/StatusBarController.swift`, `WidgetToDo/WidgetToDoApp.swift` | Localize AppKit alert, menu, and native Settings scene strings. |
| `Tests/NotionFloatCoreTests/AppLanguageTests.swift`, `AppMessageLocalizationTests.swift`, `ConfigurationInputNormalizerTests.swift`, `TaskDateSelectionTests.swift` | Catalogue completeness, deferred formatting, semantic validation, date/duration output. |
| `Tests/NotionFloatCoreSmokeTests/main.swift` | Source-level regression coverage for language-store wiring; replace stale assertions that expect old Chinese help literals. |
| `progress.md` | Required status and evidence record after implementation. |

### Task 1: Make the localization catalogue complete and mechanically verifiable

**Files:**
- Modify: `WidgetToDo/Core/Services/AppLocalizer.swift`
- Modify: `WidgetToDo/Core/Models/AppMessage.swift`
- Modify: `WidgetToDo/LanguageStore.swift`
- Modify: `Tests/NotionFloatCoreTests/AppLanguageTests.swift`
- Modify: `Tests/NotionFloatCoreTests/AppMessageLocalizationTests.swift`

- [ ] **Step 1: Write failing catalogue and formatting tests.**

Add assertions that every `AppText.Key` exists for all three languages, the fixed selector text remains unchanged, and a message retains its raw argument while its app-authored wrapper changes:

```swift
func testAllLanguagesProvideEveryAppTextKey() {
    for language in AppLanguage.allCases {
        XCTAssertEqual(AppText.keys(in: language), Set(AppText.Key.allCases))
    }
}

func testTaskUpdateFailureFormatsForEachLanguage() {
    let message = AppMessage(.taskUpdateFailed, arguments: ["HTTP 401"])
    XCTAssertEqual(message.string(in: .simplifiedChinese), "任务更新失败：HTTP 401")
    XCTAssertEqual(message.string(in: .english), "Task update failed: HTTP 401")
    XCTAssertEqual(message.string(in: .french), "Échec de la mise à jour de la tâche : HTTP 401")
}
```

- [ ] **Step 2: Run the focused tests and verify they fail because the new keys do not exist.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter AppLanguageTests`

Expected: compile failure mentioning missing keys such as `taskUpdateFailed`.

- [ ] **Step 3: Add the complete key set and translations.**

Add keys for the audited UI groups: startup/loading, welcome/onboarding/settings, token/database fields and placeholders, reset confirmation, task toolbar/actions/errors, task form labels and validation, journal errors/retry, sync states, mini capsule/date/duration, generic actions, and AppKit alert copy. Keep formatting in the catalogue rather than concatenating translated fragments:

```swift
public enum AppText {
    public enum Key: String, CaseIterable, Hashable, Sendable {
        case taskUpdateFailed
        case taskCreateFailed
        case estimatedMinutesInvalid
        case todayTasksCapsule
        case completedCount
        case minutesSuffix
        // Include every audited application-owned string in the same enum.
    }
}

// Each language must contain every enum case. Examples:
.taskUpdateFailed: "Task update failed: %@",
.completedCount: "%@/%@ completed",
.minutesSuffix: "%@ min"
```

Keep `languageSettingTitle` as `Language` and do not add language option names to the translation catalogue.

- [ ] **Step 4: Give `LanguageStore` one canonical message resolver.**

```swift
func text(_ message: AppMessage) -> String {
    message.string(in: language)
}
```

Do not store rendered strings in view models. A language change must re-render the same key with the new language.

- [ ] **Step 5: Run focused tests and verify green.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter 'AppLanguageTests|AppMessageLocalizationTests'`

Expected: all selected tests pass.

- [ ] **Step 6: Commit the catalogue foundation.**

```bash
git add WidgetToDo/Core/Services/AppLocalizer.swift WidgetToDo/Core/Models/AppMessage.swift WidgetToDo/LanguageStore.swift Tests/NotionFloatCoreTests/AppLanguageTests.swift Tests/NotionFloatCoreTests/AppMessageLocalizationTests.swift
git commit -m "feat: complete localization message catalogue"
```

### Task 2: Localize configuration validation and onboarding status without translating remote data

**Files:**
- Modify: `WidgetToDo/Core/Services/ConfigurationInputNormalizer.swift`
- Modify: `WidgetToDo/Core/Services/FieldValidator.swift`
- Modify: `WidgetToDo/Core/Infrastructure/NotionRepository.swift`
- Modify: `WidgetToDo/OnboardingViewModel.swift`
- Modify: `WidgetToDo/ContentView.swift`
- Modify: `Tests/NotionFloatCoreTests/ConfigurationInputNormalizerTests.swift`
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] **Step 1: Replace language-dependent validation expectations with semantic test expectations.**

Make configuration validation return a stable issue kind, then test the kinds rather than Chinese source strings:

```swift
func testValidateReportsMissingToken() {
    let issues = ConfigurationInputNormalizer.validate(token: "", tasksInput: validID, journalInput: validID)
    XCTAssertEqual(issues.map(\.kind), [.missingToken])
}
```

- [ ] **Step 2: Run the focused test and verify it fails.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter ConfigurationInputNormalizerTests`

Expected: compile failure because `ValidationIssue.kind` does not exist.

- [ ] **Step 3: Add semantic issue kinds and resolve them in the view model.**

Use a stable code for app-authored validation and retain raw details only as arguments:

```swift
public struct ValidationIssue: Equatable, Sendable {
    public let kind: ValidationIssueKind
    public let details: [String]
}

public enum ValidationIssueKind: Equatable, Sendable {
    case missingToken, invalidTasksDatabaseInput, invalidJournalDatabaseInput
    case missingRequiredField, duplicateRequiredField, fieldMappingFailed
}

@Published var statusMessage: AppMessage?
```

Map `ValidationIssueKind` to `AppText.Key` in `OnboardingViewModel`; pass actual remote/property details as `AppMessage.arguments` only. Replace `OnboardingUserFacingError`’s hard-coded Chinese message with an `AppMessage(.resetConfigurationFailed)` and make `ContentView` call `languageStore.text(message)`.

- [ ] **Step 4: Replace repository-authored Chinese wrappers without changing Notion calls.**

Keep `NotionClient` request/response behavior unchanged. Convert repository-generated errors such as invalid database input, missing cache record, missing configuration, and missing token into typed cases or stable semantic kinds. `NotionClient` response text remains raw and is injected into a localized wrapper only in a view model.

- [ ] **Step 5: Update stale smoke assertions.**

Replace direct Chinese source expectations for help sheets and configuration status with assertions that the UI resolves `AppText.Key`/`AppMessage` via `languageStore`, for example:

```swift
expect(source.contains("Text(languageStore.text(message))"), "onboarding statuses should resolve through LanguageStore")
expect(!source.contains("获取 Tasks Database 链接"), "help copy should not be hard-coded in ContentView")
```

- [ ] **Step 6: Run validation and smoke tests.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter ConfigurationInputNormalizerTests`

Expected: selected tests pass.

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests`

Expected: `All smoke tests passed.`

- [ ] **Step 7: Commit onboarding and validation localization.**

```bash
git add WidgetToDo/Core/Services/ConfigurationInputNormalizer.swift WidgetToDo/Core/Services/FieldValidator.swift WidgetToDo/Core/Infrastructure/NotionRepository.swift WidgetToDo/OnboardingViewModel.swift WidgetToDo/ContentView.swift Tests/NotionFloatCoreTests/ConfigurationInputNormalizerTests.swift Tests/NotionFloatCoreSmokeTests/main.swift
git commit -m "fix: localize configuration validation and statuses"
```

### Task 3: Localize task creation, editing, deletion, retry, and toast state

**Files:**
- Modify: `WidgetToDo/TodoListViewModel.swift`
- Modify: `WidgetToDo/NewTaskViewModel.swift`
- Modify: `WidgetToDo/ToastHostView.swift`
- Modify: `WidgetToDo/NewTaskFormCard.swift`
- Modify: `WidgetToDo/ContentView.swift`
- Modify: `Tests/NotionFloatCoreTests/AppMessageLocalizationTests.swift`
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] **Step 1: Add failing deferred-message tests for task state.**

```swift
func testTaskMessagesRemainDeferredUntilRender() {
    let success = AppMessage(.taskUpdated)
    let failed = AppMessage(.taskCreateFailed, arguments: ["HTTP 500"])
    XCTAssertEqual(success.string(in: .english), "Task updated")
    XCTAssertEqual(failed.string(in: .french), "Échec de la création de la tâche : HTTP 500")
}
```

- [ ] **Step 2: Run focused tests and verify red.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter AppMessageLocalizationTests`

Expected: failure until the task keys and translations are present.

- [ ] **Step 3: Publish `AppMessage`, not rendered `String`, from task view models.**

```swift
@Published var errorMessage: AppMessage?

private func showToast(_ kind: ToastKind, message: AppMessage) {
    toast = ToastItem(kind: kind, message: message)
}

errorMessage = AppMessage(.taskUpdateFailed, arguments: [error.localizedDescription])
showToast(.success, message: AppMessage(.taskUpdated))
```

Apply this to loading/retry/update/delete/create failures, empty title, invalid estimated minutes, and success toasts. `ToastItem` must carry `AppMessage`; `ToastHostView` receives `@EnvironmentObject private var languageStore: LanguageStore` and renders `languageStore.text(toast.message)`.

- [ ] **Step 4: Replace static task form and action labels.**

In `NewTaskFormCard` and `EditTaskFormCard`, replace all fixed labels/actions/prompts with the catalogue:

```swift
Text(languageStore.text(.newTaskTitle))
NewTaskFieldLabel(text: languageStore.text(.taskTitleLabel))
Button(languageStore.text(.create)) { viewModel.submit() }
```

Also localize delete confirmation title/message/action, retry/edit/delete controls, loading copy, `Back to today`, task sync state, and estimated-minute display. Do not translate a task’s title or priority value from Notion.

- [ ] **Step 5: Add smoke checks and run the task test slice.**

```swift
expect(!source.contains("删除任务"), "task actions should not be hard-coded")
expect(source.contains("languageStore.text(.editTask)"), "edit action should resolve through LanguageStore")
```

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter 'AppMessageLocalizationTests|TaskDateSelectionTests'`

Expected: selected tests pass.

- [ ] **Step 6: Commit task interaction localization.**

```bash
git add WidgetToDo/TodoListViewModel.swift WidgetToDo/NewTaskViewModel.swift WidgetToDo/ToastHostView.swift WidgetToDo/NewTaskFormCard.swift WidgetToDo/ContentView.swift Tests/NotionFloatCoreTests/AppMessageLocalizationTests.swift Tests/NotionFloatCoreSmokeTests/main.swift
git commit -m "fix: localize task actions and toast messages"
```

### Task 4: Localize journal, dates, capsules, and empty/sync state

**Files:**
- Modify: `WidgetToDo/JournalViewModel.swift`
- Modify: `WidgetToDo/Core/Models/TodoDateDisplayFormatter.swift`
- Modify: `WidgetToDo/MiniCapsuleViews.swift`
- Modify: `WidgetToDo/PendingTodoRowView.swift`
- Modify: `WidgetToDo/ContentView.swift`
- Modify: `Tests/NotionFloatCoreTests/TaskDateSelectionTests.swift`
- Modify: `Tests/NotionFloatCoreTests/AppMessageLocalizationTests.swift`

- [ ] **Step 1: Add tests for English and French date/duration output.**

```swift
func testMonthDayUsesSelectedLanguage() {
    let date = makeDate(year: 2026, month: 7, day: 25)
    XCTAssertEqual(TodoDateDisplayFormatter.monthDayString(for: date, language: .english), "Jul 25")
    XCTAssertEqual(TodoDateDisplayFormatter.monthDayString(for: date, language: .french), "25 juil.")
}

func testDurationUsesLocalizedFormatKey() {
    XCTAssertEqual(AppText.string(.minutesSuffix, language: .english, arguments: ["30"]), "30 min")
}
```

- [ ] **Step 2: Run date tests and verify red when exact output is not yet supported.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter TaskDateSelectionTests`

Expected: a failing exact-output assertion or missing key compile error.

- [ ] **Step 3: Make journal errors and mini-capsule strings deferred.**

```swift
@Published var errorMessage: AppMessage?

errorMessage = AppMessage(.journalSaveFailed, arguments: [error.localizedDescription])

return AppText.string(
    .completedCount,
    language: language,
    arguments: [String(completedCount), String(totalCount)]
)
```

Resolve app-owned strings in `ContentView`/capsules using the current `LanguageStore`, including task/journal loading, retry, journal date, empty state, sync state, completion count, word count, and minute labels. Leave user journal text untouched.

- [ ] **Step 4: Make render-time date formatting locale-correct.**

Use `Date.FormatStyle` with `language.locale` in both task and journal date formatters; do not cache a preformatted date string in a view model. Keep the selected date as `Date`.

- [ ] **Step 5: Run focused tests and commit.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter 'TaskDateSelectionTests|AppMessageLocalizationTests'`

Expected: all selected tests pass.

```bash
git add WidgetToDo/JournalViewModel.swift WidgetToDo/Core/Models/TodoDateDisplayFormatter.swift WidgetToDo/MiniCapsuleViews.swift WidgetToDo/PendingTodoRowView.swift WidgetToDo/ContentView.swift Tests/NotionFloatCoreTests/TaskDateSelectionTests.swift Tests/NotionFloatCoreTests/AppMessageLocalizationTests.swift
git commit -m "fix: localize journal and compact widget status"
```

### Task 5: Localize the app shell, welcome flow, menu, and native settings scene

**Files:**
- Modify: `WidgetToDo/WelcomeView.swift`
- Modify: `WidgetToDo/ContentView.swift`
- Modify: `WidgetToDo/AppDelegate.swift`
- Modify: `WidgetToDo/StatusBarController.swift`
- Modify: `WidgetToDo/WidgetToDoApp.swift`
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] **Step 1: Add failing source-level checks for shell wiring.**

```swift
expect(!welcomeSource.contains("欢迎使用 WidgetToDo"), "welcome copy should not be hard-coded")
expect(appSource.contains("@StateObject private var languageStore"), "native Settings scene should observe LanguageStore")
expect(appDelegateSource.contains("languageStore.text(.startupFailed)"), "startup alert should use localized text")
```

- [ ] **Step 2: Run the smoke executable and verify red.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests`

Expected: failure on one of the new localized-shell checks.

- [ ] **Step 3: Inject the same shared language store into every shell view.**

Make `LanguageStore.shared` the one `@MainActor` instance owned for the process, then use that instance in `RootViewModel` and the SwiftUI `App`. The native Settings scene must observe that same object so changing the language refreshes every surface immediately:

```swift
@MainActor
final class LanguageStore: ObservableObject {
    static let shared = LanguageStore()
    // existing @Published language and text methods
}

// RootViewModel
let languageStore = LanguageStore.shared

// WidgetToDoApp
@ObservedObject private var languageStore = LanguageStore.shared

Text(languageStore.text(.appTitle))
Text(languageStore.text(.settingsSceneHint))
```

Make `WelcomeView` read `LanguageStore` from the environment. Replace its close accessibility label, hero text, tagline, and action text. Replace AppDelegate startup alert and RootView loading/failure copy with catalogue keys. Preserve menu keyboard shortcuts and menu command behavior.

- [ ] **Step 4: Run smoke tests and app build.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests`

Expected: `All smoke tests passed.`

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit shell localization.**

```bash
git add WidgetToDo/WelcomeView.swift WidgetToDo/ContentView.swift WidgetToDo/AppDelegate.swift WidgetToDo/StatusBarController.swift WidgetToDo/WidgetToDoApp.swift Tests/NotionFloatCoreSmokeTests/main.swift
git commit -m "fix: localize application shell and settings scene"
```

### Task 6: Exhaustive audit, verification, and documentation

**Files:**
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift`
- Modify: `progress.md`

- [ ] **Step 1: Add the final hard-coded app-text audit.**

The smoke executable should inspect only production Swift files (excluding `AppLocalizer.swift`, preview fixtures, raw API/SQL files, and tests) and fail on the audited legacy literals. Include a small explicit allow-list for `Language`, `简体中文`, `English`, `Français`, `Low`, `Medium`, `High`, and system/SF-symbol/API literals.

```swift
let forbiddenAppCopy = [
    "正在加载任务...", "删除任务", "欢迎使用 WidgetToDo",
    "今日待办", "已同步到 Notion", "日记保存失败："
]
for text in forbiddenAppCopy {
    expect(!productionSources.contains(text), "app-owned copy must come from AppText: \\(text)")
}
```

- [ ] **Step 2: Run the complete automated suite.**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox`

Expected: all XCTest cases pass.

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests`

Expected: `All smoke tests passed.`

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Perform safe runtime verification.**

Do not clear the real Keychain token or Notion configuration. Launch the existing Debug app and switch the current language through the settings selector. For each of `简体中文`, `English`, and `Français`, verify: menu items; onboarding/settings labels; task/journal tabs; task date/empty state; task form and delete confirmation; help overlays; journal sync/auto-save text; mini capsule; toast or other available status. Record unavailable states as a limitation rather than altering user data.

- [ ] **Step 4: Record evidence and commit.**

Update the `2026-07-24 - Complete localization remediation` section in `progress.md` with exact command results and the runtime verification matrix. Do not update `bugs.md` unless the user requests it or a verified recurring defect is found.

```bash
git add Tests/NotionFloatCoreSmokeTests/main.swift progress.md
git commit -m "test: audit full application localization"
```

## Plan self-review

- Spec coverage: Tasks 1–5 cover every requested application-owned text surface; Task 2 keeps remote/user data unmodified; Task 4 covers dates and compact mode; Task 6 provides a persistent audit and three-language verification.
- Scope guard: The plan intentionally excludes external Notion journal page titles and raw remote values, avoiding an unapproved Notion API/persistence contract change.
- Placeholder scan: no deferred implementation steps; every task includes concrete files, tests, commands, expected result, and commit scope.
- Type consistency: `AppText.Key` is the typed catalogue; `AppMessage` carries a key and raw arguments; `LanguageStore.shared.text(_:)` is the only render boundary for deferred messages; validation uses `ValidationIssue.kind` and view models publish `AppMessage?`.
