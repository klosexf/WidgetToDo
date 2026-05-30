# Settings Visual Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the settings screen's shared form typography, spacing, and control sizing with the onboarding "连接 Notion" modal without changing any behavior.

**Architecture:** Keep the work local to `WidgetToDo/ContentView.swift`, where onboarding and settings already share one modal component. Reuse the onboarding presentation values for shared settings form regions, avoid touching handlers or bindings, and record the result in `progress.md`.

**Tech Stack:** SwiftUI, Swift Concurrency, SwiftPM smoke tests, XCTest-backed `swift test`

---

## File Map

- Modify: `WidgetToDo/ContentView.swift`
  - Collapse settings-mode presentation drift for shared form regions so the view uses the same visual rhythm as onboarding.
- Modify: `../progress.md`
  - Record the task, changed files, and verification evidence.

## Task 1: Align shared settings form presentation

**Files:**
- Modify: `WidgetToDo/ContentView.swift`

- [ ] **Step 1: Locate settings-only style branches inside the shared modal**

Inspect `OnboardingModalView` in `WidgetToDo/ContentView.swift` and identify all branches where `mode == .settings` changes presentation-only values in:

- the scroll container spacing and padding
- `modalHeader`
- `tokenSection`
- `databaseSection`
- `inputShell`
- `statusBanner`
- `primaryButton`

Do not change any branch that affects:

- `Button` actions
- `Binding` values
- `onChange`
- `Task { ... }`
- `sheet`
- `confirmationDialog`

- [ ] **Step 2: Replace shared-form settings spacing with onboarding spacing**

Apply onboarding values to the shared container so settings uses the same layout rhythm:

```swift
VStack(alignment: .leading, spacing: mode == .onboarding ? OnboardingModalMetrics.onboardingContentSpacing : OnboardingModalMetrics.onboardingContentSpacing) {
    ...
}
.padding(.horizontal, mode == .onboarding ? OnboardingModalMetrics.onboardingHorizontalPadding : OnboardingModalMetrics.onboardingHorizontalPadding)
.padding(.top, mode == .onboarding ? OnboardingModalMetrics.onboardingTopPadding : OnboardingModalMetrics.onboardingTopPadding)
.padding(.bottom, mode == .onboarding ? OnboardingModalMetrics.onboardingBottomPadding : OnboardingModalMetrics.onboardingBottomPadding)
```

After the edit, simplify duplicated ternaries when both branches are identical.

- [ ] **Step 3: Align header typography and padding**

Retune `modalHeader` so settings uses the same padding rhythm and title size system as onboarding:

```swift
if mode == .settings {
    Text("设置")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(OnboardingModalPalette.primaryText)
}

...
.padding(.horizontal, 16)
.padding(.vertical, 14)
```

Keep the existing back button, placeholder balance view, and mode-specific title copy logic unchanged.

- [ ] **Step 4: Align section labels, helper copy, and input shell sizing**

Use the onboarding presentation values for shared form rows:

```swift
Text("Notion Token")
    .font(.system(size: 12, weight: .semibold))

Image(systemName: "chevron.right")
    .font(.system(size: 9, weight: .semibold))

HStack(alignment: .center, spacing: 6) {
    Image(systemName: "lock")
        .font(.system(size: 10, weight: .medium))
    Text(...)
        .font(.system(size: 12))
}
```

And in `inputShell`:

```swift
HStack(spacing: OnboardingModalMetrics.onboardingInputIconSpacing) {
    Image(systemName: icon)
        .font(.system(size: OnboardingModalMetrics.onboardingInputIconSize, weight: .medium))
        .frame(width: OnboardingModalMetrics.onboardingInputIconWidth)

    field()
        .font(.system(size: 13))
}
.padding(.horizontal, OnboardingModalMetrics.onboardingInputHorizontalPadding)
.padding(.vertical, OnboardingModalMetrics.onboardingInputVerticalPadding)
```

Keep the `SecureField`, `TextField`, `disabled`, and `onChange` behavior intact.

- [ ] **Step 5: Align status banner and primary button presentation**

Apply onboarding typography and padding to the shared status banner and primary action:

```swift
HStack(alignment: .top, spacing: 8) {
    Image(systemName: ...)
        .font(.system(size: 14, weight: .semibold))
    Text(message)
        .font(.system(size: 12))
}
.padding(.horizontal, OnboardingModalMetrics.onboardingStatusHorizontalPadding)
.padding(.vertical, OnboardingModalMetrics.onboardingStatusVerticalPadding)
```

If `primaryButton` still branches on settings-specific sizing, switch those frame/padding/font values to the onboarding equivalents while leaving the button label text, disabled state, and async action unchanged.

- [ ] **Step 6: Verify the diff is visual-only**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo
git diff -- WidgetToDo/ContentView.swift
```

Expected:

- diff only shows `font`, `padding`, `spacing`, `frame`, or equivalent presentation changes
- no handler body, binding path, or async control-flow changes

## Task 2: Run verification and sync progress

**Files:**
- Modify: `../progress.md`

- [ ] **Step 1: Run full automated verification**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift test
```

Expected:

- either the suite passes
- or the existing known `XCTest` environment failure remains the blocker, with no new failure attributed to this visual change

- [ ] **Step 2: Record UI verification status honestly**

If desktop runtime verification is available, open the settings screen and compare it with onboarding for:

- header padding
- section title size
- input field height
- section spacing
- primary button size

If runtime verification is not available in this session, record the blocker explicitly instead of claiming visual QA completion.

- [ ] **Step 3: Update `progress.md`**

Add a new in-progress task entry that includes:

- the goal and non-goal summary
- changed files
- verification commands and results
- whether UI hand-check was completed or blocked

- [ ] **Step 4: Commit**

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo
git add WidgetToDo/ContentView.swift ../progress.md
git commit -m "style: align settings modal with onboarding form"
```
