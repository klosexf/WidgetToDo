# 编辑任务弹框自适应高度 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让编辑任务弹框在内容较少时收紧到保存按钮下方，在内容超过安全上限时继续通过现有 5 pt 极细滚动条访问全部内容。

**Architecture:** 在共享的 `SlimFormScrollView` 上增加一个默认关闭的内容高度协商开关。开关开启时，承载 SwiftUI 表单的 `HostingScrollView` 把已按可视宽度测得的 `NSHostingView.fittingSize.height` 作为自身固有高度，并只在高度实际变化时失效该尺寸；`EditTaskFormCard` 是唯一启用该开关的调用点，外层现有 `242...376 pt` 约束负责最小高度、最大高度和溢出滚动。

**Tech Stack:** Swift 6.2、SwiftUI、AppKit、SwiftPM smoke executable、Xcode Debug build。

---

## 文件结构

- 修改：`WidgetToDo/SlimFormScrollView.swift` — 为共享 AppKit 滚动容器提供可选的内容固有高度协商，不改变默认滚动行为。
- 修改：`WidgetToDo/ContentView.swift` — 仅让 `EditTaskFormCard` 启用内容高度协商。
- 修改：`Tests/NotionFloatCoreSmokeTests/main.swift` — 以源码合约防止编辑表单遗漏自适应模式，并约束共享容器的高度失效机制。
- 修改：`progress.md` — 记录根因、影响路径、红绿测试、构建和手测结果。

### Task 1: 写入编辑表单自适应高度回归契约

**Files:**
- Modify: `Tests/NotionFloatCoreSmokeTests/main.swift:1120-1140`（编辑表单滚动容器现有契约之后）

- [ ] **Step 1: 在现有编辑表单契约中加入失败断言**

在读取出的 `editFormSource` 上加入以下断言，保留既有 `SlimFormScrollView` 与无 `fixedSize` 断言：

```swift
try expect(
    editFormSource.contains("SlimFormScrollView(usesContentHeight: true) {"),
    "edit form should opt into content-driven height negotiation"
)
```

在同一个契约函数中，读取 `SlimFormScrollView.swift` 后加入以下断言：

```swift
try expect(
    scrollerSource.contains("let usesContentHeight: Bool")
        && scrollerSource.contains("init(usesContentHeight: Bool = false"),
    "shared slim scroller should keep content-height negotiation opt-in"
)
try expect(
    scrollerSource.contains("override var intrinsicContentSize: NSSize")
        && scrollerSource.contains("invalidateIntrinsicContentSize()"),
    "content-height scroller should expose and invalidate measured intrinsic height"
)
```

如果当前函数未读取 `SlimFormScrollView.swift`，先复用其已有的 `rootURL`，加入：

```swift
let scrollerSource = try String(
    contentsOf: rootURL
        .appendingPathComponent("WidgetToDo")
        .appendingPathComponent("SlimFormScrollView.swift"),
    encoding: .utf8
)
```

- [ ] **Step 2: 运行 smoke，确认它因缺少自适应模式而失败**

运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache \
swift run NotionFloatCoreSmokeTests
```

预期：失败信息包含 `edit form should opt into content-driven height negotiation`。该红灯证明旧代码仍使用无固有高度的共享容器；若先失败于其他断言，先修正断言放置范围而不修改生产代码。

- [ ] **Step 3: 提交仅包含回归契约的红灯提交**

```bash
git add Tests/NotionFloatCoreSmokeTests/main.swift
git commit -m "test: cover adaptive edit task height"
```

### Task 2: 给共享滚动容器增加按内容协商高度的能力

**Files:**
- Modify: `WidgetToDo/SlimFormScrollView.swift:10-24,46-90`

- [ ] **Step 1: 为 `SlimFormScrollView` 增加默认关闭的模式参数**

将组件的存储属性和初始化器改为：

```swift
struct SlimFormScrollView<Content: View>: NSViewRepresentable {
    let usesContentHeight: Bool
    let content: Content

    init(
        usesContentHeight: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.usesContentHeight = usesContentHeight
        self.content = content()
    }

    func makeNSView(context: Context) -> HostingScrollView<Content> {
        HostingScrollView(rootView: content, usesContentHeight: usesContentHeight)
    }
}
```

保持 `updateNSView` 继续调用 `scrollView.update(rootView: content)`；开关是构造期不变配置，不在每次 SwiftUI 更新时切换。

- [ ] **Step 2: 在 `HostingScrollView` 中保存并公开测量后的高度**

将存储属性和初始化器开头替换为：

```swift
final class HostingScrollView<Content: View>: NSScrollView {
    private let hostingView: NSHostingView<Content>
    private let usesContentHeight: Bool
    private var measuredContentHeight: CGFloat = 1

    init(rootView: Content, usesContentHeight: Bool) {
        self.usesContentHeight = usesContentHeight
        hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        // 保留现有滚动条、背景和 documentView 配置。
    }

    override var intrinsicContentSize: NSSize {
        guard usesContentHeight else { return super.intrinsicContentSize }
        return NSSize(width: NSView.noIntrinsicMetric, height: measuredContentHeight)
    }
}
```

保留 `documentView = hostingView` 与既有 5 pt `SlimVerticalScroller` 配置，不引入自动布局约束。

- [ ] **Step 3: 在每次文档高度测量后，仅在实际变化时失效固有高度**

将 `updateDocumentLayout()` 的测量尾部改为：

```swift
let contentHeight = max(hostingView.fittingSize.height, 1)
hostingView.frame.size.height = contentHeight
updateMeasuredContentHeight(contentHeight)
reflectScrolledClipView(contentView)
```

并在该方法之后加入：

```swift
private func updateMeasuredContentHeight(_ contentHeight: CGFloat) {
    guard usesContentHeight,
          abs(measuredContentHeight - contentHeight) > 0.5
    else { return }

    measuredContentHeight = contentHeight
    invalidateIntrinsicContentSize()
}
```

继续保留 `guard documentWidth > 0 else { return }`，使首次零宽布局不发布错误高度。`0.5 pt` 阈值防止小数像素反复失效造成布局循环。

- [ ] **Step 4: 运行 smoke，确认共享组件契约通过、编辑调用点仍失败**

运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache \
swift run NotionFloatCoreSmokeTests
```

预期：共享组件相关断言通过，仍失败于 `edit form should opt into content-driven height negotiation`。

- [ ] **Step 5: 提交共享组件实现**

```bash
git add WidgetToDo/SlimFormScrollView.swift
git commit -m "feat: support content-sized slim scrollers"
```

### Task 3: 只为编辑任务启用内容自适应模式

**Files:**
- Modify: `WidgetToDo/ContentView.swift:2088-2254`

- [ ] **Step 1: 替换编辑表单的共享滚动容器调用**

将 `EditTaskFormCard` 外层调用从：

```swift
SlimFormScrollView {
```

改为：

```swift
SlimFormScrollView(usesContentHeight: true) {
```

不修改内部字段、`typeOptionsMenu`、按钮事件、卡片宽度或以下既有安全约束：

```swift
.frame(width: NewTaskFormMetrics.cardWidth)
.frame(minHeight: NewTaskFormMetrics.cardMinHeight, maxHeight: NewTaskFormMetrics.cardMaxHeight)
```

- [ ] **Step 2: 运行 smoke，确认全量 smoke 通过**

运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache \
swift run NotionFloatCoreSmokeTests
```

预期：`All smoke tests passed.`

- [ ] **Step 3: 运行完整单测和 Debug 构建**

运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache \
swift test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo \
  -configuration Debug \
  -derivedDataPath /private/tmp/widgettodo-edit-task-adaptive-height-build \
  CODE_SIGNING_ALLOWED=NO build
```

预期：`swift test` 为 70 tests / 0 failures；构建输出包含 `BUILD SUCCEEDED`。

- [ ] **Step 4: 手测已配置的编辑任务弹框**

在运行中的应用中执行：

1. 打开任意现有任务的编辑弹框，确认保存按钮下没有大块留白。
2. 展开类型选择；确认弹框仅增长到内容高度，且内容超过 376 pt 时显示现有 5 pt 纵向滚动条。
3. 滚动到最底部，确认取消与保存按钮可达。
4. 收起类型列表，确认弹框重新收紧。
5. 点击取消，确认未写入 Notion。

若隔离构建没有 Tasks 数据库配置，记录为手测阻塞，不读取、复制或输入 Notion token。

- [ ] **Step 5: 更新进度并提交成品**

在 `progress.md` 顶部新增一条，记录根因、文件影响、红绿 smoke、完整测试、构建和手测结果。然后：

```bash
git add WidgetToDo/ContentView.swift Tests/NotionFloatCoreSmokeTests/main.swift progress.md
git commit -m "fix: adapt edit task form height"
```
