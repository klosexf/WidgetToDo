# Settings Reset Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a settings-only `初始化配置` module that clears the saved Notion token and database IDs, returns the app to the welcome screen, and lets the user restart onboarding from a clean configuration state without clearing local task or journal cache.

**Architecture:** Reuse the existing `NotionRepository.resetConfiguration()` persistence boundary and add the missing UI and navigation flow above it. `OnboardingView` will render the destructive section and confirmation dialog, `OnboardingViewModel` will own in-memory form reset and status updates, and `RootViewModel` will coordinate the successful transition back to `.welcome`.

**Tech Stack:** SwiftUI, Swift Concurrency, AppKit-backed macOS alert/dialog presentation through SwiftUI APIs, SwiftPM smoke tests

---

## File Map

- Modify: `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift`
  - Add source-level smoke coverage for the reset module, confirmation copy, reset API call, and welcome-screen navigation contract.
- Modify: `WidgetToDo/WidgetToDo/OnboardingViewModel.swift`
  - Expand reset behavior to clear in-memory form fields and surface readable reset status.
- Modify: `WidgetToDo/WidgetToDo/ContentView.swift`
  - Add a `RootViewModel` reset coordinator.
  - Add settings-only destructive UI, confirmation dialog, and reset button state handling inside `OnboardingView`.
- Modify: `progress.md`
  - Replace the current in-progress entry with this task’s status and verification evidence after implementation.

## Task 1: Add smoke coverage for the reset flow contract

**Files:**
- Modify: `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] **Step 1: Add a failing smoke-test entry for the settings reset contract**

Insert a new runner call near the existing source-level UI guards:

```swift
try settingsResetFlowReturnsUserToWelcome()
```

Add the guard:

```swift
static func settingsResetFlowReturnsUserToWelcome() throws {
    let rootURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let contentViewURL = rootURL
        .appendingPathComponent("WidgetToDo")
        .appendingPathComponent("ContentView.swift")
    let onboardingViewModelURL = rootURL
        .appendingPathComponent("WidgetToDo")
        .appendingPathComponent("OnboardingViewModel.swift")
    let contentSource = try String(contentsOf: contentViewURL, encoding: .utf8)
    let viewModelSource = try String(contentsOf: onboardingViewModelURL, encoding: .utf8)

    try expect(
        contentSource.contains("初始化配置"),
        "settings screen should include the reset configuration module"
    )
    try expect(
        contentSource.contains("不会清除本地缓存的任务和日记内容"),
        "reset confirmation should explain that local cached content is retained"
    )
    try expect(
        contentSource.contains("showingResetConfirmation"),
        "settings reset flow should require explicit confirmation state"
    )
    try expect(
        contentSource.contains("await rootViewModel.resetConfigurationFromSettings()"),
        "settings reset button should call the root view-model reset coordinator"
    )
    try expect(
        contentSource.contains("screen = .welcome"),
        "successful reset should return the app to the welcome screen"
    )
    try expect(
        viewModelSource.contains("try await repository.resetConfiguration()"),
        "onboarding view model should continue to reset persisted configuration via the repository"
    )
}
```

- [ ] **Step 2: Run the smoke target to verify the new guard fails before implementation**

Run: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests`

Expected: FAIL because the current settings screen does not yet contain the reset module, confirmation state, or root-level reset coordinator.

- [ ] **Step 3: Keep the guard narrow and stable**

Limit the assertions to these source-level contracts:

```swift
contentSource.contains("初始化配置")
contentSource.contains("不会清除本地缓存的任务和日记内容")
contentSource.contains("showingResetConfirmation")
contentSource.contains("await rootViewModel.resetConfigurationFromSettings()")
contentSource.contains("screen = .welcome")
viewModelSource.contains("try await repository.resetConfiguration()")
```

Do not assert colors, exact layout spacing, or alert modifier ordering.

- [ ] **Step 4: Re-run the smoke target after implementation**

Run: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests`

Expected: PASS with `All smoke tests passed.`

- [ ] **Step 5: Commit**

```bash
git add Tests/NotionFloatCoreSmokeTests/main.swift
git commit -m "test: guard settings reset flow contract"
```

## Task 2: Make reset clear only onboarding state and persist readable status

**Files:**
- Modify: `WidgetToDo/WidgetToDo/OnboardingViewModel.swift`

- [ ] **Step 1: Add a dedicated reset method that clears in-memory form state after repository reset**

Replace the minimal reset method with:

```swift
func resetConfigurationForRestart() async throws {
    isWorking = true
    statusMessage = "正在重置配置..."
    isErrorState = false
    defer { isWorking = false }

    do {
        try await repository.resetConfiguration()
        token = ""
        tasksDatabaseInput = ""
        journalDatabaseInput = ""
        statusMessage = nil
        isErrorState = false
    } catch let error as LocalizedError {
        statusMessage = error.errorDescription ?? error.localizedDescription
        isErrorState = true
        throw error
    } catch {
        statusMessage = error.localizedDescription
        isErrorState = true
        throw error
    }
}
```

This preserves the existing persistence boundary while ensuring stale values do not remain in the form after a successful reset.

- [ ] **Step 2: Keep the save path unchanged**

Do not modify these existing behaviors:

```swift
func validateAndSave() async
func normalizeTasksDatabaseInput()
func normalizeJournalDatabaseInput()
```

The only production behavior change in this file is the new reset flow wrapper around `repository.resetConfiguration()`.

- [ ] **Step 3: Re-run the smoke target after this file change**

Run: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests`

Expected: still FAIL until the settings UI and root coordinator are added, but no new compile-time errors should be introduced by the view-model rename or implementation.

- [ ] **Step 4: Commit**

```bash
git add WidgetToDo/OnboardingViewModel.swift
git commit -m "feat: reset onboarding form state after config clear"
```

## Task 3: Add a root-level reset coordinator that returns to welcome

**Files:**
- Modify: `WidgetToDo/WidgetToDo/ContentView.swift`

- [ ] **Step 1: Add a `RootViewModel` reset coordinator method**

Inside `RootViewModel`, add:

```swift
func resetConfigurationFromSettings() async {
    do {
        try await onboardingViewModel.resetConfigurationForRestart()
        screenBeforeSettings = .welcome
        bannerMessage = nil
        screen = .welcome
    } catch {
        onboardingViewModel.statusMessage = "初始化配置失败：\(error.localizedDescription)"
        onboardingViewModel.isErrorState = true
    }
}
```

This keeps navigation ownership inside the root view model and avoids direct screen mutation from the settings view.

- [ ] **Step 2: Keep existing navigation paths intact**

Do not change the existing meanings of:

```swift
func bootstrap() async
func openSettings()
func returnFromSettings()
```

The reset coordinator is additive and should not alter how normal settings open/save/back behavior works.

- [ ] **Step 3: Re-run the smoke target**

Run: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests`

Expected: still FAIL until the settings UI references `await rootViewModel.resetConfigurationFromSettings()`.

- [ ] **Step 4: Commit**

```bash
git add WidgetToDo/ContentView.swift
git commit -m "feat: route settings reset back to welcome"
```

## Task 4: Add the destructive settings module, confirmation dialog, and in-flight feedback

**Files:**
- Modify: `WidgetToDo/WidgetToDo/ContentView.swift`

- [ ] **Step 1: Thread a reset callback into the settings-screen render path**

Change the settings case in `ContentView` from:

```swift
OnboardingView(
    viewModel: rootViewModel.onboardingViewModel,
    mode: .settings,
    onBack: rootViewModel.returnFromSettings
)
```

to:

```swift
OnboardingView(
    viewModel: rootViewModel.onboardingViewModel,
    mode: .settings,
    onBack: rootViewModel.returnFromSettings,
    onResetConfiguration: {
        await rootViewModel.resetConfigurationFromSettings()
    }
)
```

- [ ] **Step 2: Add local state for reset confirmation presentation**

Inside `OnboardingView`, add:

```swift
var onResetConfiguration: (() async -> Void)?
@State private var showingResetConfirmation = false
```

Keep `showingResetConfirmation` local to the view because it is transient presentation state, not app model state.

- [ ] **Step 3: Render a settings-only destructive section**

Add a new block near the bottom of the settings form, after the normal configuration sections and before the save button:

```swift
if mode == .settings {
    resetConfigurationSection
}
```

Implement:

```swift
private var resetConfigurationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("初始化配置")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(OnboardingModalPalette.primaryText)

        Text("清除当前保存的 Notion Token 与数据库配置，并返回欢迎页重新开始。不会清除本地缓存的任务和日记内容。")
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(OnboardingModalPalette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

        Button {
            showingResetConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                Text("初始化配置")
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(DestructiveSecondaryButtonStyle())
        .disabled(viewModel.isWorking)
    }
    .padding(16)
    .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(OnboardingModalPalette.inputFill)
    )
    .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(OnboardingModalPalette.errorBorder.opacity(0.55), lineWidth: 1)
    )
}
```

- [ ] **Step 4: Add a destructive secondary button style local to `ContentView.swift`**

Add:

```swift
private struct DestructiveSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white.opacity(isEnabled ? 1 : 0.82))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 191 / 255, green: 64 / 255, blue: 64 / 255))
            )
            .opacity(configuration.isPressed ? 0.9 : (isEnabled ? 1 : 0.65))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
```

- [ ] **Step 5: Present a confirmation dialog and execute the reset only after confirmation**

Attach this to `OnboardingView.body`:

```swift
.confirmationDialog(
    "初始化配置",
    isPresented: $showingResetConfirmation,
    titleVisibility: .visible
) {
    Button("确认初始化配置", role: .destructive) {
        Task {
            await onResetConfiguration?()
        }
    }
    Button("取消", role: .cancel) {}
} message: {
    Text("这会清除当前保存的 Notion Token 和数据库配置，但不会清除本地缓存的任务和日记内容。完成后将返回欢迎页。")
}
```

- [ ] **Step 6: Keep reset progress feedback visible through the existing banner system**

Do not add a second spinner-only status surface. Let the view model drive the banner copy:

```swift
statusMessage = "正在重置配置..."
```

The button remains disabled via `viewModel.isWorking`, which prevents duplicate submissions while the banner communicates progress.

- [ ] **Step 7: Re-run the smoke target**

Run: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests`

Expected: PASS with `All smoke tests passed.`

- [ ] **Step 8: Commit**

```bash
git add WidgetToDo/ContentView.swift
git commit -m "feat: add settings reset configuration module"
```

## Task 5: Run repo verification and record progress

**Files:**
- Modify: `progress.md`

- [ ] **Step 1: Run the smoke target explicitly**

Run: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests`

Expected: PASS with `All smoke tests passed.`

- [ ] **Step 2: Run the full SwiftPM test suite**

Run: `cd WidgetToDo && swift test`

Expected: PASS. If the environment still returns `no such module 'XCTest'`, record that exact blocker in `progress.md` instead of marking verification complete.

- [ ] **Step 3: Perform manual UI validation if the local app can be launched**

Manual checklist:

1. Open the app in a configured state.
2. Open `设置`.
3. Verify the `初始化配置` module is visible and visually distinct from `保存设置`.
4. Click `初始化配置`, then click `取消`.
5. Verify the token and database inputs remain unchanged.
6. Click `初始化配置` again and confirm.
7. Verify `正在重置配置...` appears and the reset button is disabled during execution.
8. Verify the app returns to the welcome screen.
9. Click the welcome CTA and verify onboarding opens with empty inputs.
10. Verify no code path attempted to clear cached task/journal content.

If local app launch is blocked, record the exact blocker.

- [ ] **Step 4: Update `progress.md` with the current task and evidence**

Replace the previous in-progress entry with a new item for this work. Include:

```markdown
### TASK-032
- 目标: 在设置页新增“初始化配置”模块，支持确认后清空 token + 数据库 ID + 配置流程状态，并返回欢迎页重新开始；保留本地任务/日记缓存
- 状态: <进行中/已完成/阻塞>
- 改动:
  - `WidgetToDo/WidgetToDo/ContentView.swift` ...
  - `WidgetToDo/WidgetToDo/OnboardingViewModel.swift` ...
  - `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift` ...
- 验证:
  - 命令: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests` — <结果>
  - 命令: `cd WidgetToDo && swift test` — <结果>
  - 手测: 设置页初始化配置取消/确认流程 — <结果或阻塞原因>
- 下一步: <若仍有阻塞则写明；若完成则写 `<!-- 无 -->`>
```

- [ ] **Step 5: Commit**

```bash
git add progress.md
git commit -m "docs: record settings reset verification"
```

## Self-Review

- Spec coverage check:
  - settings-only destructive module: Task 4
  - confirmation and misoperation protection: Task 4
  - reset only token + database IDs + onboarding state: Task 2 and Task 3
  - return to welcome and restart onboarding: Task 3 and Task 5 manual check
  - preserve local cache: guarded by spec-constrained implementation and manual verification in Task 5
- Placeholder scan:
  - no `TODO` / `TBD`
  - all file paths and commands are explicit
  - all new function/property names are spelled consistently across tasks
- Type consistency check:
  - `resetConfigurationForRestart()` is the single new view-model reset API
  - `resetConfigurationFromSettings()` is the single root-level coordinator
  - `showingResetConfirmation` is the single settings-view confirmation state
