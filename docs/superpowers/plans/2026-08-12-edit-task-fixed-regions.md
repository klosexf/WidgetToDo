# 编辑任务弹框固定头尾与自适应滚动 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 编辑任务弹框收起时只保留必要高度；展开或超高时只滚动中部字段，并固定显示标题和取消/保存。

**Architecture:** `EditTaskFormCard` 从单一 AppKit 滚动文档改为固定标题、内容自适应的 `SlimFormScrollView`、固定操作区三段结构。共享 `HostingScrollView` 保持完整文档高度，只限制中部区域的可视高度；外层卡片继续使用既有 242...376 pt 边界，`isTypeOptionsPresented` 驱动 0.22 秒收展动画。

**Tech Stack:** Swift 6.2、SwiftUI、AppKit、SwiftPM smoke executable、Xcode Debug build。

---

## 文件结构

- 修改：`WidgetToDo/SlimFormScrollView.swift` — 维持完整滚动文档，同时限制中部的可视高度。
- 修改：`WidgetToDo/ContentView.swift` — 将 `EditTaskFormCard` 拆为固定标题、中部可滚动字段、固定按钮；添加高度动画。
- 修改：`Tests/NotionFloatCoreSmokeTests/main.swift` — 加入固定区域、动态上限、完整文档和动画的回归契约。
- 修改：`progress.md` — 记录根因、影响路径、验证及手测结果。

### Task 1: 写入失败回归契约

**Files:**

- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift:999-1075,1126-1165`

- [ ] **Step 1: 验证共享容器区分可视高度和文档高度**

在 `taskFormsUseSharedSlimScrollerContract()` 中加入：

```swift
try expect(
    scrollerSource.contains("let contentHeightLimit: CGFloat?")
        && scrollerSource.contains("min(measuredContentHeight, contentHeightLimit ?? measuredContentHeight)"),
    "content-height scroller should cap its intrinsic height"
)
try expect(
    scrollerSource.contains("hostingView.frame.size.height = contentHeight")
        && !scrollerSource.contains("hostingView.frame.size.height = min(contentHeight"),
    "content-height scroller should preserve the full document height for scrolling"
)
```

- [ ] **Step 2: 验证编辑表单三段结构和动画**

在 `editTaskTypePickerUsesSearchableDropdownContract()` 的 `editFormSource` 断言中加入：

```swift
try expect(
    editFormSource.contains("private var editTaskHeader: some View")
        && editFormSource.contains("private var editTaskFooter: some View")
        && editFormSource.contains("private var editTaskScrollableContent: some View"),
    "edit form should split fixed header and footer from its scrollable content"
)
try expect(
    editFormSource.contains("contentHeightLimit: scrollableContentHeightLimit"),
    "edit form should bound only its scrollable content"
)
try expect(
    editFormSource.contains(".animation(.easeInOut(duration: 0.22), value: isTypeOptionsPresented)"),
    "edit form should animate type-list height changes"
)
```

- [ ] **Step 3: 运行红灯测试**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift run NotionFloatCoreSmokeTests`

Expected: FAIL，包含 `edit form should split fixed header and footer from its scrollable content`。

- [ ] **Step 4: 提交红灯测试**

Run: `git add Tests/NotionFloatCoreSmokeTests/main.swift && git commit -m "test: cover fixed edit task form regions"`

### Task 2: 保留完整滚动文档

**Files:**

- Modify: `WidgetToDo/SlimFormScrollView.swift:8-108`（仅契约不满足时）

- [ ] **Step 1: 确认内容高度配置由容器转交给 HostingScrollView**

保留：

```swift
init(
    usesContentHeight: Bool = false,
    contentHeightLimit: CGFloat? = nil,
    @ViewBuilder content: () -> Content
)
```

`makeNSView` 必须把 `usesContentHeight` 和 `contentHeightLimit` 都传给 `HostingScrollView`。新建任务继续不传配置。

- [ ] **Step 2: 固有高度受限，文档高度不受限**

保留：

```swift
height: min(measuredContentHeight, contentHeightLimit ?? measuredContentHeight)
```

并继续将完整高度给文档：

```swift
hostingView.frame.size.height = contentHeight
```

禁止将 `contentHeightLimit` 用在 `hostingView.frame.size.height`，否则底部字段和选项不可滚动访问。

- [ ] **Step 3: 验证共享容器契约**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift run NotionFloatCoreSmokeTests`

Expected: 上限与完整文档断言通过；编辑固定区域断言仍 FAIL。

### Task 3: 重组编辑弹框

**Files:**

- Modify: `WidgetToDo/ContentView.swift:2062-2380`

- [ ] **Step 1: 定义中部区域上限**

在 `EditTaskFormCard` 中添加：

```swift
private let headerHeight: CGFloat = 35
private let footerHeight: CGFloat = 70
private var scrollableContentHeightLimit: CGFloat {
    NewTaskFormMetrics.cardMaxHeight - headerHeight - footerHeight
}
```

- [ ] **Step 2: 替换为固定头、中部滚动、固定尾结构**

将 `body` 外层替换为：

```swift
VStack(spacing: 0) {
    editTaskHeader
    SlimFormScrollView(
        usesContentHeight: true,
        contentHeightLimit: scrollableContentHeightLimit
    ) {
        editTaskScrollableContent
    }
    editTaskFooter
}
.frame(width: NewTaskFormMetrics.cardWidth)
.frame(minHeight: NewTaskFormMetrics.cardMinHeight, maxHeight: NewTaskFormMetrics.cardMaxHeight)
.animation(.easeInOut(duration: 0.22), value: isTypeOptionsPresented)
```

保留原有背景、描边、阴影、`onAppear` 和 `editingPriority` 的 `onChange`。

- [ ] **Step 3: 提取固定标题与底部按钮区**

添加 `editTaskHeader`：标题高度为 `headerHeight`，居中显示 `languageStore.text(.editTask)`。

添加 `editTaskFooter`：保留当前取消按钮的 `viewModel.cancelEditing()` 与保存按钮的 `await viewModel.saveTaskEdit()`，使用现有样式和 `.disabled(viewModel.isSavingTaskEdit)`；用 `NewTaskFormMetrics.contentPadding` 的水平与底部间距，固定高度 `footerHeight`。

- [ ] **Step 4: 提取中部字段内容**

把旧 `body` 内标题之后、按钮之前的任务、时长和能力维度 `VStack` 原样移动至 `editTaskScrollableContent`，保留所有 Binding、焦点、错误文案、`typeOptionsMenu`、搜索与选项操作。该视图使用：

```swift
.padding(.horizontal, NewTaskFormMetrics.contentPadding.leading)
.padding(.bottom, NewTaskFormMetrics.contentPadding.bottom)
```

标题、取消和保存不得留在 `SlimFormScrollView` 闭包中；`typeOptionsListHeight` 与内部 `ScrollView` 不变。

- [ ] **Step 5: 验证绿灯并提交**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift run NotionFloatCoreSmokeTests`

Expected: `All smoke tests passed.`

Run: `git add WidgetToDo/ContentView.swift && git commit -m "fix: pin edit task form actions"`

### Task 4: 完整验证、手测与进度同步

**Files:**

- Modify: `progress.md`

- [ ] **Step 1: 运行全量测试**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift test`

Expected: 70 tests / 0 failures；可记录已有 `PomodoroSessionEngineTests` 未使用返回值警告。

- [ ] **Step 2: 构建 Debug App**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/widgettodo-edit-task-fixed-regions-build CODE_SIGNING_ALLOWED=NO build`

Expected: `BUILD SUCCEEDED`。

- [ ] **Step 3: 无写入手测**

1. 打开既有任务的编辑弹框，确认标题、字段、按钮完整且按钮下无空白。
2. 展开类型，确认弹框平滑增高。
3. 在多选项或较大系统字体下，确认卡片不超过 376 pt、标题和取消/保存固定、5 pt 滑块只在中部出现，且所有字段/选项可达。
4. 收起列表，确认高度收紧且滚动条消失；点击取消，确认不写入 Notion。

若隔离构建没有 Tasks 数据库，记录为手测阻塞；不得读取、复制或输入 Notion token。

- [ ] **Step 4: 同步进度并提交**

在 `progress.md` 顶部记录根因、影响路径、每条验证命令、结果及手测/阻塞，然后运行：

    git status --short
    git diff --check
    git add Tests/NotionFloatCoreSmokeTests/main.swift progress.md
    git commit -m "docs: record edit task fixed regions"

Expected: 除用户已有的 `docs/superpowers/plans/2026-08-11-new-task-type-picker.md` 未跟踪文件外，无无关改动。
