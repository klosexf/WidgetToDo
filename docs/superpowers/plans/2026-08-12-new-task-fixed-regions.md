# 新建任务弹框固定头尾与自适应滚动 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新建任务弹框收起时移除底部留白；类型展开或内容过高时，仅滚动中部字段，标题与取消/创建保持固定可见。

**Architecture:** `NewTaskFormCard` 从单一滚动文档改为固定标题、中部内容高度驱动的 `SlimFormScrollView`、固定操作区。`TaskChoicePicker` 把现有展开状态通过闭包通知父视图，使父视图以 0.22 秒动画更新中部高度；共享 AppKit 滚动容器维持完整文档高度，卡片继续用 242...376 pt 约束可视范围。

**Tech Stack:** Swift 6.2、SwiftUI、AppKit、SwiftPM smoke executable、Xcode Debug build。

---

## 文件结构

- 修改：`WidgetToDo/NewTaskFormCard.swift` — 新建表单改为三段布局；类型选择器上浮展开状态。
- 修改：`Tests/NotionFloatCoreSmokeTests/main.swift` — 锁定三段结构、动态上限、动画和状态回调。
- 修改：`progress.md` — 记录影响路径、红绿测试、构建和手测。

### Task 1: 写入新建任务固定区域的失败契约

**Files:**

- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift:852-997,999-1124`

- [ ] **Step 1: 扩展新建表单契约**

在 `newTaskFormKeepsCreateTaskContract()` 取得 `formSource` 后加入：

```swift
try expect(
    formSource.contains("private var newTaskHeader: some View") &&
        formSource.contains("private var newTaskFooter: some View") &&
        formSource.contains("private var newTaskScrollableContent: some View"),
    "new task form should split fixed header and footer from its scrollable content"
)
try expect(
    formSource.contains("contentHeightLimit: scrollableContentHeightLimit") &&
        formSource.contains("NewTaskFormMetrics.cardMaxHeight - headerHeight - footerHeight"),
    "new task form should reserve fixed regions from its scrollable height limit"
)
try expect(
    formSource.contains(".animation(.easeInOut(duration: 0.22), value: isTypeOptionsPresented)"),
    "new task form should animate type-list height changes"
)
```

- [ ] **Step 2: 扩展选择器状态回调契约**

在 `newTaskTypePickerUsesSearchableDropdownContract()` 中加入：

```swift
try expect(
    source.contains("let onOptionsPresentedChange: (Bool) -> Void") &&
        source.contains("onOptionsPresentedChange(isOptionsPresented)"),
    "new task type picker should report expanded state to its parent"
)
try expect(
    source.contains("TaskChoicePicker(") &&
        source.contains("onOptionsPresentedChange: { isTypeOptionsPresented = $0 }"),
    "new task form should use picker state to drive its height"
)
```

- [ ] **Step 3: 运行 red smoke**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift run NotionFloatCoreSmokeTests`

Expected: FAIL，包含 `new task form should split fixed header and footer from its scrollable content`。

- [ ] **Step 4: 提交红灯测试**

Run: `git add Tests/NotionFloatCoreSmokeTests/main.swift && git commit -m "test: cover fixed new task form regions"`

### Task 2: 上浮类型选择器的展开状态

**Files:**

- Modify: `WidgetToDo/NewTaskFormCard.swift:294-489`

- [ ] **Step 1: 为选择器增加状态回调**

将 `TaskChoicePicker` 的属性开头改为：

```swift
private struct TaskChoicePicker: View {
    let field: TaskChoiceField
    @Binding var selection: String?
    let onOptionsPresentedChange: (Bool) -> Void
    @State private var searchText = ""
    @State private var isOptionsPresented = false
```

- [ ] **Step 2: 统一状态写入并通知父视图**

新增：

```swift
private func setOptionsPresented(_ isPresented: Bool) {
    isOptionsPresented = isPresented
    onOptionsPresentedChange(isPresented)
}
```

将 `presentOptions()` 内的 `isOptionsPresented = true` 换为 `setOptionsPresented(true)`；将 `dismissOptions()`、`clearSelection()` 和 `select(_:)` 中的 `isOptionsPresented = false` 全部换为 `setOptionsPresented(false)`。

在选择器的 `.onAppear` 中追加：

```swift
onOptionsPresentedChange(isOptionsPresented)
```

保持搜索、焦点、选择 Binding、可筛选列表和所有按钮行为不变。

- [ ] **Step 3: 运行 smoke，确认回调契约满足、表单结构仍失败**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift run NotionFloatCoreSmokeTests`

Expected: 选择器回调相关断言通过，仍 FAIL 于 `new task form should split fixed header and footer from its scrollable content`。

### Task 3: 重组新建任务弹框

**Files:**

- Modify: `WidgetToDo/NewTaskFormCard.swift:131-289`

- [ ] **Step 1: 定义固定区域与展开状态**

在 `NewTaskFormCard` 状态属性后加入：

```swift
@State private var isTypeOptionsPresented = false
private let headerHeight: CGFloat = 35
private let footerHeight: CGFloat = 58
private var scrollableContentHeightLimit: CGFloat {
    NewTaskFormMetrics.cardMaxHeight - headerHeight - footerHeight
}
```

- [ ] **Step 2: 将 body 改为三段结构**

替换外层 `SlimFormScrollView` 为：

```swift
VStack(spacing: 0) {
    newTaskHeader
    SlimFormScrollView(
        usesContentHeight: true,
        contentHeightLimit: scrollableContentHeightLimit
    ) {
        newTaskScrollableContent
    }
    newTaskFooter
}
.frame(width: NewTaskFormMetrics.cardWidth)
.frame(minHeight: NewTaskFormMetrics.cardMinHeight, maxHeight: NewTaskFormMetrics.cardMaxHeight)
.animation(.easeInOut(duration: 0.22), value: isTypeOptionsPresented)
```

保留既有卡片背景、描边、阴影和 `.onSubmit { viewModel.submit() }`。

- [ ] **Step 3: 提取固定标题与操作区**

新增 `newTaskHeader`：居中 `languageStore.text(.newTask)`，高度 `headerHeight`，沿用当前字体与颜色。

新增 `newTaskFooter`：保留当前取消按钮的 `viewModel.dismissForm()` 和创建按钮的 `viewModel.submit()`、原有按钮样式；使用：

```swift
.padding(.horizontal, NewTaskFormMetrics.contentPadding.leading)
.padding(.top, 4)
.padding(.bottom, NewTaskFormMetrics.contentPadding.bottom)
.frame(height: footerHeight)
```

- [ ] **Step 4: 提取中部字段内容并连接选择器回调**

把旧 `body` 内标题之后、按钮之前的任务、日期、时长与可选类型字段原样移入 `newTaskScrollableContent`。保留所有校验、焦点与 Binding；它的结尾使用：

```swift
.padding(.horizontal, NewTaskFormMetrics.contentPadding.leading)
.padding(.bottom, NewTaskFormMetrics.contentPadding.bottom)
```

类型调用改为：

```swift
TaskChoicePicker(
    field: choiceField,
    selection: $viewModel.priority,
    onOptionsPresentedChange: { isTypeOptionsPresented = $0 }
)
```

标题和取消/创建按钮不得置入 `SlimFormScrollView` 闭包。

- [ ] **Step 5: 运行 green smoke**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift run NotionFloatCoreSmokeTests`

Expected: `All smoke tests passed.`

- [ ] **Step 6: 提交实现**

Run: `git add WidgetToDo/NewTaskFormCard.swift && git commit -m "fix: pin new task form actions"`

### Task 4: 完整验证、手测和进度同步

**Files:**

- Modify: `progress.md`

- [ ] **Step 1: 运行完整单测**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift test`

Expected: 70 tests / 0 failures；可保留既有 `PomodoroSessionEngineTests` 未使用返回值警告记录。

- [ ] **Step 2: 构建 Debug App**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/widgettodo-new-task-fixed-regions-build CODE_SIGNING_ALLOWED=NO build`

Expected: `BUILD SUCCEEDED`。

- [ ] **Step 3: 无写入手测**

1. 点击新建任务，确认标题、全部字段和取消/创建完整可见，按钮下没有留白。
2. 展开类型，确认卡片以动画平滑增高。
3. 多选项或大字体导致超高时，确认卡片不超过 376 pt；标题和取消/创建固定，5 pt 滑块只在中部，且可访问所有字段和选项。
4. 收起列表，确认高度收紧且滚动条消失；点击取消，确认未创建 Notion 任务。

若隔离运行环境没有 Tasks 数据库，记录为手测阻塞；不得读取、复制或输入 Notion token。

- [ ] **Step 4: 记录证据并提交**

在 `progress.md` 顶部记录根因、影响路径、红绿 smoke、单测、构建和手测结果。然后运行：

    git status --short
    git diff --check
    git add Tests/NotionFloatCoreSmokeTests/main.swift progress.md
    git commit -m "docs: record new task fixed regions"

Expected: 除用户已有的未跟踪设计/计划文档外，无无关改动。
