# New Task Modal Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the create-task popup so it adopts the floating widget’s card language without changing any create-task behavior, bindings, shortcuts, or dismissal rules.

**Architecture:** Keep the behavior surface where it already is: `FloatingWidgetView` continues to own overlay presentation and outside-tap dismissal, while `NewTaskFormCard` is restyled in place as a custom warm-gray card. Add a narrow smoke guard that protects the existing interaction contract and the new visual intent without asserting brittle pixel values.

**Tech Stack:** SwiftUI, Swift Concurrency, SwiftPM smoke tests, macOS runtime manual verification

---

## File Map

- Modify: `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift`
  - Add a source-level smoke guard for the create-task card contract: same bindings and actions, new custom card surface instead of `.regularMaterial`.
- Modify: `WidgetToDo/WidgetToDo/NewTaskFormCard.swift`
  - Replace the current generic modal styling with widget-aligned card styling while preserving handlers, focus, validation, and field structure.
- Modify: `progress.md`
  - Replace the design-only in-progress entry with implementation status and verification evidence after code lands.

## Task 1: Add a smoke guard for the create-task card contract

**Files:**
- Modify: `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift`

- [ ] **Step 1: Add a failing runner call for the new-task card contract**

Insert a new runner call near the other source-level UI guards:

```swift
try newTaskFormUsesWidgetCardStyle()
```

- [ ] **Step 2: Add the source-level guard**

Add this function to `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift`:

```swift
static func newTaskFormUsesWidgetCardStyle() throws {
    let rootURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let formURL = rootURL
        .appendingPathComponent("WidgetToDo")
        .appendingPathComponent("NewTaskFormCard.swift")
    let source = try String(contentsOf: formURL, encoding: .utf8)

    try expect(
        source.contains("TextField(\"标题(必填)\", text: $viewModel.title)"),
        "new task form should keep the title binding"
    )
    try expect(
        source.contains("DatePicker(\"\", selection: $viewModel.taskDate, displayedComponents: .date)"),
        "new task form should keep the compact date binding"
    )
    try expect(
        source.contains("viewModel.dismissForm()"),
        "new task form should keep cancel behavior"
    )
    try expect(
        source.contains("viewModel.submit()"),
        "new task form should keep submit behavior"
    )
    try expect(
        source.contains("viewModel.formState == .validationFailed"),
        "new task form should keep validation state rendering"
    )
    try expect(
        source.contains(".modifier(ShakeEffect(animatableData: viewModel.shakeAttempts))"),
        "new task form should keep the shake effect"
    )
    try expect(
        !source.contains(".background(.regularMaterial"),
        "new task form should no longer use the generic regularMaterial card"
    )
    try expect(
        source.contains("RoundedRectangle") && source.contains(".shadow("),
        "new task form should define a custom card surface with border or shadow"
    )
}
```

- [ ] **Step 3: Run the smoke target to verify the new guard fails before implementation**

Run: `cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift run NotionFloatCoreSmokeTests`

Expected: FAIL because `NewTaskFormCard.swift` still contains `.background(.regularMaterial, in: RoundedRectangle(...))`.

- [ ] **Step 4: Keep the guard narrow**

Do not add brittle assertions for exact spacing, exact color values, or exact modifier ordering. Keep the contract limited to:

```swift
source.contains("TextField(\"标题(必填)\", text: $viewModel.title)")
source.contains("DatePicker(\"\", selection: $viewModel.taskDate, displayedComponents: .date)")
source.contains("viewModel.dismissForm()")
source.contains("viewModel.submit()")
source.contains("viewModel.formState == .validationFailed")
source.contains(".modifier(ShakeEffect(animatableData: viewModel.shakeAttempts))")
!source.contains(".background(.regularMaterial")
source.contains("RoundedRectangle") && source.contains(".shadow(")
```

- [ ] **Step 5: Re-run the smoke target after implementation**

Run: `cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift run NotionFloatCoreSmokeTests`

Expected: PASS with `All smoke tests passed.` If the suite is still blocked by the existing `settingsBackRow` guard, record that exact blocker in `progress.md`.

- [ ] **Step 6: Commit**

```bash
git add Tests/NotionFloatCoreSmokeTests/main.swift
git commit -m "test: guard new task card contract"
```

## Task 2: Restyle `NewTaskFormCard` as a widget-aligned card

**Files:**
- Modify: `WidgetToDo/WidgetToDo/NewTaskFormCard.swift`

- [ ] **Step 1: Introduce a local visual constants namespace inside `NewTaskFormCard.swift`**

Add a private constants type above `NewTaskFormCard` so the styling stays local:

```swift
private enum NewTaskFormMetrics {
    static let cardWidth: CGFloat = 286
    static let cardMinHeight: CGFloat = 194
    static let cardCornerRadius: CGFloat = 18
    static let verticalSpacing: CGFloat = 14
    static let fieldCornerRadius: CGFloat = 12
    static let fieldHeight: CGFloat = 42
    static let contentPadding = EdgeInsets(top: 18, leading: 18, bottom: 16, trailing: 18)
}

private enum NewTaskFormPalette {
    static let cardFill = Color(red: 0.965, green: 0.957, blue: 0.941)
    static let cardBorder = Color.black.opacity(0.08)
    static let cardShadow = Color.black.opacity(0.14)
    static let title = Color(red: 0.22, green: 0.21, blue: 0.19)
    static let meta = Color(red: 0.50, green: 0.47, blue: 0.43)
    static let fieldFill = Color.white.opacity(0.78)
    static let fieldBorder = Color.black.opacity(0.10)
    static let validationBorder = Color.red.opacity(0.85)
    static let accent = Color.accentColor
}
```

Keep these values local to avoid coupling this one form to the broader widget palette refactor surface.

- [ ] **Step 2: Replace the emoji-led title with a compact icon row**

Replace:

```swift
Text("➕ 新建任务")
    .font(.system(size: 14, weight: .medium))
```

with:

```swift
HStack(spacing: 8) {
    Image(systemName: "plus")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(NewTaskFormPalette.meta)
        .frame(width: 20, height: 20)
        .background(
            Circle()
                .fill(Color.white.opacity(0.72))
        )

    Text("新建任务")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(NewTaskFormPalette.title)
        .modifier(TrackingModifier(value: -0.16))
}
.frame(maxWidth: .infinity, alignment: .leading)
```

This keeps the title quiet and aligned with the widget hierarchy.

- [ ] **Step 3: Restyle the title field while keeping binding, focus, and validation**

Replace the existing field shell with:

```swift
TextField("标题(必填)", text: $viewModel.title)
    .textFieldStyle(.plain)
    .font(.system(size: 13, weight: .medium))
    .foregroundStyle(NewTaskFormPalette.title)
    .padding(.horizontal, 12)
    .frame(height: NewTaskFormMetrics.fieldHeight)
    .background(
        RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
            .fill(NewTaskFormPalette.fieldFill)
    )
    .overlay(
        RoundedRectangle(cornerRadius: NewTaskFormMetrics.fieldCornerRadius, style: .continuous)
            .stroke(
                viewModel.formState == .validationFailed
                    ? NewTaskFormPalette.validationBorder
                    : NewTaskFormPalette.fieldBorder,
                lineWidth: viewModel.formState == .validationFailed ? 1.5 : 1
            )
    )
    .modifier(ShakeEffect(animatableData: viewModel.shakeAttempts))
    .focused($isTitleFocused)
    .onAppear {
        isTitleFocused = true
    }
```

Do not change the placeholder text, the binding, the validation condition, or the focus behavior.

- [ ] **Step 4: Keep the validation copy but tune its placement**

Leave the same conditional:

```swift
if viewModel.formState == .validationFailed {
    Text("标题不能为空")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
}
```

Only move it if needed to sit directly under the field with a tighter gap. Do not rename the copy.

- [ ] **Step 5: Rebuild the date row as card metadata instead of default modal chrome**

Replace the current date row with:

```swift
HStack(spacing: 8) {
    Image(systemName: "calendar")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(NewTaskFormPalette.meta)
        .frame(width: 18)

    DatePicker("", selection: $viewModel.taskDate, displayedComponents: .date)
        .labelsHidden()
        .datePickerStyle(.compact)
}
.frame(maxWidth: .infinity, alignment: .leading)
```

Keep the same `DatePicker` configuration and binding. This step changes presentation only.

- [ ] **Step 6: Restyle the action row without changing actions**

Use:

```swift
HStack {
    Button("Esc 取消") {
        viewModel.dismissForm()
    }
    .buttonStyle(.plain)
    .font(.system(size: 12, weight: .semibold))
    .foregroundStyle(NewTaskFormPalette.meta)

    Spacer()

    Button("Enter 创建") {
        viewModel.submit()
    }
    .buttonStyle(.plain)
    .font(.system(size: 12, weight: .semibold))
    .foregroundStyle(NewTaskFormPalette.accent)
}
```

Do not convert either action into a filled CTA button.

- [ ] **Step 7: Replace the outer card container**

Replace:

```swift
.padding(16)
.frame(width: 280, height: 190)
.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
.shadow(color: .black.opacity(0.15), radius: 8, y: 4)
```

with:

```swift
.padding(NewTaskFormMetrics.contentPadding)
.frame(width: NewTaskFormMetrics.cardWidth)
.frame(minHeight: NewTaskFormMetrics.cardMinHeight)
.background(
    RoundedRectangle(cornerRadius: NewTaskFormMetrics.cardCornerRadius, style: .continuous)
        .fill(NewTaskFormPalette.cardFill)
)
.overlay(
    RoundedRectangle(cornerRadius: NewTaskFormMetrics.cardCornerRadius, style: .continuous)
        .stroke(NewTaskFormPalette.cardBorder, lineWidth: 1)
)
.shadow(color: NewTaskFormPalette.cardShadow, radius: 18, y: 10)
```

This is the contract change the smoke test protects.

- [ ] **Step 8: Set the overall stack rhythm**

Use:

```swift
VStack(alignment: .leading, spacing: NewTaskFormMetrics.verticalSpacing) {
    ...
}
```

Keep the view small and compact. Do not add new sections, dividers, or helper text beyond what already exists.

- [ ] **Step 9: Run a targeted source inspection before broader verification**

Run: `sed -n '1,220p' /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo/WidgetToDo/NewTaskFormCard.swift`

Expected: the file still contains `viewModel.dismissForm()`, `viewModel.submit()`, `ShakeEffect`, and the same `TextField` / `DatePicker` bindings, but no `.background(.regularMaterial`.

- [ ] **Step 10: Commit**

```bash
git add WidgetToDo/NewTaskFormCard.swift
git commit -m "feat: restyle new task popup as widget card"
```

## Task 3: Verify behavior and record progress

**Files:**
- Modify: `progress.md`

- [ ] **Step 1: Run the full SwiftPM test entrypoint**

Run: `cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift test`

Expected: either PASS, or the same known environment blocker:

```text
Tests/NotionFloatCoreTests/ConfigurationInputNormalizerTests.swift:1:8 error: no such module 'XCTest'
```

Record the exact outcome in `progress.md`.

- [ ] **Step 2: Run the smoke target**

Run: `cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && swift run NotionFloatCoreSmokeTests`

Expected:

- preferred outcome: `All smoke tests passed.`
- acceptable blocked outcome: the suite still fails first on the existing `settingsBackRow` assertion unrelated to this task; if so, record that exact failure in `progress.md`

- [ ] **Step 3: Perform manual runtime verification**

Open the app and validate:

1. enter the todo tab
2. click the `+` button
3. confirm the popup reads as a warm-gray widget card rather than a generic material sheet
4. confirm the title field is focused automatically
5. click outside the card and confirm dismissal still works
6. reopen the popup and press `Esc`; confirm dismissal
7. reopen the popup, leave the title empty, press `Enter`; confirm the card shakes and shows `标题不能为空`
8. enter a title, press `Enter`; confirm task creation still succeeds

If runtime verification is blocked by environment limitations, record the blocker instead of claiming success.

- [ ] **Step 4: Update `progress.md`**

Replace the current design-only entry with an implementation entry that includes:

- changed files
- verification commands
- exact pass/fail/blocker results
- manual runtime result or blocker

Use this structure:

```md
### TASK-040
- 目标: 将“新建任务”弹窗改成与主界面统一的卡片式视觉，不改交互和功能
- 状态: ...
- 改动:
  - ...
- 验证:
  - 命令: `...` — ...
  - UI 手测: ...
- 下一步: ...
```

- [ ] **Step 5: Commit**

```bash
git add progress.md
git commit -m "docs: record new task card verification"
```

## Self-Review

Spec coverage check:

- visual restyle of `NewTaskFormCard`: Task 2
- keep bindings, shortcuts, validation, focus, and dismissal unchanged: Task 1 and Task 2
- verify `swift test` plus runtime behavior: Task 3
- avoid global theme refactor: Task 2 local constants step

Placeholder scan:

- no `TODO`, `TBD`, or “similar to previous task” shortcuts remain
- every code-changing step includes concrete code or exact commands

Type consistency:

- `NewTaskFormCard`
- `viewModel.title`
- `viewModel.taskDate`
- `viewModel.dismissForm()`
- `viewModel.submit()`
- `viewModel.formState == .validationFailed`
- `TrackingModifier`
- `ShakeEffect`

These names all match the current codebase and spec.
