# Onboarding Modal HTML Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the SwiftUI onboarding and settings modal visuals with scaled ports of `#connectModal` and `#settingsModal` from `WidgetToDo-Welcome-Modal.html`, while preserving all existing bindings, validation, save flow, and navigation behavior.

**Architecture:** Keep the implementation local to `WidgetToDo/WidgetToDo/ContentView.swift` by rebuilding `OnboardingView` into two mode-specific render paths backed by shared local styling helpers. Use source-level smoke tests to protect the behavior contract, then verify the final result with app-level manual UI checks because SwiftPM cannot fully exercise these SwiftUI views.

**Tech Stack:** SwiftUI, AppKit-backed hover behavior on macOS, Swift Concurrency, SwiftPM smoke tests, Xcode app target assets

---

## File Map

- Modify: `WidgetToDo/WidgetToDo/ContentView.swift`
  - Rebuild `OnboardingView` into HTML-mapped onboarding and settings layouts.
  - Add local metrics, colors, input chrome helpers, status banner styling, and custom primary button styling.
  - Add onboarding-only top-left back action that returns to welcome without clearing current inputs.
- Modify: `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift`
  - Add source-level smoke guards for copy, `SecureField`, help sheet trigger, normalization hooks, and mode-specific primary button labels.
- Modify: `progress.md`
  - Record plan completion now, then implementation progress and verification results after code changes.

## Task 1: Add smoke coverage for the modal behavior contract

**Files:**
- Modify: `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] **Step 1: Add a failing smoke test entry for the onboarding / settings modal source contract**

Insert a new runner call near the existing source-level UI guards:

```swift
try onboardingViewRetainsBehaviorWhileSwitchingToHtmlParityLayout()
```

Add the function:

```swift
static func onboardingViewRetainsBehaviorWhileSwitchingToHtmlParityLayout() throws {
    let rootURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let contentViewURL = rootURL
        .appendingPathComponent("WidgetToDo")
        .appendingPathComponent("ContentView.swift")
    let source = try String(contentsOf: contentViewURL, encoding: .utf8)

    try expect(
        source.contains("SecureField("),
        "configuration modal should keep SecureField for token entry"
    )
    try expect(
        source.contains("isShowingTokenHelp = true"),
        "configuration modal should keep the token help trigger"
    )
    try expect(
        source.contains("validateAndSave()"),
        "configuration modal should keep the existing save action"
    )
    try expect(
        source.contains("normalizeTasksDatabaseInput()"),
        "tasks database input should still normalize on change"
    )
    try expect(
        source.contains("normalizeJournalDatabaseInput()"),
        "journal database input should still normalize on change"
    )
    try expect(
        source.contains("内容 / 初始配置"),
        "onboarding mode should adopt the HTML title-bar copy"
    )
    try expect(
        source.contains("保存设置"),
        "settings mode should keep the existing save action semantics"
    )
}
```

- [ ] **Step 2: Run the smoke test to verify it fails for the right reason before implementation**

Run: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests`

Expected: FAIL because `ContentView.swift` still contains the old onboarding copy and layout.

- [ ] **Step 3: Keep the guard focused on stable behavior and copy only**

Do not assert exact padding, color literals, or view ordering. Keep the contract limited to:

```swift
source.contains("SecureField(")
source.contains("validateAndSave()")
source.contains("normalizeTasksDatabaseInput()")
source.contains("normalizeJournalDatabaseInput()")
source.contains("内容 / 初始配置")
source.contains("保存设置")
```

This keeps the smoke test durable while layout tuning happens.

- [ ] **Step 4: Re-run the smoke test after the implementation task**

Run: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests`

Expected: PASS with `All smoke tests passed.`

- [ ] **Step 5: Commit**

```bash
git add Tests/NotionFloatCoreSmokeTests/main.swift
git commit -m "test: guard onboarding modal behavior contract"
```

## Task 2: Rebuild `OnboardingView` into mode-specific HTML-mapped layouts

**Files:**
- Modify: `WidgetToDo/WidgetToDo/ContentView.swift`

- [ ] **Step 1: Add local metrics and colors for the modal port**

Add local constants above `OnboardingView`:

```swift
private enum OnboardingModalMetrics {
    static let outerPadding: CGFloat = 18
    static let titleBarHeight: CGFloat = 42
    static let modalCornerRadius: CGFloat = 16
    static let sectionSpacing: CGFloat = 18
    static let fieldSpacing: CGFloat = 8
    static let inputHeight: CGFloat = 42
    static let inputCornerRadius: CGFloat = 12
    static let buttonHeight: CGFloat = 44
    static let heroIconSize: CGFloat = 68
    static let buttonCornerRadius: CGFloat = 12
}

private enum OnboardingModalColors {
    static let title = Color(red: 45 / 255, green: 45 / 255, blue: 45 / 255)
    static let body = Color(red: 104 / 255, green: 104 / 255, blue: 104 / 255)
    static let border = Color.black.opacity(0.08)
    static let softFill = Color.white
    static let mutedFill = Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255)
    static let buttonFill = Color(red: 45 / 255, green: 45 / 255, blue: 45 / 255)
    static let successFill = Color(red: 245 / 255, green: 248 / 255, blue: 245 / 255)
    static let successText = Color(red: 74 / 255, green: 119 / 255, blue: 74 / 255)
    static let errorFill = Color(red: 253 / 255, green: 244 / 255, blue: 244 / 255)
    static let errorText = Color(red: 176 / 255, green: 62 / 255, blue: 62 / 255)
}
```

- [ ] **Step 2: Add a custom primary button style with hover and pressed states**

Add a local button style:

```swift
private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: OnboardingModalMetrics.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: OnboardingModalMetrics.buttonCornerRadius, style: .continuous)
                    .fill(OnboardingModalColors.buttonFill.opacity(isEnabled ? 1 : 0.65))
            )
            .shadow(
                color: .black.opacity(isHovered ? 0.18 : 0.12),
                radius: isHovered ? 14 : 10,
                x: 0,
                y: isHovered ? 8 : 5
            )
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .offset(y: isHovered && !configuration.isPressed ? -1 : 0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.2), value: isHovered)
    }
}
```

- [ ] **Step 3: Split `OnboardingView` into onboarding and settings render branches**

Replace the current shared `VStack` body with:

```swift
@State private var isShowingTokenHelp = false
@State private var isPrimaryHovered = false
@State private var isAppeared = false

var body: some View {
    Group {
        switch mode {
        case .onboarding:
            onboardingModalBody
        case .settings:
            settingsModalBody
        }
    }
    .padding(OnboardingModalMetrics.outerPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .opacity(isAppeared ? 1 : 0)
    .offset(y: isAppeared ? 0 : 10)
    .animation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.32), value: isAppeared)
    .onAppear {
        guard !isAppeared else { return }
        isAppeared = true
    }
    .sheet(isPresented: $isShowingTokenHelp) {
        NotionTokenHelpView()
    }
}
```

- [ ] **Step 4: Build the onboarding-mode structure to match `#connectModal`**

Add:

```swift
private var onboardingModalBody: some View {
    VStack(spacing: 0) {
        modalHeader(title: "内容 / 初始配置")
        VStack(alignment: .leading, spacing: OnboardingModalMetrics.sectionSpacing) {
            onboardingHero
            tokenSection
            databaseSection(
                title: "Tasks Database",
                placeholder: "粘贴任务数据库链接",
                text: $viewModel.tasksDatabaseInput,
                normalize: viewModel.normalizeTasksDatabaseInput
            )
            databaseSection(
                title: "Journal Database",
                placeholder: "粘贴日记数据库链接",
                text: $viewModel.journalDatabaseInput,
                normalize: viewModel.normalizeJournalDatabaseInput
            )
            statusBanner
            primaryActionButton(title: "验证并继续")
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 18)
    }
    .background(modalSurface)
}
```

- [ ] **Step 5: Build the settings-mode structure to match `#settingsModal`**

Add:

```swift
private var settingsModalBody: some View {
    VStack(spacing: 0) {
        modalHeader(title: "设置")
        VStack(alignment: .leading, spacing: OnboardingModalMetrics.sectionSpacing) {
            settingsBackButton
            VStack(alignment: .leading, spacing: 8) {
                Text("设置")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(OnboardingModalColors.title)
                Text("这个版本需要一个 Notion 集成令牌，以及一个任务数据库和一个日记数据库。")
                    .font(.system(size: 14))
                    .foregroundStyle(OnboardingModalColors.body)
            }
            tokenSection
            databaseSection(
                title: "Tasks Database",
                placeholder: "粘贴任务数据库链接",
                text: $viewModel.tasksDatabaseInput,
                normalize: viewModel.normalizeTasksDatabaseInput
            )
            databaseSection(
                title: "Journal Database",
                placeholder: "粘贴日记数据库链接",
                text: $viewModel.journalDatabaseInput,
                normalize: viewModel.normalizeJournalDatabaseInput
            )
            statusBanner
            primaryActionButton(title: "保存设置")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }
    .background(modalSurface)
}
```

- [ ] **Step 6: Add shared helper views without changing bindings or actions**

Add these helpers and keep logic untouched:

```swift
private var modalSurface: some View {
    RoundedRectangle(cornerRadius: OnboardingModalMetrics.modalCornerRadius, style: .continuous)
        .fill(Color.white)
        .shadow(color: .black.opacity(0.06), radius: 24, x: 0, y: 12)
}

private func modalHeader(title: String) -> some View { /* title + visual close area */ }
private var onboardingHero: some View { /* icon + 连接 Notion + two-line desc */ }
private var tokenSection: some View { /* help link + SecureField shell + security note */ }
private func databaseSection(title: String, placeholder: String, text: Binding<String>, normalize: @escaping () -> Void) -> some View { /* input shell + onChange */ }
private var statusBanner: some View { /* collapse when no message; color by isErrorState */ }
private func primaryActionButton(title: String) -> some View { /* Task { await viewModel.validateAndSave() } */ }
private var settingsBackButton: some View { /* Button { onBack?() } label: { ... } */ }
```

Constraints for these helpers:

- onboarding mode must expose a real top-left back action that returns to welcome while preserving current `OnboardingViewModel` field values

- token field must stay:

```swift
SecureField("输入你的 Notion Token", text: $viewModel.token)
```

- tasks field must keep:

```swift
.onChange(of: viewModel.tasksDatabaseInput) { _ in
    viewModel.normalizeTasksDatabaseInput()
}
```

- journal field must keep:

```swift
.onChange(of: viewModel.journalDatabaseInput) { _ in
    viewModel.normalizeJournalDatabaseInput()
}
```

- help link must keep:

```swift
Button {
    isShowingTokenHelp = true
} label: {
    Text("如何获取？")
}
```

- primary action must keep:

```swift
Task {
    await viewModel.validateAndSave()
}
```

- [ ] **Step 7: Use the existing local image asset for the onboarding hero**

Inside `onboardingHero`, render the same source used by the HTML workflow if the asset is available in the app target:

```swift
Image("WelcomeIllustration")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: OnboardingModalMetrics.heroIconSize, height: OnboardingModalMetrics.heroIconSize)
```

If `WelcomeIllustration` is not the correct asset for the left hero icon, replace only the asset name with the app-target-available icon source. Do not fall back to SF Symbols in the final implementation.

- [ ] **Step 8: Run the smoke test and keep iterating until it passes**

Run: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests`

Expected: PASS with `All smoke tests passed.`

- [ ] **Step 9: Commit**

```bash
git add WidgetToDo/ContentView.swift Tests/NotionFloatCoreSmokeTests/main.swift
git commit -m "feat: port onboarding modals to html parity layout"
```

## Task 3: Verify full test and manual UI behavior

**Files:**
- Modify: `progress.md`

- [ ] **Step 1: Run the full SwiftPM test suite**

Run: `cd WidgetToDo && swift test`

Expected: either PASS, or the known environment failure is reproduced exactly and recorded verbatim.

- [ ] **Step 2: Perform manual onboarding-mode verification in the app**

Manual check list:

- app opens into onboarding mode when bootstrap is incomplete
- title bar top-left back button returns to welcome
- after returning to welcome and re-entering onboarding, previously typed `token` / `tasksDatabaseInput` / `journalDatabaseInput` values are still present
- title bar shows `内容 / 初始配置`
- hero block matches the HTML structure
- `如何获取？` still opens the help sheet
- token input still behaves as secure entry
- tasks / journal URL paste still auto-normalizes after change
- `验证并继续` still triggers the existing save flow
- hover / press states render correctly on the primary button

- [ ] **Step 3: Perform manual settings-mode verification in the app**

Manual check list:

- settings screen title bar shows `设置`
- back button still returns through `onBack`
- heading copy matches the HTML settings modal
- input sections, status banner, and button match the target style
- `保存设置` still triggers the existing save flow

- [ ] **Step 4: Record verification results in `progress.md`**

Add or update the active task entry with:

```md
- 验证:
  - 命令: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests` — 通过，`All smoke tests passed.`
  - 命令: `cd WidgetToDo && swift test` — <通过或阻塞详情>
  - 手测: onboarding / settings 模式分别验证标题栏、输入、帮助弹窗、返回、按钮、状态提示 — <结果摘要>
```

- [ ] **Step 5: Commit**

```bash
git add progress.md
git commit -m "docs: record onboarding modal parity verification"
```

## Self-Review

- Spec coverage:
  - `#connectModal` 映射: Task 2 Steps 3-7
  - `#settingsModal` 映射: Task 2 Steps 3-6
  - 文案切换到 HTML: Task 1 Step 1, Task 2 Steps 4-6
  - 逻辑不变约束: Task 1 Step 1, Task 2 Step 6
  - 按钮动画和状态提示: Task 2 Steps 2 and 6
  - 自动化与手测验证: Task 3
- Placeholder scan: no `TODO` / `TBD` placeholders left in executable steps.
- Type consistency:
  - `OnboardingView`, `OnboardingViewModel`, `validateAndSave()`, `normalizeTasksDatabaseInput()`, and `normalizeJournalDatabaseInput()` match the current codebase names.
