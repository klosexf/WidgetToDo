# Onboarding Modal Visual Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retune the SwiftUI onboarding-only "连接 Notion" modal so its typography, spacing, and control sizing visually align with `#connectModal` in `WidgetToDo-Welcome-Modal.html` without changing any existing behavior.

**Architecture:** Keep the change local to `WidgetToDo/ContentView.swift`. Protect the behavior contract with one source-level smoke test in `Tests/NotionFloatCoreSmokeTests/main.swift`, then apply onboarding-only metric adjustments so settings mode and business flow remain untouched.

**Tech Stack:** SwiftUI, Swift Concurrency, SwiftPM smoke tests, XCTest-backed `swift test`, Xcode app runtime for manual UI verification

---

## File Map

- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift`
  - Add a source-level smoke guard proving onboarding visual work keeps the existing bindings, save action, and help trigger, while staying onboarding-only.
- Modify: `WidgetToDo/ContentView.swift`
  - Adjust onboarding-only modal metrics and view modifiers for header density, hero sizing, form spacing, input chrome, status banner, and primary button.
- Modify: `../progress.md`
  - Record the active task, code changes, and verification results after implementation.

## Task 1: Add a smoke guard for the onboarding visual-only contract

**Files:**
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] **Step 1: Add the new smoke test call to the runner**

Insert the new call near the existing configuration-related smoke tests inside `main()`:

```swift
try onboardingVisualAlignmentKeepsExistingBehaviorContract()
```

The surrounding block should read:

```swift
try welcomeViewUsesDedicatedIllustrationAssetAndCallback()
try configurationFormContainsSettingsHelpAndExtractionCopy()
try onboardingVisualAlignmentKeepsExistingBehaviorContract()
try settingsResetFlowReturnsUserToWelcome()
try statusBarMenuContainsSettingsEntry()
```

- [ ] **Step 2: Add the source-level smoke test implementation**

Append this function inside `NotionFloatCoreSmokeTestsRunner` next to the other `ContentView.swift` source guards:

```swift
static func onboardingVisualAlignmentKeepsExistingBehaviorContract() throws {
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
        "onboarding modal should keep SecureField token entry"
    )
    try expect(
        source.contains("isShowingTokenHelp = true"),
        "onboarding modal should keep the token help trigger"
    )
    try expect(
        source.contains("await viewModel.validateAndSave()"),
        "onboarding modal should keep the existing validate-and-save action"
    )
    try expect(
        source.contains("normalizeTasksDatabaseInput()"),
        "tasks database field should still normalize URL input"
    )
    try expect(
        source.contains("normalizeJournalDatabaseInput()"),
        "journal database field should still normalize URL input"
    )
    try expect(
        source.contains("mode == .settings ? \"保存设置\" : \"验证并继续\""),
        "primary action copy should remain mode-specific"
    )
}
```

- [ ] **Step 3: Run the smoke target before visual edits**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift run NotionFloatCoreSmokeTests
```

Expected:

- The new smoke test compiles and passes.
- If the run still fails, it should fail on a pre-existing unrelated smoke assertion rather than on the new onboarding contract guard.

- [ ] **Step 4: Keep the smoke guard intentionally narrow**

Do not assert exact spacing, fonts, or pixel values in the smoke test. The contract for this task is only:

- onboarding keeps the same bound control types
- token help still opens from the same trigger path
- save still goes through `validateAndSave()`
- URL normalization hooks still exist
- settings copy path is still present

- [ ] **Step 5: Commit the test guard**

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo
git add Tests/NotionFloatCoreSmokeTests/main.swift
git commit -m "test: guard onboarding visual alignment contract"
```

## Task 2: Retune onboarding-only modal metrics in `ContentView.swift`

**Files:**
- Modify: `WidgetToDo/ContentView.swift`

- [ ] **Step 1: Add onboarding-only metric constants instead of mutating shared settings spacing blindly**

Expand `OnboardingModalMetrics` with onboarding-specific constants:

```swift
private enum OnboardingModalMetrics {
    static let horizontalPadding: CGFloat = 24
    static let onboardingHorizontalPadding: CGFloat = 16
    static let onboardingTopPadding: CGFloat = 20
    static let onboardingBottomPadding: CGFloat = 20
    static let onboardingContentSpacing: CGFloat = 18
    static let onboardingHeroSpacing: CGFloat = 14
    static let onboardingHeroIllustrationSize: CGFloat = 68
    static let onboardingHeroTextSpacing: CGFloat = 6
    static let onboardingSectionSpacing: CGFloat = 8
    static let onboardingInputHorizontalPadding: CGFloat = 12
    static let onboardingInputVerticalPadding: CGFloat = 10
    static let onboardingInputIconSpacing: CGFloat = 8
    static let onboardingInputIconSize: CGFloat = 13
    static let onboardingInputIconWidth: CGFloat = 14
    static let onboardingStatusHorizontalPadding: CGFloat = 12
    static let onboardingStatusVerticalPadding: CGFloat = 10
    static let onboardingButtonHeight: CGFloat = 44
    static let onboardingButtonSpacing: CGFloat = 8
    static let onboardingButtonHoverOffset: CGFloat = 2
    static let settingsContentSpacing: CGFloat = 18
    static let cardCornerRadius: CGFloat = 18
}
```

Keep existing settings metrics unchanged.

- [ ] **Step 2: Apply onboarding-only body padding and section spacing**

Update the `ScrollView` content padding and stack spacing:

```swift
VStack(
    alignment: .leading,
    spacing: mode == .onboarding
        ? OnboardingModalMetrics.onboardingContentSpacing
        : OnboardingModalMetrics.settingsContentSpacing
) {
    if mode == .settings {
        settingsIntro
    } else {
        onboardingHero
    }

    tokenSection
    databaseSection(
        title: mode == .settings ? "Tasks Database ID" : "Tasks Database",
        placeholder: mode == .settings ? "任务数据库 ID" : "粘贴任务数据库链接",
        text: $viewModel.tasksDatabaseInput,
        normalize: viewModel.normalizeTasksDatabaseInput
    )
    databaseSection(
        title: mode == .settings ? "Journal Database ID" : "Journal Database",
        placeholder: mode == .settings ? "日记数据库 ID" : "粘贴日记数据库链接",
        text: $viewModel.journalDatabaseInput,
        normalize: viewModel.normalizeJournalDatabaseInput
    )

    if let message = viewModel.statusMessage {
        statusBanner(message: message)
    }

    if mode == .settings {
        resetSection
    }

    primaryButton
}
.padding(.horizontal, mode == .onboarding
    ? OnboardingModalMetrics.onboardingHorizontalPadding
    : OnboardingModalMetrics.horizontalPadding
)
.padding(.top, mode == .onboarding
    ? OnboardingModalMetrics.onboardingTopPadding
    : 18
)
.padding(.bottom, mode == .onboarding
    ? OnboardingModalMetrics.onboardingBottomPadding
    : 24
)
```

This keeps settings untouched while bringing onboarding closer to the HTML `modal-body` rhythm.

- [ ] **Step 3: Retune the header density for onboarding mode only**

Change `modalHeader` padding to branch by mode:

```swift
.padding(.horizontal, mode == .onboarding ? 16 : 24)
.padding(.vertical, mode == .onboarding ? 14 : 16)
```

Do not change:

- `onBack()` wiring
- settings-mode disabled logic
- divider rendering
- title strings

- [ ] **Step 4: Retune `onboardingHero` to match the HTML proportions**

Update the hero block:

```swift
private var onboardingHero: some View {
    HStack(alignment: .top, spacing: OnboardingModalMetrics.onboardingHeroSpacing) {
        Image("ConnectModalHero")
            .resizable()
            .scaledToFit()
            .frame(
                width: OnboardingModalMetrics.onboardingHeroIllustrationSize,
                height: OnboardingModalMetrics.onboardingHeroIllustrationSize
            )
            .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: OnboardingModalMetrics.onboardingHeroTextSpacing) {
            Text("连接 Notion")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(OnboardingModalPalette.primaryText)
            Text("使用你的 Notion 工作区\n同步任务与日记内容")
                .font(.system(size: 13))
                .foregroundStyle(OnboardingModalPalette.secondaryText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

This is the largest visual correction in the task.

- [ ] **Step 5: Tighten token and database section typography / spacing**

Update `tokenSection`:

```swift
private var tokenSection: some View {
    VStack(alignment: .leading, spacing: OnboardingModalMetrics.onboardingSectionSpacing) {
        HStack(alignment: .firstTextBaseline) {
            Text("Notion Token")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OnboardingModalPalette.primaryText)
            Spacer()
            Button {
                isShowingTokenHelp = true
            } label: {
                HStack(spacing: 4) {
                    Text("如何获取？")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(OnboardingModalPalette.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("如何获取？")
        }

        inputShell(icon: "lock", placeholder: "输入你的 Notion Token") {
            SecureField(
                "",
                text: $viewModel.token,
                prompt: Text("输入你的 Notion Token")
                    .foregroundColor(OnboardingModalPalette.placeholderText)
            )
            .textFieldStyle(.plain)
            .disabled(viewModel.isWorking)
            .accessibilityLabel("Notion Token")
        }

        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "lock")
                .font(.system(size: 10, weight: .medium))
            Text(mode == .settings ? "令牌只保存在本机钥匙串。" : "令牌只保存在本机钥匙串中，安全加密存储。")
                .font(.system(size: 12))
        }
        .foregroundStyle(OnboardingModalPalette.secondaryText)
    }
}
```

Update `databaseSection` with the same outer spacing and a slightly smaller label hierarchy:

```swift
VStack(alignment: .leading, spacing: OnboardingModalMetrics.onboardingSectionSpacing) {
    HStack(alignment: .firstTextBaseline) {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(OnboardingModalPalette.primaryText)
        Spacer()
        Text("粘贴整个URL自动提取")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(OnboardingModalPalette.secondaryText)
    }

    inputShell(icon: "doc.text", placeholder: placeholder) {
        TextField(
            "",
            text: text,
            prompt: Text(placeholder)
                .foregroundColor(OnboardingModalPalette.placeholderText)
        )
        .textFieldStyle(.plain)
        .disabled(viewModel.isWorking)
        .accessibilityLabel(title)
        .onChange(of: text.wrappedValue) { _ in
            normalize()
        }
    }
}
```

Leave all `SecureField`, `TextField`, and `.onChange` bindings exactly as they are.

- [ ] **Step 6: Retune `inputShell` so onboarding fields land near the HTML control height**

Branch `inputShell` by mode without creating a new control type:

```swift
private func inputShell<Field: View>(icon: String, placeholder: String, @ViewBuilder field: () -> Field) -> some View {
    HStack(spacing: mode == .onboarding
        ? OnboardingModalMetrics.onboardingInputIconSpacing
        : 10
    ) {
        Image(systemName: icon)
            .font(.system(
                size: mode == .onboarding
                    ? OnboardingModalMetrics.onboardingInputIconSize
                    : 14,
                weight: .medium
            ))
            .foregroundStyle(OnboardingModalPalette.tertiaryText)
            .frame(width: mode == .onboarding
                ? OnboardingModalMetrics.onboardingInputIconWidth
                : 16
            )

        field()
            .font(.system(size: mode == .onboarding ? 13 : 14))
            .foregroundStyle(OnboardingModalPalette.primaryText)
    }
    .padding(.horizontal, mode == .onboarding
        ? OnboardingModalMetrics.onboardingInputHorizontalPadding
        : 14
    )
    .padding(.vertical, mode == .onboarding
        ? OnboardingModalMetrics.onboardingInputVerticalPadding
        : 12
    )
    .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(OnboardingModalPalette.inputBackground)
    )
    .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(OnboardingModalPalette.inputBorder, lineWidth: 1)
    )
}
```

This preserves native editing behavior while reducing control bulk.

- [ ] **Step 7: Reduce `statusBanner` and `primaryButton` optical weight for onboarding**

Update `statusBanner` padding and icon sizing to branch by mode:

```swift
HStack(alignment: .top, spacing: mode == .onboarding ? 8 : 10) {
    Image(systemName: viewModel.isErrorState ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
        .font(.system(size: mode == .onboarding ? 14 : 15, weight: .semibold))
    Text(message)
        .font(.system(size: mode == .onboarding ? 12 : 13))
        .fixedSize(horizontal: false, vertical: true)
}
.padding(.horizontal, mode == .onboarding
    ? OnboardingModalMetrics.onboardingStatusHorizontalPadding
    : 14
)
.padding(.vertical, mode == .onboarding
    ? OnboardingModalMetrics.onboardingStatusVerticalPadding
    : 12
)
```

Update `primaryButton`:

```swift
HStack(spacing: mode == .onboarding
    ? OnboardingModalMetrics.onboardingButtonSpacing
    : 10
) {
    if viewModel.isWorking {
        ProgressView()
            .controlSize(.small)
            .tint(.white)
    } else {
        notionMark
    }

    Text(mode == .settings ? "保存设置" : "验证并继续")
        .font(.system(size: mode == .onboarding ? 13 : 14, weight: .semibold))

    if !viewModel.isWorking {
        Image(systemName: "arrow.right")
            .font(.system(size: mode == .onboarding ? 12 : 13, weight: .semibold))
            .offset(x: isPrimaryButtonHovered
                ? (mode == .onboarding ? OnboardingModalMetrics.onboardingButtonHoverOffset : 3)
                : 0
            )
    }
}
.frame(maxWidth: .infinity)
.frame(height: mode == .onboarding
    ? OnboardingModalMetrics.onboardingButtonHeight
    : 48
)
```

Also shrink `notionMark` slightly for onboarding:

```swift
let markSize: CGFloat = mode == .onboarding ? 16 : 18
let cornerRadius: CGFloat = mode == .onboarding ? 3.5 : 4
let fontSize: CGFloat = mode == .onboarding ? 9 : 10
```

- [ ] **Step 8: Run focused source inspection after editing**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo
rg -n "onboardingHorizontalPadding|onboardingHeroIllustrationSize|mode == \\.onboarding \\? 16 : 24|await viewModel\\.validateAndSave\\(\\)" WidgetToDo/ContentView.swift
```

Expected:

- onboarding-only metrics are present
- header padding branches by mode
- save path still points to `await viewModel.validateAndSave()`

- [ ] **Step 9: Commit the onboarding visual retune**

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo
git add WidgetToDo/ContentView.swift
git commit -m "style: align onboarding modal with html reference"
```

## Task 3: Verify and sync progress

**Files:**
- Modify: `../progress.md`

- [ ] **Step 1: Re-run the smoke target after the visual edit**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift run NotionFloatCoreSmokeTests
```

Expected:

- the onboarding visual-alignment guard passes
- if the target still fails, record the first unrelated blocking assertion exactly

- [ ] **Step 2: Run the required repo-level verification**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift test
```

Expected:

- PASS if the environment has usable XCTest wiring
- otherwise record the exact failure text, because AGENTS requires explicit blocking evidence rather than an assumption

- [ ] **Step 3: If Xcode is available, perform onboarding-modal manual UI verification**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build
```

Then launch the app in a full Xcode runtime and verify:

- onboarding header density is tighter than before
- hero icon is closer to the HTML 68px proportion
- title/body text hierarchy matches the reference more closely
- token, tasks, and journal fields have denser spacing and lower visual weight
- status banner and primary button no longer overpower the form
- token help, typing, URL normalization, and validate/save flow still work

If app runtime is unavailable, record the blocker explicitly.

- [ ] **Step 4: Update `progress.md` with task scope, status, and evidence**

Add a new in-progress card at the top of `../progress.md`, then replace each result line with the real command outcome from this run rather than leaving template text behind:

```markdown
### TASK-035
- 目标: 将 onboarding 模式“连接 Notion”配置弹窗的字号、间距、控件尺寸与 `WidgetToDo-Welcome-Modal.html` 的 `#connectModal` 视觉系统对齐，仅改视觉样式，不改交互和数据流
- 状态: 代码修改完成，自动化验证与 UI 手测按实际结果填写
- 改动:
  - `WidgetToDo/WidgetToDo/ContentView.swift` 记录 onboarding header / hero / form / input / status / button 的视觉调整
  - `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift` 记录 onboarding visual-only contract smoke guard
- 验证:
  - 命令: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests` — 填写本次实际结果
  - 命令: `cd WidgetToDo && swift test` — 填写本次实际结果
  - UI 手测: 填写本次实际结果或阻塞原因
- 下一步: 若仍阻塞，写出需补的 UI 验证或环境问题；若验证完成，写明无需后续动作
```

Preserve the existing task history below it.

- [ ] **Step 5: Commit the verification and progress sync**

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo
git add Tests/NotionFloatCoreSmokeTests/main.swift WidgetToDo/ContentView.swift ../progress.md
git commit -m "docs: record onboarding visual alignment verification"
```
