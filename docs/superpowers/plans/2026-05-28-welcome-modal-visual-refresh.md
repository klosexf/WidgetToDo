# Welcome Modal Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the SwiftUI welcome screen visuals with a scaled, high-fidelity port of the HTML welcome modal while preserving the existing `onStartConfig` flow and `340 x 560` container.

**Architecture:** Keep the implementation local to `WidgetToDo/WelcomeView.swift`. Port the HTML structure into a reference-driven SwiftUI layout with a small metrics namespace, a local custom button style, and a dedicated illustration viewport. Use source-level smoke checks plus manual app verification because SwiftPM tests do not compile App-layer SwiftUI views.

**Tech Stack:** SwiftUI, AppKit-backed macOS hover behavior, Swift Concurrency, SwiftPM smoke tests, Xcode app target assets

---

## File Map

- Modify: `WidgetToDo/WidgetToDo/WelcomeView.swift`
  - Replace the current spacer-driven layout with a scaled HTML-mapped layout.
  - Add local metrics, CTA styling, and entry animation.
- Create: `WidgetToDo/WidgetToDo/Assets.xcassets/WelcomeIllustration.imageset/Contents.json`
  - Register the welcome illustration in the app asset catalog.
- Create: `WidgetToDo/WidgetToDo/Assets.xcassets/WelcomeIllustration.imageset/welcome-illustration.png`
  - Copy the illustration source into the app target so `WelcomeView` can render it.
- Modify: `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift`
  - Add source-level smoke checks for `WelcomeView` structure and callback wiring.
- Modify: `progress.md`
  - Record implementation progress and verification results after code changes.

## Task 1: Prepare the app-side illustration asset

**Files:**
- Create: `WidgetToDo/WidgetToDo/Assets.xcassets/WelcomeIllustration.imageset/Contents.json`
- Create: `WidgetToDo/WidgetToDo/Assets.xcassets/WelcomeIllustration.imageset/welcome-illustration.png`

- [ ] **Step 1: Confirm the current app asset catalog does not already contain a welcome illustration**

Run: `find WidgetToDo/WidgetToDo/Assets.xcassets -maxdepth 2 -type d | sort`
Expected: `AccentColor.colorset` and `AppIcon.appiconset` only; no existing welcome illustration set.

- [ ] **Step 2: Create the new asset set metadata**

```json
{
  "images" : [
    {
      "filename" : "welcome-illustration.png",
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Write that content to `WidgetToDo/WidgetToDo/Assets.xcassets/WelcomeIllustration.imageset/Contents.json`.

- [ ] **Step 3: Copy the reference illustration into the asset set**

Run: `cp '/Users/chenxiaofeng/Documents/Tare code file/widgets for notion/笔记主体图标.png' 'WidgetToDo/WidgetToDo/Assets.xcassets/WelcomeIllustration.imageset/welcome-illustration.png'`
Expected: command succeeds with no output.

- [ ] **Step 4: Verify the asset files exist and are readable**

Run: `find WidgetToDo/WidgetToDo/Assets.xcassets/WelcomeIllustration.imageset -maxdepth 1 -type f | sort`
Expected:

```text
WidgetToDo/WidgetToDo/Assets.xcassets/WelcomeIllustration.imageset/Contents.json
WidgetToDo/WidgetToDo/Assets.xcassets/WelcomeIllustration.imageset/welcome-illustration.png
```

- [ ] **Step 5: Commit**

```bash
git add WidgetToDo/Assets.xcassets/WelcomeIllustration.imageset
git commit -m "feat: add welcome illustration asset"
```

## Task 2: Add smoke coverage for the welcome-screen structure contract

**Files:**
- Modify: `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] **Step 1: Add a failing smoke test entry to the runner**

Insert the new invocation near the other source-level UI guards in `main()`:

```swift
try welcomeViewUsesDedicatedIllustrationAssetAndCallback()
```

Add the function skeleton:

```swift
static func welcomeViewUsesDedicatedIllustrationAssetAndCallback() throws {
    let rootURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let welcomeViewURL = rootURL
        .appendingPathComponent("WidgetToDo")
        .appendingPathComponent("WelcomeView.swift")
    let source = try String(contentsOf: welcomeViewURL, encoding: .utf8)

    try expect(
        source.contains("Button {") && source.contains("onStartConfig()"),
        "welcome view should keep the existing start-config callback wiring"
    )
    try expect(
        source.contains("Image(\"WelcomeIllustration\")"),
        "welcome view should render the dedicated asset-backed illustration"
    )
    try expect(
        !source.contains(".buttonStyle(.borderedProminent)"),
        "welcome CTA should no longer rely on the default bordered prominent style"
    )
}
```

- [ ] **Step 2: Run the smoke test before implementation to verify it fails**

Run: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests`
Expected: FAIL because `WelcomeView.swift` still uses SF Symbols and `.borderedProminent`.

- [ ] **Step 3: Keep the smoke test in place without broadening it beyond stable structure guarantees**

Do not assert exact padding numbers or color literals in the smoke test. Keep it limited to:

```swift
source.contains("Image(\"WelcomeIllustration\")")
!source.contains(".buttonStyle(.borderedProminent)")
source.contains("onStartConfig()")
```

This keeps the test durable through layout tuning.

- [ ] **Step 4: Re-run the smoke test after the implementation task**

Run: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests`
Expected: PASS with `All smoke tests passed.`

- [ ] **Step 5: Commit**

```bash
git add Tests/NotionFloatCoreSmokeTests/main.swift
git commit -m "test: guard welcome view visual contract"
```

## Task 3: Rebuild `WelcomeView` as a scaled HTML port

**Files:**
- Modify: `WidgetToDo/WidgetToDo/WelcomeView.swift`

- [ ] **Step 1: Replace the free-form spacer layout with a metrics-driven composition**

Use a local metrics namespace instead of raw spacer stacks:

```swift
private enum WelcomeMetrics {
    static let horizontalPadding: CGFloat = 14
    static let topPadding: CGFloat = 12
    static let headerHeight: CGFloat = 30
    static let illustrationHeight: CGFloat = 186
    static let illustrationBottomSpacing: CGFloat = 12
    static let titleBottomSpacing: CGFloat = 8
    static let subtitleBottomSpacing: CGFloat = 2
    static let featuresBottomSpacing: CGFloat = 20
    static let buttonMinWidth: CGFloat = 170
    static let buttonHorizontalPadding: CGFloat = 28
    static let buttonVerticalPadding: CGFloat = 10
    static let buttonCornerRadius: CGFloat = 8
    static let progressTopSpacing: CGFloat = 16
}
```

These values are the scaled starting point. Adjust them optically during manual verification, but keep all values centralized in one namespace.

- [ ] **Step 2: Add a local custom CTA style with hover and press feedback**

Add a dedicated button style in `WelcomeView.swift`:

```swift
private struct WelcomePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, WelcomeMetrics.buttonHorizontalPadding)
            .padding(.vertical, WelcomeMetrics.buttonVerticalPadding)
            .background(Color(red: 45 / 255, green: 45 / 255, blue: 45 / 255))
            .clipShape(RoundedRectangle(cornerRadius: WelcomeMetrics.buttonCornerRadius, style: .continuous))
            .shadow(
                color: Color.black.opacity(isHovered ? 0.25 : 0.20),
                radius: isHovered ? 10 : 8,
                x: 0,
                y: isHovered ? 5 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .offset(y: isHovered && !configuration.isPressed ? -1 : 0)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.18), value: isHovered)
            .opacity(isEnabled ? 1 : 0.7)
    }
}
```

- [ ] **Step 3: Port the welcome layout and typography structure**

Replace the current body with a single content column that mirrors the HTML modal:

```swift
@State private var isAppeared = false
@State private var isButtonHovered = false

var body: some View {
    VStack(spacing: 0) {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.clear)
                .frame(width: 24, height: 24)
        }
        .frame(height: WelcomeMetrics.headerHeight)

        illustrationView
            .padding(.bottom, WelcomeMetrics.illustrationBottomSpacing)

        Text("欢迎使用 WidgetToDo")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
            .tracking(-0.18)
            .padding(.bottom, WelcomeMetrics.titleBottomSpacing)

        subtitleView
            .padding(.bottom, WelcomeMetrics.subtitleBottomSpacing)

        Text("待办 · 日记 · 一目了然")
            .font(.system(size: 10.5, weight: .regular))
            .foregroundStyle(Color(red: 107 / 255, green: 107 / 255, blue: 107 / 255))
            .tracking(0.52)
            .padding(.bottom, WelcomeMetrics.featuresBottomSpacing)

        startButton

        progressDots
            .padding(.top, WelcomeMetrics.progressTopSpacing)

        Spacer(minLength: 0)
    }
    .padding(.horizontal, WelcomeMetrics.horizontalPadding)
    .padding(.top, WelcomeMetrics.topPadding)
    .padding(.bottom, 24)
    .opacity(isAppeared ? 1 : 0)
    .offset(y: isAppeared ? 0 : 10)
    .animation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.42), value: isAppeared)
    .onAppear { isAppeared = true }
}
```

- [ ] **Step 4: Add the illustration, subtitle badge, and progress-dot subviews**

Keep these helpers private in the same file:

```swift
private var illustrationView: some View {
    Image("WelcomeIllustration")
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(maxWidth: .infinity)
        .frame(height: WelcomeMetrics.illustrationHeight)
        .clipped()
        .offset(y: 8)
}

private var subtitleView: some View {
    Text("一个常驻桌面的 ")
        .font(.system(size: 10.5))
        .foregroundStyle(secondaryTextColor)
    + Text("Notion")
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(primaryTextColor)
        .background(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255))
                .frame(height: 16)
        )
    + Text(" 小窗口")
        .font(.system(size: 10.5))
        .foregroundStyle(secondaryTextColor)
}

private var progressDots: some View {
    HStack(spacing: 7) {
        Circle().fill(Color.accentColor).frame(width: 6, height: 6)
        ForEach(1..<5, id: \.self) { _ in
            Circle()
                .fill(Color.secondary.opacity(0.26))
                .frame(width: 6, height: 6)
        }
    }
}
```

When implementing the badge, prefer an `HStack`/`Text` composition that renders reliably in SwiftUI over forcing an attributed-string trick that is harder to maintain.

- [ ] **Step 5: Rebuild the CTA label while preserving the existing callback**

Use the current callback and replace only the visuals:

```swift
private var startButton: some View {
    Button {
        onStartConfig()
    } label: {
        HStack(spacing: 8) {
            Image(systemName: "square.stack")
                .font(.system(size: 11, weight: .semibold))
            Text("开始配置")
                .font(.system(size: 11, weight: .medium))
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .offset(x: isButtonHovered ? 2 : 0)
                .animation(.easeOut(duration: 0.18), value: isButtonHovered)
        }
        .frame(minWidth: WelcomeMetrics.buttonMinWidth)
    }
    .buttonStyle(WelcomePrimaryButtonStyle(isHovered: isButtonHovered))
    .onHover { isHovering in
        isButtonHovered = isHovering
    }
}
```

- [ ] **Step 6: Build the app target to catch SwiftUI compile issues**

Run this in Xcode or from the command line if Xcode is available:

```bash
xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build
```

Expected: build succeeds. If `xcodebuild` is blocked by the active developer directory, stop and record the exact blocker instead of pretending the app build passed.

- [ ] **Step 7: Commit**

```bash
git add WidgetToDo/WelcomeView.swift
git commit -m "feat: restyle welcome modal"
```

## Task 4: Run verification and sync project state

**Files:**
- Modify: `progress.md`

- [ ] **Step 1: Run smoke verification after implementation**

Run: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests`
Expected: `All smoke tests passed.`

- [ ] **Step 2: Run the required repository-wide test command**

Run: `cd WidgetToDo && swift test`
Expected: either PASS, or the known `no such module 'XCTest'` environment failure already seen in `progress.md`. Record whichever actually happens.

- [ ] **Step 3: Perform manual welcome-screen validation**

Manual checklist:

```text
1. Launch the app into the welcome state.
2. Confirm the illustration is visible and cropped lower than center.
3. Confirm the title/subtitle/features hierarchy matches the HTML reference proportionally.
4. Hover the CTA and verify lift + shadow + arrow movement.
5. Click the CTA and verify the app still transitions into onboarding.
```

Expected: all five checks pass, or any blocker is recorded precisely.

- [ ] **Step 4: Update `progress.md` with the implementation outcome**

Add or update a task entry with:

```markdown
### TASK-030
- 目标: 将欢迎页视觉替换为 `WidgetToDo-Welcome-Modal.html` 的缩放复刻版，同时保持现有逻辑不变
- 状态: 已完成 / 阻塞
- 改动:
  - `WidgetToDo/WidgetToDo/WelcomeView.swift` 重建欢迎页布局、插图、CTA 与动画
  - `WidgetToDo/WidgetToDo/Assets.xcassets/WelcomeIllustration.imageset/*` 新增欢迎插图资源
  - `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift` 新增欢迎页结构 smoke guard
- 验证:
  - 命令: `cd WidgetToDo && swift run NotionFloatCoreSmokeTests` — ...
  - 命令: `cd WidgetToDo && swift test` — ...
  - 手测: 欢迎页 hover/click/跳转 — ...
```

- [ ] **Step 5: Commit**

```bash
git add ../progress.md
git commit -m "docs: record welcome modal verification"
```

## Self-Review

- Spec coverage check:
  - fixed `340 x 560` container: Task 3
  - logic preservation and `onStartConfig`: Tasks 2 and 3
  - no fake close action: Task 3 header placeholder step
  - illustration crop behavior: Tasks 1 and 3
  - CTA hover/press polish: Task 3
  - source-level + manual verification: Tasks 2 and 4
- Placeholder scan: no `TODO` / `TBD` markers remain.
- Type consistency: plan uses `WelcomeIllustration`, `WelcomeMetrics`, `WelcomePrimaryButtonStyle`, and `welcomeViewUsesDedicatedIllustrationAssetAndCallback()` consistently.
