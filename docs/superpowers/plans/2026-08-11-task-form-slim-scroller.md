# Task Form Slim Scroller Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give both task forms one shared, draggable 5 pt vertical scrollbar without changing task-form data or actions.

**Architecture:** A new AppKit-backed `SlimFormScrollView` will host the existing SwiftUI form content inside `NSScrollView`. Its private `NSScroller` subclass declares a 5 pt width and draws only the rounded thumb. `NewTaskFormCard` and `EditTaskFormCard` will replace only their outer form `ScrollView`; their fields, bindings, buttons, and expanded type pickers stay intact.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, XCTest smoke executable, Xcode Debug build.

---

## File structure

- Create: `WidgetToDo/WidgetToDo/SlimFormScrollView.swift` — shared AppKit bridge and 5 pt scroller drawing.
- Modify: `WidgetToDo/WidgetToDo/NewTaskFormCard.swift` — switch the new-task form’s outer scroller to the shared component.
- Modify: `WidgetToDo/WidgetToDo/ContentView.swift` — switch `EditTaskFormCard`’s outer scroller to the shared component, preserving the type-picker sizing rule.
- Modify: `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift` — static regression contract covering component definition and both form call sites.
- Modify: `WidgetToDo/progress.md` — record the implementation status and fresh verification evidence after code changes.

### Task 1: Add the regression contract

**Files:**
- Modify: `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift:38-47, after newTaskFormKeepsCreateTaskContract()`

- [ ] **Step 1: Add a failing smoke-test invocation and contract**

Insert the invocation before the existing type-picker contracts so the new check runs before unrelated known smoke failures:

```swift
try taskFormsUseSharedSlimScrollerContract()
```

Add the contract function. It must independently load the three UI files, then assert the exact component API and both replacements:

```swift
static func taskFormsUseSharedSlimScrollerContract() throws {
    let rootURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let appURL = rootURL.appendingPathComponent("WidgetToDo")
    let scrollerSource = try String(
        contentsOf: appURL.appendingPathComponent("SlimFormScrollView.swift"),
        encoding: .utf8
    )
    let newTaskSource = try String(
        contentsOf: appURL.appendingPathComponent("NewTaskFormCard.swift"),
        encoding: .utf8
    )
    let contentSource = try String(
        contentsOf: appURL.appendingPathComponent("ContentView.swift"),
        encoding: .utf8
    )

    try expect(scrollerSource.contains("struct SlimFormScrollView"), "task forms should share a dedicated slim scroll view")
    try expect(scrollerSource.contains("static let thumbWidth: CGFloat = 5"), "task form scrollbar thumb should be 5 pt wide")
    try expect(scrollerSource.contains("final class SlimVerticalScroller: NSScroller"), "shared form scroller should keep native drag behavior")
    try expect(newTaskSource.contains("SlimFormScrollView {"), "new task form should use the shared slim scroll view")

    guard let editStart = contentSource.range(of: "struct EditTaskFormCard: View"),
          let previewStart = contentSource[editStart.upperBound...].range(of: "#Preview", options: [], range: editStart.upperBound..<contentSource.endIndex)?.lowerBound else {
        throw SmokeTestFailure(description: "edit task form scope should remain available")
    }
    let editSource = String(contentSource[editStart.lowerBound..<previewStart])
    try expect(editSource.contains("SlimFormScrollView {"), "edit task form should use the shared slim scroll view")
}
```

- [ ] **Step 2: Run the smoke executable and confirm red**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift run NotionFloatCoreSmokeTests
```

Expected: failure stating that `SlimFormScrollView.swift` is unavailable, because the component has not been created. A build or sandbox-environment failure must be recorded as a blocker and not treated as red-test evidence.

### Task 2: Implement the reusable 5 pt AppKit scroller

**Files:**
- Create: `WidgetToDo/WidgetToDo/SlimFormScrollView.swift`

- [ ] **Step 1: Add the AppKit bridge and custom thumb**

Create the shared component with a generic SwiftUI content closure, a no-track 5 pt `NSScroller`, overlay presentation, auto-hidden scrollbars, and a hosting view pinned to the clip view width:

```swift
import AppKit
import SwiftUI

private enum SlimFormScrollerMetrics {
    static let thumbWidth: CGFloat = 5
    static let thumbCornerRadius: CGFloat = 2.5
    static let thumbColor = NSColor(calibratedWhite: 0.38, alpha: 0.78)
}

struct SlimFormScrollView<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> HostingScrollView<Content> {
        HostingScrollView(rootView: content)
    }

    func updateNSView(_ scrollView: HostingScrollView<Content>, context: Context) {
        scrollView.update(rootView: content)
    }
}

final class SlimVerticalScroller: NSScroller {
    override class func scrollerWidth(
        for controlSize: NSControl.ControlSize,
        scrollerStyle: NSScroller.Style
    ) -> CGFloat {
        SlimFormScrollerMetrics.thumbWidth
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}

    override func drawKnob() {
        SlimFormScrollerMetrics.thumbColor.setFill()
        NSBezierPath(
            roundedRect: rect(for: .knob),
            xRadius: SlimFormScrollerMetrics.thumbCornerRadius,
            yRadius: SlimFormScrollerMetrics.thumbCornerRadius
        ).fill()
    }
}

final class HostingScrollView<Content: View>: NSScrollView {
    private let hostingView: NSHostingView<Content>

    init(rootView: Content) {
        hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        drawsBackground = false
        borderType = .noBorder
        hasHorizontalScroller = false
        hasVerticalScroller = true
        autohidesScrollers = true
        scrollerStyle = .overlay
        verticalScroller = SlimVerticalScroller()

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        documentView = hostingView
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingView.widthAnchor.constraint(equalTo: contentView.widthAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(rootView: Content) {
        hostingView.rootView = rootView
        hostingView.invalidateIntrinsicContentSize()
        needsLayout = true
        layoutSubtreeIfNeeded()
    }
}
```

If AppKit requires the hosting view’s height to be invalidated explicitly when the option list expands, add that recalculation inside `HostingScrollView.update(rootView:)`; do not put form-specific state in the shared component.

- [ ] **Step 2: Run the smoke executable and confirm the component portion turns green**

Run the Task 1 command. Expected: it advances past the missing-component assertion, then fails because neither task form has yet adopted `SlimFormScrollView`.

### Task 3: Adopt the shared component in both task forms

**Files:**
- Modify: `WidgetToDo/WidgetToDo/NewTaskFormCard.swift:138-263`
- Modify: `WidgetToDo/WidgetToDo/ContentView.swift:2088-2254`

- [ ] **Step 1: Replace only each outer vertical `ScrollView`**

In both forms, replace this outer wrapper:

```swift
ScrollView(.vertical, showsIndicators: true) {
    VStack(alignment: .leading, spacing: NewTaskFormMetrics.verticalSpacing) {
        // existing form body unchanged
    }
    .padding(NewTaskFormMetrics.contentPadding)
}
```

with:

```swift
SlimFormScrollView {
    VStack(alignment: .leading, spacing: NewTaskFormMetrics.verticalSpacing) {
        // preserve the existing form body, bindings, and actions exactly
    }
    .padding(NewTaskFormMetrics.contentPadding)
}
```

Keep the new-task card’s existing width/min/max-height modifiers unchanged. In `EditTaskFormCard`, retain `.fixedSize(horizontal: false, vertical: !isTypeOptionsPresented)` exactly after the shared-wrapper replacement so the edit card continues to collapse when the type list is closed and expand/scroll when it is open. Do not change the inner type-option list, which intentionally has no indicator.

- [ ] **Step 2: Run the smoke executable and confirm green for this contract**

Run the Task 1 command. Expected: the new slim-scroller contract passes. If the full smoke suite stops at an existing unrelated assertion, capture its first failure and verify that it has advanced beyond `taskFormsUseSharedSlimScrollerContract()`.

- [ ] **Step 3: Run source hygiene check**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo
rg -n 'SlimFormScrollView \{|ScrollView\(.vertical, showsIndicators: true\)' WidgetToDo/NewTaskFormCard.swift WidgetToDo/ContentView.swift WidgetToDo/SlimFormScrollView.swift
```

Expected: one `SlimFormScrollView {` in `NewTaskFormCard.swift`, one inside `EditTaskFormCard` in `ContentView.swift`, and no legacy outer form scroller. Existing unrelated `ScrollView` instances are allowed.

### Task 4: Validate, document, and commit

**Files:**
- Modify: `WidgetToDo/progress.md`

- [ ] **Step 1: Run the full automated checks**

Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/widgettodo-slim-scroller-build CODE_SIGNING_ALLOWED=NO build
```

Expected: `swift test` reports zero failures and Xcode reports `** BUILD SUCCEEDED **`. If either is blocked by the recorded environment issue, retain the exact output and do not call the change fully verified.

- [ ] **Step 2: Perform desktop visual verification**

In Xcode or the app runtime:

1. Open the Todo tab and choose `+`; make the form overflow, then check that the right-side thumb is 5 pt and draggable.
2. Open an existing task’s edit form; expand and collapse the type picker, then confirm the same thumb width, updated thumb ratio, and no clipping.
3. In both forms, use the mouse wheel/trackpad, Tab through inputs, type in title and duration, then cancel; create/save a test task only if a test Notion setup is available.

Record either the observed results or the specific UI-runtime blocker in `progress.md`.

- [ ] **Step 3: Update progress and commit only task-scroller files**

Add a new task entry that lists the affected files, the smoke red/green evidence, `swift test`, Debug build, and visual-verification result. Stage only the files created or modified by this plan; do not stage the pre-existing untracked `docs/superpowers/plans/2026-08-11-new-task-type-picker.md`.

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo
git add WidgetToDo/SlimFormScrollView.swift WidgetToDo/NewTaskFormCard.swift WidgetToDo/ContentView.swift Tests/NotionFloatCoreSmokeTests/main.swift progress.md
git commit -m "feat: slim task form scrollers"
git status --short
```

Expected: the task-scroller commit is created; the pre-existing untracked type-picker plan, if still present, remains unstaged and untouched.

## Plan self-review

- Spec coverage: Tasks 2 and 3 supply one shared 5 pt component to both forms; Task 3 preserves task data and existing form interactions; Task 4 covers overflow, drag, keyboard focus, and dynamic type-picker size.
- No-placeholder scan: no deferred implementation or unspecified test step remains.
- Type consistency: the test contract, implementation, and callers consistently use `SlimFormScrollView`, `SlimVerticalScroller`, and `SlimFormScrollerMetrics.thumbWidth`.
