# Onboarding Language Selector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing language selector available during first-run initialization, with the same immediate update and persistence behavior as Settings.

**Architecture:** `OnboardingView` already contains the shared `languageSection`; its only missing connection is the language-selection closure in the onboarding construction path, plus its placement in the onboarding layout. Reuse `RootViewModel.selectLanguage(_:)` unchanged so all existing language-store, repository, failure-recovery, and persistence behavior remains the single source of truth.

**Tech Stack:** Swift 6.2, SwiftUI, XCTest/SwiftPM smoke executable, Xcode Debug build.

---

## File map

- Modify `WidgetToDo/ContentView.swift`: provide the existing root language-selection callback to the onboarding view and render the shared row before the onboarding hero.
- Modify `Tests/NotionFloatCoreSmokeTests/main.swift`: lock the onboarding callback and layout contracts with a source-level smoke check.
- Modify `progress.md`: record the exact red/green, suite, build, and desktop-verification result.

### Task 1: Lock the onboarding language contract with a failing smoke check

**Files:**
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift:48,664-684`
- Test: `Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] **Step 1: Call the new smoke check from the runner.**

  Insert it directly after `settingsContainsPersistentLanguageControl()`:

  ```swift
  try onboardingContainsPersistentLanguageControl()
  try statusBarMenuContainsSettingsEntry()
  ```

- [ ] **Step 2: Add the failing source-level contract.**

  Add this sibling function after `settingsContainsPersistentLanguageControl()`:

  ```swift
  static func onboardingContainsPersistentLanguageControl() throws {
      let rootURL = URL(fileURLWithPath: #filePath)
          .deletingLastPathComponent()
          .deletingLastPathComponent()
          .deletingLastPathComponent()
      let contentViewURL = rootURL
          .appendingPathComponent("WidgetToDo")
          .appendingPathComponent("ContentView.swift")
      let source = try String(contentsOf: contentViewURL, encoding: .utf8)

      guard let onboardingRange = source.range(of: "case .onboarding:"),
            let settingsRange = source.range(of: "case .settings:"),
            let formLayoutRange = source.range(of: "if mode == .settings {")
      else {
          throw SmokeTestFailure(description: "onboarding language control should have a discoverable view structure")
      }

      let onboardingConstruction = String(source[onboardingRange.lowerBound..<settingsRange.lowerBound])
      let formLayout = String(source[formLayoutRange.lowerBound...])
      try expect(
          onboardingConstruction.contains("onLanguageChange: rootViewModel.selectLanguage"),
          "onboarding should persist language selection through RootViewModel"
      )
      try expect(
          formLayout.contains("} else {\\n                            languageSection\\n                            onboardingHero"),
          "onboarding should place the shared language control before the Notion hero"
      )
  }
  ```

- [ ] **Step 3: Run the smoke executable to verify RED.**

  Run:

  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests
  ```

  Expected: exits nonzero with `onboarding should persist language selection through RootViewModel`, because the existing onboarding call does not pass the callback.

### Task 2: Reuse the language selector in first-run onboarding

**Files:**
- Modify: `WidgetToDo/ContentView.swift:32-38,336-343`
- Test: `Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] **Step 1: Wire the existing callback into the onboarding construction.**

  Change the onboarding screen construction to:

  ```swift
  case .onboarding:
      OnboardingView(
          viewModel: rootViewModel.onboardingViewModel,
          mode: .onboarding,
          onBack: {
              rootViewModel.screen = .welcome
          },
          onLanguageChange: rootViewModel.selectLanguage
      )
      .frame(width: AppWindowChrome.defaultWidth, height: AppWindowChrome.defaultHeight)
  ```

- [ ] **Step 2: Render the existing language row before the onboarding hero.**

  Change the mode-specific content block to:

  ```swift
  if mode == .settings {
      settingsIntro
      languageSection
  } else {
      languageSection
      onboardingHero
  }
  ```

  Do not duplicate `languageSection`, add a new state property, or change `selectLanguage(_:)`.

- [ ] **Step 3: Run the smoke executable to verify GREEN.**

  Run:

  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests
  ```

  Expected: exit 0 and `All smoke tests passed.`

- [ ] **Step 4: Commit the implementation and regression check.**

  ```bash
  git add WidgetToDo/ContentView.swift Tests/NotionFloatCoreSmokeTests/main.swift
  git commit -m "feat: add language selector to onboarding"
  ```

### Task 3: Verify the complete change and record its status

**Files:**
- Modify: `progress.md`

- [ ] **Step 1: Run the complete SwiftPM suite.**

  Run:

  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox
  ```

  Expected: exit 0 with all tests passing and zero failures.

- [ ] **Step 2: Build the macOS app target.**

  Run:

  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build
  ```

  Expected: exit 0 and `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Desktop-test the first-run flow.**

  Open a fresh/unconfigured app session, choose each of `简体中文`, `English`, and `Français` from the onboarding `Language` row, then verify the visible setup copy changes immediately. Relaunch and confirm the selected language is present before the welcome/onboarding screen. If the environment cannot safely reset or launch a test app instance, record that blocker rather than claiming a desktop pass.

- [ ] **Step 4: Update `progress.md` with evidence.**

  Add a dated entry that records the changed files, red smoke failure message, green smoke result, full-suite result, build result, desktop-test result or blocker, low UI-only risk, and rollback point (`ContentView.swift` plus the smoke assertion).

- [ ] **Step 5: Commit the verification record.**

  ```bash
  git add progress.md
  git commit -m "docs: record onboarding language verification"
  ```
