# Progress

## 2026-08-12 - 编辑任务弹框固定头尾与自适应中部滚动
- 目标: 消除类型列表关闭时取消/保存下方的无效空白；展开类型或内容过高时，仅让中部字段与选项滚动，标题和取消/保存始终固定可见，并以平滑动画完成收展。
- 根因: 上一版将标题、字段、类型列表和按钮全部置于同一个 `NSScrollView` 文档。即使可视高度已限制，底部操作区仍属于滚动内容，无法满足“头尾固定”的交互边界。
- 影响路径:
  - `WidgetToDo/ContentView.swift`: `EditTaskFormCard` 改为固定标题（35 pt）、内容自适应的中部 `SlimFormScrollView`、固定操作区（58 pt，恰好容纳 38 pt 按钮及原有上下内边距）。中部上限为卡片 376 pt 扣除固定区域；字段 Binding、错误提示、类型筛选、取消/保存和 Notion 数据流未变。`isTypeOptionsPresented` 以 0.22 秒 `easeInOut` 动画驱动高度过渡。
  - `Tests/NotionFloatCoreSmokeTests/main.swift`: 编辑表单回归契约要求固定头尾、中部专用上限及收展动画，并断言中部上限必须从 376 pt 卡片上限中扣除固定头尾高度；既有上限契约同步为中部高度上限。
  - `WidgetToDo/SlimFormScrollView.swift`: 未改动；复用既有“固有高度受限、完整文档高度保留”的实现，确保中部内容仍可滚动到底。
- 状态: 已在隔离分支 `fix/edit-task-fixed-regions` 完成代码、自动化验证与无写入桌面手测；待合并到本地 `main`。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift run NotionFloatCoreSmokeTests` — 新契约先在旧单一滚动文档上按预期失败：`edit form should split fixed header and footer from its scrollable content`；实现并更新旧上限契约后通过。独立审查后补充“中部上限扣除固定头尾”的契约，复跑仍为 `All smoke tests passed.`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift test` — 70 tests / 0 failures（仅既有 `PomodoroSessionEngineTests` 未使用返回值警告）。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/widgettodo-edit-task-fixed-regions-build CODE_SIGNING_ALLOWED=NO build` — `BUILD SUCCEEDED`。
- 手测: 运行隔离 Debug app，打开任务「但是发生的」编辑弹框。折叠时辅助功能树显示独立的标题、中部滚动区和取消/保存；展开 6 个类型时中部出现独立滚动条，而标题与取消/保存仍同层可见；再次收起后中部滚动条消失；点击取消后表单关闭，未执行保存。
- 风险/回滚点: 固定区高度目前为 35 + 58 pt；将来若按钮或标题尺寸变化，需同步调整其常量以保持中部上限正确。回滚 `EditTaskFormCard` 的三段重组和 smoke 契约即可恢复旧单一滚动策略，不影响任务数据或 Notion 配置。

## 2026-08-12 - 修复编辑任务类型展开越出弹框
- 目标: 修复编辑任务弹框展开类型列表后，标题越出顶部、取消/保存按钮越出底部的问题；保留关闭列表时的紧凑自适应高度，以及超出上限后的表单滚动。
- 根因: 自适应模式将完整表单内容高度作为 `NSScrollView` 的固有高度返回。外层 SwiftUI 的 `frame(maxHeight: 376)` 约束了卡片背景，却没有约束 AppKit 滚动容器本身，导致完整文档继续绘制到卡片之外。
- 方案: `SlimFormScrollView` 新增可选 `contentHeightLimit`。编辑表单传入既有 `NewTaskFormMetrics.cardMaxHeight`（376 pt）；滚动容器固有高度取“内容实测高度”和该上限的较小值，但其文档视图仍保持完整高度，因此超过上限时由原有 5 pt 极细滚动条访问所有字段和按钮。新建任务弹框不传该配置，行为不变。
- 影响路径:
  - `WidgetToDo/SlimFormScrollView.swift`: 为内容高度模式增加可选上限，并只限制滚动容器的固有高度，保留完整文档高度。
  - `WidgetToDo/ContentView.swift`: 仅 `EditTaskFormCard` 传入既有卡片最大高度。
  - `Tests/NotionFloatCoreSmokeTests/main.swift`: 增加“固有高度受限、完整文档保留”的回归合约；调整与多行初始化器无关的脆弱文本匹配。
- 状态: 已于 2026-08-12 合并至本地 `main`；自动化验证已通过，待用户在已配置的应用中展开类型列表回测视觉边界与按钮可达性。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift run NotionFloatCoreSmokeTests` — 新合约先在旧实现上按预期失败：`content-height scroller should cap its intrinsic height while preserving the full scroll document`；实现后通过，`All smoke tests passed.`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/widgettodo-edit-task-height-overflow-build CODE_SIGNING_ALLOWED=NO build` — `BUILD SUCCEEDED`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift test` — 70 tests / 0 failures（仅有既有 `PomodoroSessionEngineTests` 未使用返回值警告）。
- 手测: 隔离 Debug app 的桌面自动化启动此前多次返回 `timeoutReached`；为不读取、复制或输入用户现有 App 的 Notion 配置，未操作安装版。需用户回测：展开类型后标题与按钮均留在弹框内，列表过长时可滚动到取消/保存，收起后弹框仍保持紧凑。
- 风险/回滚点: 上限只作用于编辑弹框的可视滚动容器，完整文档高度与可视高度在溢出时会有意不同；回滚 `contentHeightLimit` 配置可恢复此前策略，但会重现越界。

## 2026-08-11 - 编辑任务弹框内容自适应高度
- 目标: 移除编辑任务弹框在类型列表关闭时、保存按钮下方的大块无效留白；内容超过安全上限时保留既有 5 pt 极细滚动条和完整表单可达性。
- 方案: 用户在视觉对比中选择 A「内容自适应 + 最大高度」。编辑表单按实际内容高度收紧，仍由既有 `242...376 pt` 卡片约束处理最小高度、最大高度及溢出滚动；新建任务弹框不启用此模式。
- 影响路径:
  - `WidgetToDo/SlimFormScrollView.swift`: `SlimFormScrollView` 增加默认关闭的 `usesContentHeight` 配置；开启时，`HostingScrollView` 把按当前宽度测得的 `NSHostingView.fittingSize.height` 作为固有高度，并仅在变化超过 0.5 pt 时失效尺寸，防止布局循环。
  - `WidgetToDo/ContentView.swift`: 仅 `EditTaskFormCard` 调用 `SlimFormScrollView(usesContentHeight: true)`；字段、Binding、取消/保存和 Notion 数据流不变。
  - `Tests/NotionFloatCoreSmokeTests/main.swift`: 新增内容高度模式、固有高度和失效机制的回归合约。
- 状态: 已完成代码与自动化验证；等待用户在已配置应用中确认实际弹框高度和类型列表滚动。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift run NotionFloatCoreSmokeTests` — 先红：`shared slim scroller should keep content-height negotiation opt-in`；共享能力完成后第二次按预期只剩 `edit form should opt into content-driven height negotiation`；启用编辑调用点后通过，`All smoke tests passed.`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift test` — 70 tests / 0 failures（仅有既有 `PomodoroSessionEngineTests` 未使用返回值警告）。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/widgettodo-edit-task-adaptive-height-build CODE_SIGNING_ALLOWED=NO build` — `BUILD SUCCEEDED`。
- 手测: 尝试通过 Computer Use 启动隔离构建 `/private/tmp/widgettodo-edit-task-adaptive-height-build/Build/Products/Debug/WidgetToDo.app`，自动化通道返回 `timeoutReached`；为不读取、复制或输入用户现有 App 的 Notion 配置，未操作安装版。需用户验证普通编辑时无底部留白、展开类型后底部按钮可滚动到达、收起后再次收紧及取消不写入。
- 风险/回滚点: 首次显示或类型列表收展时，AppKit 与 SwiftUI 之间可能有一次正常的重新布局；0.5 pt 阈值避免持续失效。回滚编辑调用点的 `usesContentHeight: true` 即恢复原固定高度策略，不影响任务数据。

## 2026-08-11 - 消除状态栏右键菜单 QoS priority inversion
- 目标: 消除 Thread Performance Checker 在 `StatusBarController.swift:114` 报告的“User-interactive 线程等待 Default QoS 线程”风险；保留左键开关浮窗、右键菜单、设置和退出行为。
- 根因: `NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp)` 的 user-interactive 事件回调内同步调用 `NSMenu.popUpContextMenu`。该 API 进入 AppKit 菜单跟踪循环并等待较低 QoS 的内部工作，触发 priority inversion 诊断。不能改为长期设置 `NSStatusItem.menu`，因为 Apple 文档明确其非空时会停用状态项的单击 action。
- 影响路径:
  - `WidgetToDo/StatusBarController.swift`: 本地监视器只截获并消费右键事件；新增 `presentContextMenu`，使用 `DispatchQueue.main.async` 在下一主队列轮次展示同一菜单、事件和按钮，避免在 user-interactive 回调内同步等待。
  - `Tests/NotionFloatCoreSmokeTests/main.swift`: 防回归契约要求右键处理转交给延迟展示函数，并要求该函数经由主队列调用 `NSMenu.popUpContextMenu`。
- 状态: 已完成代码与自动化验证；桌面 UI 自动化启动隔离 Debug app 超时，需在 Xcode 开启 Thread Performance Checker 后人工右键状态栏图标确认菜单可打开且不再报告该行。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift run NotionFloatCoreSmokeTests` — 新契约先在旧同步实现上按预期失败：`status bar event monitor should defer contextual menu presentation instead of tracking it inline`；实现后通过，`All smoke tests passed.`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/widgettodo-statusbar-qos-build CODE_SIGNING_ALLOWED=NO build` — `BUILD SUCCEEDED`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift test` — 70 tests / 0 failures。
- 手测: 已尝试通过 Computer Use 启动 `/private/tmp/widgettodo-statusbar-qos-build/Build/Products/Debug/WidgetToDo.app`，自动化通道返回 `timeoutReached`；为不读取或改写用户已安装 App 的 Notion 配置，未继续操作。需人工验证右键菜单位置及 Thread Performance Checker。
- 风险/回滚点: 菜单展示推迟一个主队列轮次，视觉上最多增加极短调度延迟；回滚 `presentContextMenu` 调用即可恢复同步展示，但会重现 QoS 警告。

## 2026-08-11 - 修复编辑任务弹框空白
- 目标: 修复编辑任务弹框显示为空白卡片的回归；保留共享 5 pt 极细滚动条、字段 Binding、类型筛选、保存/取消及 Notion 数据流。
- 根因: 编辑表单保留了只适用于 SwiftUI `ScrollView` 的 `.fixedSize(horizontal: false, vertical: !isTypeOptionsPresented)`。改为 AppKit `NSScrollView` 后，该视图没有固有尺寸（本机查询为 `-1 × -1`），导致嵌入的表单内容无法获得有效布局高度。
- 影响路径:
  - `WidgetToDo/ContentView.swift`: 仅移除编辑表单外层的上述固定尺寸修饰符；原有卡片宽度、最小/最大高度和类型列表滚动逻辑保留。
  - `Tests/NotionFloatCoreSmokeTests/main.swift`: 将旧的固定尺寸约束改为反向合约，防止 AppKit 容器重新引入不兼容修饰符。
- 状态: 已完成代码与自动化验证；等待用户在已配置 app runtime 中重新打开编辑任务确认表单内容可见。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift run NotionFloatCoreSmokeTests` — 先红：`AppKit-backed edit form should not use the incompatible fixed-size modifier`；移除修饰符后通过，`All smoke tests passed.`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift test` — 70 tests / 0 failures。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/widgettodo-edit-form-empty-build CODE_SIGNING_ALLOWED=NO build` — `BUILD SUCCEEDED`。
- 手测: 原问题由用户截图确认；当前修复构建未配置 Tasks 数据库，无法在不读取或输入 Notion 凭据的情况下打开编辑表单。需用户回测确认标题、时长、类型及取消/保存按钮均恢复显示。
- 风险/回滚点: 移除固定尺寸后，编辑弹框会由现有 `frame(minHeight:maxHeight:)` 决定可视高度，可能比关闭类型列表时稍高；回滚这一处修饰符即可恢复旧尺寸策略，但会重现空白卡片。

## 2026-08-11 - 新建与编辑任务弹框的极细滚动条
- 目标: 将新建任务与编辑任务弹框右侧滚动条统一为 5 pt 极细自定义滑块，保留表单字段、Notion 数据流、表单尺寸及滚轮/触控板/键盘/滑块拖拽语义。
- 非目标: 不调整标题、日期、时长、类型字段、创建/保存/取消动作或 Notion 配置。
- 影响路径:
  - `WidgetToDo/SlimFormScrollView.swift`: 新增共享 AppKit 容器与不绘制轨道的 `SlimVerticalScroller`；滑块宽度固定为 5 pt，保留 `NSScroller` 原生拖拽与自动隐藏；每次 SwiftUI 内容更新或容器布局后都显式重算文档宽高，以同步编辑任务类型列表收展后的可滚动范围与滑块比例。
  - `WidgetToDo/NewTaskFormCard.swift`、`WidgetToDo/ContentView.swift`: 新建/编辑任务弹框仅替换外层滚动容器；字段 Binding、按钮与编辑任务类型下拉框收展逻辑不变。
  - `Tests/NotionFloatCoreSmokeTests/main.swift`: 新增共享极细滚动组件与两个调用入口的合约；旧断言同步为同一“可溢出、不裁切”语义。
- 状态: 已完成代码与自动化验证；桌面 UI 手测受隔离构建未配置 Tasks 数据库阻塞。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift run NotionFloatCoreSmokeTests` — 两次先红：先因 `SlimFormScrollView.swift` 缺失、后因缺少动态文档高度刷新而失败；实现后通过，`All smoke tests passed.`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/widgettodo-clang-cache swift test` — 70 tests / 0 failures。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/widgettodo-slim-scroller-build CODE_SIGNING_ALLOWED=NO build` — `BUILD SUCCEEDED`。
- 手测: 已启动隔离 Debug app，但当前只显示“欢迎使用 WidgetToDo / 开始配置”。该隔离环境没有已配置的 Tasks 数据库；为避免读取或输入 Notion token，未进入新建/编辑任务弹框。因此 5 pt 宽度、拖拽及类型列表动态高度仍需在已配置的 app runtime 中人工核对。
- 风险/回滚点: 独立代码复核未发现 Critical 问题；动态高度刷新已由 `HostingScrollView.updateDocumentLayout()` 覆盖，但仍需真实表单手测验证。回滚共享组件与两处外层容器替换即可恢复系统滚动条，不影响任务或 Notion 数据。

## 2026-08-11 - 编辑任务弹框底部留白收紧
- 目标: 移除编辑任务弹框在类型列表关闭时按钮下方的大块无效空白，同时保持类型列表展开后的最大高度与纵向滚动。
- 非目标: 不改新建任务弹框、编辑字段尺寸、保存/取消交互、Notion 数据绑定或类型选择逻辑。
- 影响路径:
  - `WidgetToDo/ContentView.swift`: 编辑表单仅在类型列表关闭时按内容高度收缩；列表展开时继续使用现有最大高度和外层滚动。
  - `Tests/NotionFloatCoreSmokeTests/main.swift`: 编辑表单源码契约限定到 `EditTaskFormCard` 区段，并断言高度收缩仅在类型列表关闭时启用。
- 状态: 已合并至本地主分支 `main`。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` — 通过；新契约先在原实现上按预期失败：`edit form should shrink only while the type list is closed`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoEditCardHeightDerivedData build` — `BUILD SUCCEEDED`。
- 手测: 使用隔离 Debug app 编辑现有任务。类型列表关闭时弹框高度紧凑，保存/取消下方不再有大块留白；展开 6 个类型后外层滚动条从 0 滚到 1，取消/保存按钮仍可达；取消关闭弹框，未触发 Notion 写入。
- 风险/回滚点: 收缩逻辑依赖 `isTypeOptionsPresented`；回滚该 `fixedSize` 动态约束即可恢复原高度行为。

## 2026-08-11 - 编辑任务类型搜索下拉框与溢出滚动
- 目标: 让编辑任务弹框的类型选择与新建任务一致：左侧可输入筛选，右侧固定下箭头展开；当类型列表使弹框内容超过承载高度时可纵向滚动。
- 非目标: 不改 `TodoListViewModel.editingPriority` 的数据绑定、Notion Select 选项来源、`saveTaskEdit()` 请求、标题/时长校验、新建任务弹框或类型颜色映射。
- 影响路径:
  - `WidgetToDo/ContentView.swift`: `EditTaskFormCard` 以输入框、分区下箭头和筛选列表替换原生 `Menu`；表单增加共享最大高度与垂直 `ScrollView`。
  - `Tests/NotionFloatCoreSmokeTests/main.swift`: 新增编辑类型输入/下箭头/筛选/清空/选项可见高度/弹框滚动的源码契约；将既有日期标题契约限定到工具栏范围，避免其他组件的 28pt 行高造成误报。
- 状态: 已合并至本地主分支 `main`。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` — 通过，`All smoke tests passed.`；新增契约先在原生 `Menu` 实现上按预期失败：`edit picker should keep local search text`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` — 70 tests / 0 failures；全新编译基线仅有既有 `PomodoroSessionEngineTests` 未使用返回值警告。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoEditTaskTypePickerDerivedData build` — `BUILD SUCCEEDED`；仅有 Xcode 多个 macOS destination 与 AppIntents metadata 跳过的环境警告。
- 手测: 使用隔离 Debug app 打开现有任务「但是发生的」的编辑弹框。点击下箭头显示 6 个 Notion 类型；输入“生活”仅显示“生活杂事”，选择后输入框回显“生活杂事”；再次展开并点击“未选择”可清空。展开全量列表时编辑卡片的滚动条可从 0 滚到 1，底部取消/保存按钮仍可达；点击取消后弹框关闭，任务列表仍显示原“工作/创作”，未执行 Notion 写入。
- 风险/回滚点: 选项较多时，类型列表与表单共享编辑弹框纵向滚动区域；回滚 `EditTaskFormCard` 的类型选择与 `ScrollView` 改动即可恢复原生 `Menu`。

## 2026-08-11 - 新建任务类型搜索下拉框与溢出滚动
- 目标: 重做新建任务弹框的类型选择器：左侧可输入筛选，右侧固定下箭头展开；当类型列表使弹框内容超出承载高度时，可在弹框内纵向滚动查看全部内容。
- 非目标: 不改 `NewTaskViewModel.priority`、Notion Select 选项来源、创建任务请求、编辑任务弹框或类型颜色映射。
- 影响路径:
  - `WidgetToDo/NewTaskFormCard.swift`：`TaskChoicePicker` 改为输入框 + 分区下箭头 + 可筛选选项列表；新建任务表单增加最大高度与纵向 `ScrollView`，避免内容裁切。
  - `Tests/NotionFloatCoreSmokeTests/main.swift`：新增类型输入/下箭头/筛选/清空/选项可见高度/弹框滚动的源码契约。
- 状态: 已合并至本地主分支 `main`。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` — 通过，`All smoke tests passed.`；新增契约先后在旧 `Menu`、零高度列表、非滚动弹框实现上按预期失败。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` — 69 tests / 0 failures。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoTypePickerDerivedData build` — `BUILD SUCCEEDED`。
- 手测: 启动隔离构建的 App，打开「+」后确认类型输入框与分隔下箭头出现；展开后显示 6 个 Notion 类型；输入筛选与选择“工作/创作”正常写回输入框；展开列表后弹框出现可用的垂直滚动区，滚动条从 0 到 1，取消关闭弹框且未创建任务。
- 风险/回滚点: 选项较多时，类型列表与表单共享弹框纵向滚动区域；回滚 `TaskChoicePicker` 和表单 `ScrollView` 的本次改动即可恢复原生 `Menu`。

## 2026-08-11 - 任务元信息相邻元素间距统一为 4pt
- 目标: 将任务列表中时间标签、选择标签、分隔点和同步状态之间的相邻元素间距由 6pt 统一调整为 4pt。
- 非目标: 不改标签内部内边距、Notion 颜色映射、时长显示规则、右侧“计时/更多”操作区或其他页面布局。
- 影响路径:
  - `ContentView`：仅调整任务元信息行的共享间距常量。
  - `TaskRowLayoutContractTests`：新增 4pt 间距回归契约。
- 状态: 已合并至本地主分支 `main`。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter TaskRowLayoutContractTests` — 2 tests / 0 failures。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` — 70 tests / 0 failures（存在基线已有的 PomodoroSessionEngineTests 未使用返回值警告）。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoTaskMetaSpacingDerivedData build` — `BUILD SUCCEEDED`。
- 手测: 实际浮窗中“工作/创作 · 已同步”与“1 分钟 · 学习 · 已同步”均保持单行，右侧“计时/更多”完整显示；相邻元信息采用 4pt 间距。
- 风险/回滚点: 仅收紧元信息行横向空隙；极窄窗口仍沿用既有截断与优先级策略。回滚该分支提交即可恢复 6pt。

## 2026-08-11 - 选择标签按文本自适应宽度
- 目标: 修复短选择项（如“工作/创作”）被拉伸为固定长胶囊的问题。
- 根因: 标签文字设置了 `maxWidth: 142`，在任务行存在剩余空间时会扩展到该宽度，而不是采用文字的固有宽度。
- 影响路径:
  - `ContentView`：移除选择标签的固定宽度约束；标签现在按选项文字加原有内边距确定宽度，空间不足时仍保持单行尾部截断。
  - `TaskRowLayoutContractTests`：禁止选择标签恢复固定宽度约束。
- 状态: 已合并至本地主分支 `main`。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter TaskRowLayoutContractTests` — 1 test / 0 failures。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` — 69 tests / 0 failures（存在基线已有的 PomodoroSessionEngineTests 未使用返回值警告）。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoAdaptiveChoiceTagDerivedData build` — `BUILD SUCCEEDED`。
- 手测: 实际浮窗的“工作/创作”和“学习”标签均已收紧到文字与内边距的宽度；右侧“计时/更多”完整显示。
- 风险/回滚点: 特别长的选项值会占用可用空间并按既有单行截断策略缩短；回滚该分支提交即可恢复原行为。

## 2026-08-11 - 修复任务行计时按钮文本被压缩
- 目标: 修复任务列表在显示 Select 标签后，“计时”按钮只剩边框、文字不可见的问题。
- 根因: 任务行左侧内容区域的优先级提高后，右侧操作容器仍允许横向压缩，导致“计时”和失败任务的“重试”文本被压到零宽或换行。
- 影响路径:
  - `ContentView`：右侧操作容器保持固有横向宽度；左侧任务内容继续使用剩余空间。未改动计时交互、任务数据或 Notion 同步。
  - `TaskRowLayoutContractTests`：增加右侧操作容器不可横向压缩的回归约束。
- 状态: 已合并至本地主分支 `main`。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter TaskRowLayoutContractTests` — 1 test / 0 failures。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` — 69 tests / 0 failures（存在基线已有的 PomodoroSessionEngineTests 未使用返回值警告）。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoTaskActionWidthDerivedData build` — `BUILD SUCCEEDED`。
- 手测: 实际浮窗中的“阅读”任务已显示完整“计时”按钮；时长、选择标签、同步状态与“更多”按钮仍在同一行。
- 风险/回滚点: 右侧操作区现在优先保留完整内容；极窄窗口会先压缩左侧可截断内容。回滚该分支提交即可恢复原布局。

## 2026-08-11 - 修复任务时长徽章换行
- 目标: 修复任务列表同时显示时长和 Select 选项时，时长文本（如“1 分钟”）被压缩为两行的问题。
- 影响路径:
  - `ContentView`：为时长徽章保留单行固有宽度；任务的左侧内容区域优先获得右侧操作按钮之外的可用宽度；Select 值仍限制单行，超长时尾部截断并可悬停查看全文。移除标签前圆点，改用对应 Notion 选项颜色的文字与浅色背景展示标签。
  - `TaskRowLayoutContractTests`：新增布局契约，防止时长再次被压缩换行，且确保任务内容区域优先分配宽度、选择标签无独立圆点。
- 状态: 已合并至本地主分支 `main`。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter TaskRowLayoutContractTests` — 1 test / 0 failures。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` — 69 tests / 0 failures。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoChoiceTagDerivedData build` — `BUILD SUCCEEDED`。
- 手测: 使用实际浮窗的“阅读”任务验证，元信息显示为“1 分钟 · 学习 · 已同步”，三项均在同一行；“学习”以其 Notion 蓝色显示文字和浅蓝标签底色、没有圆点；右侧“计时/更多”操作区位置保持不变。
- 风险/回滚点: 极窄窗口或极长选项名称下，Select 值将按既定策略尾部截断，时长与右侧操作按钮优先保留；回滚该分支提交即可恢复原布局。

## 2026-08-11 - 自动刷新任务 Select 映射与配置错误详情
- 目标: 修复旧配置未保存 Select 选项时新建任务不显示选择器的问题，并保留配置失败的具体原因。
- 影响路径:
  - `NotionRepository`：仅当本地 Select 选项为空时读取一次 Tasks schema；成功后仅更新该可选字段映射和选项，失败时保留原设置。
  - `ContentView`：启动、设置页与刷新入口均应用最新映射；不改任务数据和既有表单布局。
  - `AppLocalizer`：字段映射失败提示保留 Notion 的可读错误详情。
  - 测试：新增旧配置自动发现 Select 的回归测试，并覆盖详情错误本地化。
- 状态: 已合并至本地主分支。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` — 合并后 68 tests / 0 failures。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoConfigurationRefreshDerivedData build` — `BUILD SUCCEEDED`。
- 手测: 未直接操作用户现有 Notion 会话；合并后在 App 中点击刷新或重启，若数据库恰有一个带选项的 Select，应在新建任务“时长”下出现选择器。
- 风险/回滚点: 首次发现缺失选项时多一次 Tasks schema 请求；请求失败不会阻塞启动或改写旧设置。回滚该条目的关联提交即可恢复旧行为。

## 2026-08-11 - Task Select field
- 状态: 已合并至本地主分支；待真实 Notion 数据库手测。
- 行为: 仅在 Tasks 数据库恰好有一个包含选项的 Select 字段时显示创建/编辑控件与任务列表胶囊；颜色由该 Notion 选项颜色决定；长文本尾部截断并可悬停查看全文。
- 验证: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` 通过（66 tests / 0 failures）；`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoTaskSelectDerivedData build` 通过。
- 手测: 待确认真实数据库中的创建、编辑、清空同步及零/多 Select 降级。

## 2026-08-10 - README 补充 Notion 数据库搭建详细教程
- 目标: 在「配置 Notion 集成」部分补充完整的数据库搭建教程，让用户清楚知道怎么创建数据库、需要哪些字段、如何关联。
- 依据: 读取 FieldValidator.swift / NotionClient.swift / NotionRepository.swift / AppSettings.swift 代码，确认实际字段校验逻辑。
- 字段要求（已写入 README）:
  - Tasks 数据库必须：1 个 title + 1 个 date + 1 个 checkbox（每种类型恰好 1 个，否则校验失败）。
  - Tasks 数据库可选：1 个 select（优先级，选项 Urgent/High/Medium/Low）+ 1 个 number（预计时长，分钟）。多于 1 个则该功能禁用。
  - Journal 数据库必须：1 个 title + 1 个 date。正文写入页面 body，不需要文本字段。
- 教程结构（中英文版均 5 步）:
  1. 创建 Notion 集成令牌（my-integrations 页面，能力勾选）。
  2. 搭建 Tasks 数据库（字段表格 + 字段数量约束警告）。
  3. 搭建 Journal 数据库（字段表格 + 正文说明）。
  4. 把集成共享到两个数据库（Connections 操作步骤）。
  5. 在应用中填入配置（粘贴 URL 自动提取 ID）。
- 影响路径:
  - 修改 `WidgetToDo/README.md`：「配置 Notion 集成」从 4 行扩展为完整 5 步教程。
  - 修改 `WidgetToDo/README.en.md`：同步英文版。
- 状态: 已完成。
- 最近验证:
  - 命令: `audit_readme.py README.md` / `audit_readme.py README.en.md` — 均通过。
  - 无 `swift test`：本次仅改 README 文档，不涉及代码或测试变更。
- 风险/回滚点:
  - 字段要求基于当前代码逻辑（FieldValidator.resolveTasks / resolveJournal），若后续代码改变字段校验逻辑需同步更新 README。
  - 回滚：`git checkout -- README.md README.en.md` 即可。

## 2026-08-10 - README 顶部添加醒目下载按钮
- 目标: 在两个 README 顶部 badges 下方添加大号下载按钮，链接到 Releases 页面，方便用户快速找到下载入口。
- 影响路径:
  - 修改 `WidgetToDo/README.md`：badges 下方新增 `for-the-badge` 样式的「⬇ 下载 WidgetToDo v1.1」蓝色按钮，链接到 Releases。
  - 修改 `WidgetToDo/README.en.md`：同步新增英文版「⬇ Download WidgetToDo v1.1」按钮。
- 状态: 已完成。
- 最近验证:
  - 命令: `audit_readme.py README.md` / `audit_readme.py README.en.md` — 均通过；图片引用无新增问题。
  - 无 `swift test`：本次仅改 README 文案，不涉及代码或测试变更。
- 风险/回滚点:
  - 下载按钮用 shields.io 动态生成，离线时无法加载；但 GitHub 默认联网，正常显示。
  - 回滚：`git checkout -- README.md README.en.md` 即可。

## 2026-08-10 - 新增英文版 README 并支持中英切换
- 目标: 创建英文版 README.en.md，在两个 README 顶部添加语言切换链接。
- 非目标: 不改 Swift 源码、测试、构建配置；不重做 SVG（英文版复用现有 hero 和架构图 SVG，章节头改用 markdown 标题避免中文装饰图）。
- 影响路径:
  - 新增 `WidgetToDo/README.en.md`：完整翻译中文 README，保留 hero.svg 和截图，架构图保留（技术术语为主），三个章节头 SVG 改用普通 markdown 标题。
  - 修改 `WidgetToDo/README.md`：在 hero 前添加语言切换链接。
- 状态: 已完成。
- 最近验证:
  - 命令: `audit_readme.py README.md` — 通过；6 个本地图片引用。
  - 命令: `audit_readme.py README.en.md` — 通过；3 个本地图片引用（hero + 截图 + 架构图）。
  - 无 `swift test`：本次仅新增/修改 README 文档，不涉及代码或测试变更。
- 风险/回滚点:
  - 英文版未用章节头 SVG，视觉上比中文版朴素，但避免了外国人看到无意义的中文装饰图。
  - hero.svg 和 architecture-flow.svg 中的中文文字在英文版中保留（前者展示应用实际 UI，后者以技术术语为主），外国人可理解。
  - 回滚：`git checkout -- README.md` 并 `rm README.en.md` 即可。
- 后续待跟进:
  - 如需英文版 SVG 章节头，可后续补做。

## 2026-08-10 - 补充 README 未签名应用放行说明
- 目标: 在 README「下载与安装」的 DMG 方式下，补充 macOS 首次启动未签名应用被拦截的多种解决方案。
- 非目标: 不改 Swift 源码、测试、构建配置；不改变应用签名策略。
- 是否会发生: 会。当前版本未做 Apple Developer 代码签名，用户首次从 DMG 安装后启动，macOS Gatekeeper 可能提示「无法验证开发者」或「无法检查是否包含恶意软件」。
- 解决方案（已写入 README）:
  1. 系统设置 → 隐私与安全性 → 仍要打开。
  2. 右键 `WidgetToDo.app` → 打开 → 确认框点「打开」。
  3. 终端执行 `xattr -cr /Applications/WidgetToDo.app` 移除隔离属性后再次双击。
- 影响路径:
  - 修改 `WidgetToDo/README.md`：将原来只有一句话的未签名提示，扩展为带编号列表的完整说明，并给出 `xattr -cr` 命令示例。
- 状态: 已完成。
- 最近验证:
  - 命令: `python3 .../audit_readme.py WidgetToDo/README.md` — 通过；6 个本地图片引用全部解析，无新增问题。
  - 无 `swift test`：本次仅改 README 文案，不涉及代码或测试变更。
- 风险/回滚点:
  - `xattr -cr` 会移除应用的扩展属性（包括 quarantine），这是开发者分发未签名应用的常规做法；对普通用户而言是安全的，但 README 已说明仅用于当前未签名版本。
  - 回滚：`git checkout -- README.md progress.md` 即可。
- 后续待跟进:
  - 如后续购买 Apple Developer 账号并做公证/签名，可移除该说明或改为「已签名，无需额外操作」。

## 2026-08-10 - Beautify README with project-native SVG assets
- 目标: 用 beautify-github-readme Skill 重设计 README 首页，新增纯 SVG 视觉系统（hero / 章节头 / 架构分层图），并按 Value → Proof → Mechanism → First use → Detail 重排信息架构；hero 和真实 proof 截图贴合实际应用 UI。
- 非目标: 不改任何 Swift 源码、测试、`Package.swift`、`.xcodeproj`、entitlements 或持久化逻辑；不用 ImageGen / 混合合成 / GIF 动画；不 commit、不 push。
- 模式: README 整体重设计（用户选定）· 纯 SVG（用户选定「图片生成仅需要 svg」）。
- 影响路径:
  - 新增 `WidgetToDo/assets/readme/hero.svg`（1200×420，左标题 + 右浅色真实 UI 浮窗面板：待办/日记 tab、日期导航、番茄钟环形进度卡片、任务行与时长徽章）。
  - 新增 `WidgetToDo/assets/readme/section-features.svg` / `section-getting-started.svg` / `section-architecture.svg`（1200×68，深色章节头横幅）。
  - 新增 `WidgetToDo/assets/readme/architecture-flow.svg`（1200×280，三列分层图）。
  - 新增 `WidgetToDo/docs/screenshots/` 目录（等待用户放入真实截图）。
  - 修改 `WidgetToDo/README.md`：顶部嵌入 hero；新增「它解决什么」首屏段落并嵌入 `docs/screenshots/app-main-light.png` 作为真实 proof；三个主章节前置 SVG 章节头；架构段嵌入 architecture-flow；保留全部原有技术内容。
- 视觉系统: hero 采用浅色暖灰画布（#F7F5F0）+ 真实应用 UI 配色（白卡片 #FFF、主文字 #1C1C1E、次要文字 #8E8E93、棕色 #B58A5F、完成按钮绿 #4CAF50、时长 pill 浅橙 #FFF5E6）；章节头/架构图保留深色自含背景以在 GitHub light/dark 下独立成块。
- 状态: 已完成；真实截图已就位，audit 通过。
- 最近验证:
  - 命令: `cp 微信图片_20260810123831_2045_19.png WidgetToDo/docs/screenshots/app-main-light.png` — 通过；图片 654×882，约 88KB。
  - 命令: `python3 .../audit_readme.py WidgetToDo/README.md` — 通过；6 个本地图片引用全部解析（5 SVG + 1 PNG 截图），SVG viewBox / title 基础检查通过。
  - 命令: 自写 Python 脚本对 5 个 SVG 做 bounds 校验 — 通过；无 rect/circle/text 溢出 viewBox，无 script/foreignObject，均有 `<title>`。
  - 命令: `sips -s format png hero.svg --out /tmp/hero-light.png` + `sips -g pixelWidth -g pixelHeight` — 通过；渲染为 1200×420 PNG，无错误。
  - 命令: integrated_browser 渲染 `/tmp/readme-full.html`（900px GitHub 宽度）— 页面快照确认 hero / 真实截图 / 章节头 / architecture-flow 按序加载，截图位于「它解决什么」之后、section-features 之前。
  - 无 `swift test`：本次仅改 README 与新增 SVG/PNG 静态资源，不涉及代码或测试变更。
- 风险/回滚点:
  - SVG 内中文依赖系统字体栈（PingFang SC / -apple-system）；GitHub 渲染端通常有中文字体。
  - 视觉未由我直接肉眼复核；用户可在 Browser View 或 GitHub 实际页面确认。
  - 回滚：`git checkout -- README.md progress.md` 并 `rm -rf assets/readme/ docs/screenshots/`，无代码影响。
- 后续待跟进:
  - 可选：经用户批准后，按 Skill Step 9 提供「README MADE WITH」签名。

## 2026-08-10 - Add MIT LICENSE
- 目标: 为仓库补充 MIT LICENSE 文件，明确授权他人使用、修改、分发代码；同步 README 许可证徽章与段落。
- 非目标: 不改 Swift 源码、测试、构建配置；版权行暂用 GitHub 用户名 `klosexf`，后续可由维护者改为真实姓名。
- 影响路径:
  - 新增 `WidgetToDo/LICENSE`（标准 MIT 文本，版权行 `Copyright (c) 2026 klosexf`）。
  - 修改 `WidgetToDo/README.md`：顶部徽章新增 `license-MIT`；许可证段落从「尚未声明」改为指向本地 `LICENSE` 的链接。
- 状态: 已完成；LICENSE 文件已创建，README 徽章与段落已同步。
- 最近验证:
  - 命令: `git status --short` — 显示新增 `LICENSE`、修改 `README.md` 与 `progress.md`，无其他意外改动。
  - 命令: `head -3 LICENSE` — 确认首行为 `MIT License`，第二行为空，第三行为 `Copyright (c) 2026 klosexf`。
  - 命令: `grep -c "license-MIT" README.md` — 通过，徽章已写入。
  - 无 `swift test`：本次仅新增许可证文档与 README 文案，不涉及代码或测试变更。
- 风险/回滚点:
  - 版权持有人写的是 GitHub 用户名 `klosexf`；若维护者希望用真实姓名，直接改 LICENSE 第二行即可。
  - 回滚：`git rm LICENSE` 并还原 README 徽章与许可证段落，无代码影响。

## 2026-08-10 - Add project README
- 目标: 为仓库新增一份 `README.md`，让 GitHub 仓库主页有项目说明，覆盖功能特性、系统要求、下载安装、Notion 集成配置、架构目录、构建测试、打包发布与开发约定。
- 非目标: 不改任何 Swift 源码、测试、`Package.swift`、`.xcodeproj`、entitlements 或 Notion / 持久化逻辑；不新增 LICENSE 文件（许可证由维护者后续决定）。
- 影响路径:
  - 新增 `WidgetToDo/README.md`（仓库根目录，GitHub 自动渲染）。
- 状态: 已完成；README 引用的全部文件路径已用脚本逐一核对存在性。
- 内容要点:
  - 徽章标注 macOS 15+ / Swift 6.2 / v1.1.0；不写 license 徽章（仓库尚未声明 LICENSE）。
  - 功能覆盖：悬浮面板、今日待办、新建任务（含可选预计时长）、当日日记、番茄钟、迷你胶囊、状态栏图标、多语言（zh-Hans/en/fr）、SQLite 本地缓存、Keychain 令牌。
  - 架构图标注 `View/ViewModel → NotionRepository → NotionClient/Store` 分层约束，与 AGENTS.md 一致。
  - 构建测试命令与 progress.md 既有条目一致：`swift build`、`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`、`swift run NotionFloatCoreSmokeTests`、`xcodebuild ... build`。
  - 明确说明 `AGENTS.md` 与 `bugs.md` 是本地维护、不进入 git 的文档，避免 GitHub 死链。
  - 截图留占位注释，待维护者补充 `docs/screenshots/` 后替换。
- 最近验证:
  - 命令: `cd WidgetToDo && for f in <README 引用的 27 个路径>; do [ -e "$f" ] && echo OK || echo MISS; done` — 通过；27 个路径全部 OK（含 `progress.md`、`Package.swift`、各 ViewModel/View、Core 子目录、lproj、Tests、docs/superpowers）。
  - 命令: `git ls-files | grep -iE "^(bugs|agents)\.md$"` — 确认 `bugs.md` / `AGENTS.md` 未被 git 追踪，README 已改为说明它们是本地不入库文档，无死链。
  - 命令: `git tag -l` — 确认最新 tag 为 `v1.1.0`，README 版本徽章与之相符。
  - 无 `swift test`：本次仅新增文档，不涉及代码或测试变更。
- 风险/回滚点:
  - README 中「截图占位」「LICENSE 待补充」为待办项，不影响功能。
  - 回滚：`git rm README.md` 或 `git checkout -- README.md` 即可，无代码影响。

## 2026-08-08 - Remove "不会修改任务状态" hint from focus start dialog
- 目标: 移除“开始进行专注”弹框底部按钮下方的“不会修改任务状态”提示文案。
- 非目标: 不改弹框结构、按钮、时长选择、文案“结束后本次时长将累计到‘时长’”；不改动番茄钟逻辑、状态、Notion 持久化。
- 影响路径:
  - `WidgetToDo/WidgetToDo/PomodoroViews.swift`: 移除 `PomodoroStartCard` 中 `PomodoroDialogHint(...)` 视图行；同步移除不再使用的 `PomodoroMetrics.dialogHintTopSpacing`。
- 状态: 已完成代码修改；自动化验证与 UI 手测受当前环境沙箱限制未完成。
- 最近验证:
  - `xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build` (sandbox 内): 失败。`PomodoroViews.swift` 单文件编译命令显示 `SwiftCompile normal arm64 Compiling PomodoroViews.swift` 正常，但整体构建因沙箱对 swift-plugin-server / Keychain 的 `sandbox-exec: sandbox_apply: Operation not permitted` 与 `#Preview` macro 插件响应异常而失败。
  - `swift test` / `swift build` (sandbox 内，Xcode 工具链): 失败，`sandbox-exec: sandbox_apply: Operation not permitted`。
  - 标准入口 `swift test` (CommandLineTools): 失败，缺 XCTest。
  - UI 手测: 未执行；建议在 Xcode 运行后确认“开始进行专注”弹框底部已不显示“不会修改任务状态”。
- 风险/回滚点:
  - 仅影响 `PomodoroStartCard` 视觉；如需恢复，补回 `PomodoroDialogHint(...)` 与 `dialogHintTopSpacing` 即可。
  - 不涉及任务时长累计逻辑或 Notion 状态变更。

## 2026-08-08 - Align new/edit task dialog buttons with Pomodoro focus dialog
- 目标: 将“新建任务”和“编辑任务”弹框底部的“取消/创建”与“取消/保存”两组按钮的样式和大小，改成与“开始进行专注”弹框底部的“取消/开始专注”按钮一致。
- 非目标: 不改弹框尺寸、输入框、标题、阴影/背景；不改番茄钟弹框本身；不动 Notion API、缓存、Keychain、设置持久化、Package.swift、.xcodeproj 或 entitlements。
- 影响路径:
  - `WidgetToDo/WidgetToDo/NewTaskFormCard.swift`: 更新 `NewTaskFormPalette` 主次按钮色值（主按钮改为 #34312e 深灰底白字，次按钮改为白底 #e2dbd2 边框 #5d554e 字）；`NewTaskPrimaryButtonStyle` / `NewTaskSecondaryButtonStyle` 高度改为 38pt、字号 12pt bold、圆角 9pt、横向撑满；底部 HStack 间距由 10 改为 8 并移除 `Spacer()`，使两按钮等宽并排。
  - `WidgetToDo/WidgetToDo/ContentView.swift`: `EditTaskFormCard` 底部 HStack 同样改为间距 8 并移除 `Spacer()`，复用更新后的按钮样式。
- 状态: 已完成代码修改；UI 手测待 Xcode / App runtime 中确认。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoButtonStyleDerivedData build`: 通过，`** BUILD SUCCEEDED **`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox`: 通过，`Executed 63 tests, with 0 failures`。
  - `swift test`（默认 CommandLineTools 环境）: 阻塞，编译 XCTest 目标时报 `no such module 'XCTest'`；属既有环境问题，已通过 Xcode 工具链验证。
  - UI 手测: 未执行；建议在 Xcode 运行后核对“新建任务”“编辑任务”底部按钮与“开始专注”弹框按钮在高度、圆角、颜色、字重与并排布局上视觉一致。
- 风险/回滚点:
  - 仅影响两个任务表单的底部按钮视觉；如需恢复旧样式，将 `NewTaskFormPalette` 按钮色值、`NewTaskPrimaryButtonStyle` / `NewTaskSecondaryButtonStyle` 的字体/高度/圆角/背景改回，并恢复 HStack 的 `Spacer()` 与 10pt 间距即可。
  - 不涉及数据契约或持久化，回滚无数据影响。

## 2026-08-08 - Rename user-facing "预计时长" to "时长"
- 目标: 将“新建任务”“编辑任务”表单中的字段标签与占位符从“预计时长”改为“时长”；并统一检查所有用户可见文案中的“预计时长”，全部替换为“时长”。
- 非目标: 不改底层模型/字段名（`estimatedMinutes` 等内部命名保留）、不改 Notion API 字段映射、不改测试数据中的字段名 mock、不动 Package.swift/.xcodeproj/entitlements。
- 影响路径:
  - `WidgetToDo/Core/Services/AppLocalizer.swift`:
    - 中文：`.estimatedMinutesLabel` 改为“时长”，`.estimatedMinutesInvalid` 改为“时长需填写为大于 0 的分钟数”，`.tasksHelpStep4` 中的两处“预计时长”改为“时长”。
    - 英文：`.estimatedMinutesLabel` 改为“Duration”，`.estimatedMinutesInvalid` 改为“Duration must be a positive number of minutes”，`.tasksHelpStep4` 中的“estimated time”改为“duration”。
    - 法文：`.estimatedMinutesLabel` 改为“Durée”，`.estimatedMinutesInvalid` 改为“La durée doit être un nombre positif de minutes”，`.tasksHelpStep4` 中的“durée estimée”改为“durée”。
  - `WidgetToDo/en.lproj/Localizable.strings`: 同步更新 key 与 value（Estimated time → Duration，Enter estimated time → Enter duration，帮助文本 estimated time → duration）。
  - `WidgetToDo/fr.lproj/Localizable.strings`: 同步更新 key 与 value（Durée estimée → Durée，Saisissez la durée estimée → Saisissez la durée，帮助文本 durée estimée → durée）。
- 状态: 已完成代码修改与核心构建验证。
- 最近验证:
  - `rg -n "预计时长" WidgetToDo/WidgetToDo`: 通过，确认应用源码中已无用户可见的“预计时长”。
  - `swift build`: 通过，核心模块构建成功。
  - `swift test`: 阻塞，当前环境 active developer directory 为 `/Library/Developer/CommandLineTools`，缺少 XCTest；本次改动纯文案，已通过源码审查与核心构建验证。
  - UI 手测: 建议在 Xcode 运行后确认“新建任务”“编辑任务”表单标签与占位符显示为“时长”，帮助文案同步更新。
- 风险/回滚点:
  - 仅影响用户可见中文文案与未使用的 Localizable.strings key；底层 `estimatedMinutes` 映射、测试、Notion API 契约均不变。
  - 回滚: 将 AppLocalizer.swift 与两个 Localizable.strings 中的上述字符串改回即可。

## 2026-08-07 - Pomodoro completion alarm-style chime
- 目标: 将番茄钟倒计时完成时的提示音从单声系统 beep 改为真实闹钟音效，让用户在一般环境噪音下能清晰听到。
- 非目标: 不改番茄钟业务逻辑、不改其他 UI/弹框、不动 Notion API/缓存/Keychain/设置持久化、不动 Package.swift/.xcodeproj/entitlements。
- 影响路径:
  - 新增 `WidgetToDo/freesound_community-house_alarm-clock_loud-92419.mp3`（freesound 下载的真实闹钟音效，约 4.46s）。
  - `WidgetToDo/TodoListViewModel.swift`：`finishPomodoroRound()` 中的 `NSSound.beep()` 替换为新增的私有 helper `playPomodoroCompletionChime()`；helper 用 `Bundle.main.url(forResource:withExtension:)` 加载 mp3，再用 `NSSound(contentsOf:byReference:)` 播放一次；加载失败回退 `NSSound.beep()`。
- 状态: 已完成代码改动与构建验证；UI/听觉手测待用户在 Xcode 运行 App 后确认。
- 设计要点:
  - 工程使用 `PBXFileSystemSynchronizedRootGroup`（Xcode 15+ 特性），`WidgetToDo/` 文件夹内所有文件自动同步进 app bundle，无需修改 .xcodeproj。
  - mp3 已验证打包进 `WidgetToDo.app/Contents/Resources/freesound_community-house_alarm-clock_loud-92419.mp3`。
  - 音频时长约 4.46s，已包含完整闹钟铃响节奏，无需循环重复。
  - `NSSound(contentsOf:)` 加载 bundle 内 mp3；失败回退到 `NSSound.beep()`，保证兼容性。
- 最近验证:
  - 构建: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoPomodoroAlarmMp3DerivedData build` — `** BUILD SUCCEEDED **`。
  - 资源打包: `ls /private/tmp/WidgetToDoPomodoroAlarmMp3DerivedData/Build/Products/Debug/WidgetToDo.app/Contents/Resources/ | grep freesound` — 确认 `freesound_community-house_alarm-clock_loud-92419.mp3` 已在 app bundle 内。
  - 音频属性: `afinfo ... mp3` — 4.464s, 2ch, 24000 Hz, 160kbps mp3。
  - 标准入口 `swift test` 仍阻塞于 `sandbox-exec: sandbox_apply: Operation not permitted`，与既有环境问题一致；本轮使用 `--disable-sandbox` + `DEVELOPER_DIR`。
  - 听觉手测: 待用户在 Xcode 运行新构建 App 后触发番茄钟自然结束路径，确认真实闹钟音效播放；本机无法自动验证声音。
- 风险/回滚点:
  - `NSSound(contentsOf:)` 对 mp3 的支持在 macOS 上稳定；若极特殊环境加载失败会回退到 beep，不会静音。
  - mp3 文件名较长且含特殊字符（连字符、下划线），`Bundle.main.url(forResource:withExtension:)` 按完整文件名匹配，已验证可正确解析。
  - 回滚: 将 `finishPomodoroRound()` 中的 `playPomodoroCompletionChime()` 改回 `NSSound.beep()`，删除 helper 与 mp3 文件即可（mp3 删除属 L3，需人工确认）。

## 2026-08-06 - Remove priority badges from task list rows
- 目标: 在产品代码的任务列表行中移除「高/中/低」优先级标签的显示；保留 `TaskItem`/`PendingTaskItem` 的 `priority` 字段、新建任务时的优先级选择以及按优先级排序逻辑，避免影响数据契约与后台行为。
- 非目标: 不修改 Notion API 字段映射、不删除模型属性、不改排序规则、不动新建/编辑任务表单、不动番茄钟/日记/设置/窗口/工程配置。
- 影响路径:
  - `WidgetToDo/ContentView.swift`：移除 `taskRowView(_:)` 中的 `if let priority = task.priority` 优先级胶囊；删除 `FloatingWidgetPalette` 中不再使用的 `priorityBg` 与 `priorityText`。
  - `WidgetToDo/PendingTodoRowView.swift`：移除 `PendingTodoRowView` 中的优先级胶囊；删除 `PendingPalette` 中不再使用的 `priorityBg` 与 `priorityText`；将分隔符 `·` 的显示条件从 `priority != nil || estimatedMinutes != nil` 简化为 `estimatedMinutes != nil`。
- 状态: 已完成代码修改与 app target 构建验证；UI 手测待用户在 Xcode 运行 App 后确认。
- 最近验证:
  - `git diff --check -- WidgetToDo/ContentView.swift WidgetToDo/PendingTodoRowView.swift progress.md`: 通过，无空白格式问题。
  - `rg -n "priorityBg|priorityText|if let priority = task.priority|if let priority = item.priority|item.priority != nil" WidgetToDo/ContentView.swift WidgetToDo/PendingTodoRowView.swift`: 通过，确认两处任务列表均已无优先级标签相关代码。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - `swift test`: 阻塞，当前环境 active developer directory 为 `/Library/Developer/CommandLineTools`，直接运行触发 `sandbox-exec: sandbox_apply: Operation not permitted`；本次改动纯 UI 层，已通过 app target 构建验证。
  - UI 手测: 本轮未启动 App 做肉眼确认；任务列表中的优先级胶囊移除效果已通过源码审查与 app target 构建验证。建议在 Xcode 运行后核对主任务列表与 pending/mini 胶囊列表均不再显示优先级标签。
- 风险/回滚点:
  - 模型与排序逻辑未动，移除的只是显示层；如需恢复优先级标签显示，将删除的代码块与调色板常量加回即可。
  - 本次改动不影响 Notion 数据、缓存、Keychain 或设置持久化。

## 2026-08-05 - Pomodoro start-dialog reference layout
- 目标: 依据用户提供的启动专注弹框参考，重排原型中的「开始一轮专注」弹框；保留现有产品的暖白、中性操作色和成功绿，不照搬参考图的蓝色。
- 影响路径:
  - `docs/superpowers/prototypes/Pomodoro Task Flow Explorations.html`：启动弹框重组为任务信息 → 「本轮时长」三等分选择（25 分钟、45 分钟、自定义）→ 仅在选择自定义后展开的分钟输入 → 左文案/右开关的自动完成设置 → 并列取消与开始按钮 → 底部同步说明。自定义仍限制为 1–480 分钟整数，且结束和再来一轮的文案/计时同步所选时长。
  - `design-qa.md`：补充本轮参考图和应检查的开始弹框状态。
  - `progress.md`：记录本轮修改与验证。
- 状态: 已完成独立 HTML 原型的启动弹框布局重排；未进入 Swift/App/Notion 实现。浏览器视觉 QA 仍因本地 `file://` 策略受阻，待用户在已打开的原型中肉眼确认。
- 最近验证:
  - 启动弹框静态契约检查 — 通过：存在三个等宽时长选项、自定义触发器与条件输入行、自动完成的标题/提示/开关结构。
  - 内联交互脚本解析 — 通过（`new Function(...)`）。
  - `git diff --check` — 通过，无空白错误。
- 风险/回滚点: 仅调整独立 HTML 原型及 QA/进度文档；不接入 App target、Notion、设置、Keychain 或 SQLite。恢复该 HTML 的上一版本即可回退弹框布局。

### 2026-08-05 后续微调 — 自定义时长输入
- 根据用户截图，移除了自定义输入行中会在窄宽度下折行的「输入分钟数」前缀。当前为整行可输入的 `输入分钟数（1–480）` 占位提示，右侧固定「分钟」单位并用细分隔线区分；点选「自定义」后不再立即显示错误，只有输入非整数或越界值时才提示。
- 验证: `rg` 精确检查确认单位、占位提示、占位样式与错误提示分支均存在；内联交互脚本通过 `new Function(...)` 解析；`git diff --check` 通过。浏览器视觉 QA 继续受本地 `file://` 策略阻塞。

### 2026-08-05 后续微调 — 进行中番茄卡与手动完成
- 进行中卡调整为「左侧大倒计时圆环 + 右侧任务信息 + 右侧底部横排放弃 / 暂停 / 完成」布局。完成采用现有成功绿色而非参考图蓝色。
- 完成按钮进入确认弹框；确认后停止本轮、隐藏置顶计时卡并标记任务完成。倒计时结束且启动时已选择自动完成的路径同样会收起置顶计时卡。
- 验证: `rg` 精确检查确认卡片网格、完成按钮、完成确认弹框与收尾状态函数存在；内联交互脚本通过 `new Function(...)` 解析；`git diff --check` 通过。浏览器视觉 QA 继续受本地 `file://` 策略阻塞。

### 2026-08-05 后续微调 — 完成语义与确认弹框
- 明确 v1 边界：番茄时长只用于倒计时，不写入任务的预计时长或任何“实际专注时长”字段；完成任务的唯一数据动作是把 Notion 现有完成勾选设为已完成。
- 手动完成弹框移除自动完成开关和“剩余时间不会计入番茄”表述，收敛为「完成任务？」→「结束本轮，并在 Notion 中将任务设为已完成。」→「继续专注 / 完成任务」。启动弹框中的开关改名为「倒计时结束时，自动完成任务」且默认关闭；开发计划同步写入此数据边界。
- 验证: 静态检查确认旧的「标记完成」、休息和再来一轮文案/入口已移除；新的完成语义、默认关闭开关和结束提示存在；内联交互脚本通过 `new Function(...)` 解析；`git diff --check` 通过。浏览器视觉 QA 继续受本地 `file://` 策略阻塞。

## 2026-08-03 - Pomodoro × Task reference-layout revision
- 目标: 依据用户提供的“进行中任务卡”与“番茄结束弹窗”两张视觉参考，将番茄钟探索稿收敛为任务列表内的条件性置顶专注卡：默认不显示，只有用户确认开始专注后才出现；用户在倒计时期间仍能持续看到并选择完整任务列表。继续保持仅在启动时勾选才自动完成任务的规则。
- 影响路径:
  - `docs/superpowers/prototypes/Pomodoro Task Flow Explorations.html`：重做为“日期导航 →（已开始时才出现的）置顶进行中卡 → 多条任务列表”的同页结构；点击任务先出现开始确认，再显示计时卡。开始弹窗支持 25 分钟、45 分钟和 1–480 分钟的自定义整数输入；确认后计时卡与开始按钮文字同步为所选时长。暂停与放弃均进入居中确认浮层；结束、暂停、放弃均保留任务状态后果说明。颜色/边框/圆角切换为当前 `FloatingWidgetPalette` 的暖白与低饱和中性视觉语言，而非照搬参考图配色。
  - `design-qa.md`：记录参考图与原型的视觉 QA 阻塞状态。
  - `progress.md`：记录本次原型更新和验证。
- 状态: 已完成条件性任务列表置顶专注卡与暂停/放弃确认交互的原型修正；浏览器视觉 QA 被本地 `file://` URL 策略阻塞，待用户在已打开的原型中肉眼确认后再迭代。未进入 Swift/App/Notion 实现。
- 最近验证:
  - `git diff --check` — 通过，无空白错误。
  - 时长控件 RED/GREEN — 先确认 HTML 中缺少 `25` / `45` / `custom-duration` 控件；加入后静态契约检查通过。自定义时长限制为 1–480 分钟整数。
  - 内联交互脚本解析 — 通过（`new Function(...)`）；默认隐藏计时卡、多任务开始确认、预设/自定义时长、置顶任务更新、暂停确认/继续、放弃二次确认、自动/手动完成分支、再来一个、休息与 Esc 关闭均存在对应事件处理。
  - 视觉 QA — 阻塞，详见 `design-qa.md`：Playwright 缺少 Chromium，应用内浏览器的 URL 策略禁止代理读取本地原型；未绕过限制。
- 风险/回滚点: 仅变更独立 HTML 原型及其 QA/进度文档，不接入 App target、Notion、设置、Keychain 或 SQLite。恢复该 HTML 到上一版本即可回到三方案探索板。

## 2026-08-02 - Pomodoro × Task interaction exploration
- 目标: 在不改动 App/Notion 运行逻辑的前提下，探索「启动番茄钟时明确勾选，结束后才自动完成所选任务」的桌面组件交互。
- 状态: 已交付 3 个可点击的 HTML 探索方案，待用户选择或组合方向后再写正式设计规格；尚未进入 Swift 实现。
- 产物: `docs/superpowers/prototypes/Pomodoro Task Flow Explorations.html`。包含 A 行内启动、B 专注启动卡、C 胶囊优先；B + C 的组合为当前推荐方向。
- 最近验证:
  - `git diff --check` — 通过，无空白错误。
  - 静态交互入口检查（`rg`）— 确认方案切换、A/B 启动与 B/C 完成本轮的事件入口均存在。
  - 浏览器预览: 阻塞。当前环境的 Playwright 缺少 Chromium；应用内浏览器的 URL 安全策略禁止打开本地 `file://` 原型，未绕过该策略。需用户通过本地文件链接打开后进行肉眼与点击体验。
- 风险/回滚点: 该产物仅为独立原型，不接入 App target、Notion、设置、Keychain 或 SQLite；删除该 HTML 即可完全移除探索稿（本轮未执行删除）。

## 2026-07-25 - Full application localization audit
- 目标: 将所有应用自有的可见文字、操作、状态、校验提示与 Toast 切换为简体中文、英语、法语；固定保留 `Language` 与三种语言原生名称，不翻译用户/Notion 原始内容。
- 状态: 进行中。已建立完整实施计划并完成第一批迁移：扩充三语目录；任务/日记的运行时错误、状态横幅与 Toast 改为延迟 `AppMessage` 渲染；待办/日记操作、加载与同步状态、表单、新手引导、欢迎页、迷你胶囊、原生 Settings 场景和 AppKit 启动提示已从 `LanguageStore` 读取。日记标题日期现明确将当前 `languageStore.language` 传给共享日期格式化器，避免英语/法语回退为默认中文。Core 配置与字段校验已改为返回语言无关的消息键；待处理 Notion 客户端的应用包装错误，以及最终全仓硬编码审计和三语言 UI 回测。
- 最近验证:
  - RED（2026-07-25）: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter AppMessageLocalizationTests` — 如预期失败，缺少 `.taskUpdateFailed` 键。
  - GREEN（2026-07-25）: 同一命令通过，`Executed 4 tests, with 0 failures`；验证应用生成的错误包装随语言切换而原始 HTTP 详情保持不变。
  - 目录完整性（2026-07-25）: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter AppLanguageTests` — 通过，`Executed 2 tests, with 0 failures`；三语目录包含全部键，`Language` 与语言选项名称不变。
  - Debug 构建（2026-07-25）: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build` — 两次局部迁移后均通过，`** BUILD SUCCEEDED **`。
  - 配置校验（2026-07-25）: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter 'ConfigurationInputNormalizerTests|FieldMappingResolutionTests'` — 通过，`Executed 11 tests, with 0 failures`；验证配置校验返回消息键与原始参数，而非硬编码中文。
  - Debug 构建（2026-07-25，配置校验迁移后）: 同一 `xcodebuild` 命令通过，`** BUILD SUCCEEDED **`。
  - 日记日期 RED/GREEN（2026-07-25）: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run NotionFloatCoreSmokeTests` 先按预期失败（缺少 `language: languageStore.language`），传入当前语言后通过，`All smoke tests passed.`；同时将既有 smoke 中已过时的中文硬编码断言迁移为语言键断言。
  - 迷你胶囊英文标题（2026-07-25）: `WidgetToDo/MiniCapsuleViews.swift` 为共享标题添加单行、缩放与布局优先级约束，覆盖 `Today's tasks` / `Today's journal`；精确源码检查先红后绿。`swift test --disable-sandbox` 通过（46 tests），Debug 构建通过；桌面迷你模式英文肉眼回测待在安全运行实例中完成。
  - 全量测试（2026-07-25）: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` — 通过，`Executed 46 tests, with 0 failures`。
  - Debug 构建（2026-07-25，日记日期修复后）: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build` — 通过，`** BUILD SUCCEEDED **`。
- 风险/回滚点: 当前批次只变更应用端显示文案与内存消息类型；不改 Notion API、字段名、令牌/缓存数据。可分别回退提交 `068e53e` 与 `3fd2a57`；最终完成前仍需全量测试、smoke 与三语言安全 UI 回测。

## 2026-07-24 - Onboarding language selector
- 目标: 在首次初始化页复用 Settings 已有的 `Language` 选择行，支持 `简体中文`、`English`、`Français`，选择后立即刷新并保持原有独立持久化行为；语言行位于“连接 Notion”说明之后、`Notion 令牌` 之前，并移除初始化页和设置页共用的上下箭头图标。
- 非目标: 不新增语言选项或持久化结构；不修改 Notion 配置校验、Token/Keychain、缓存、API、`Package.swift`、Xcode 工程或 entitlements。
- 影响路径:
  - `WidgetToDo/ContentView.swift`：初始化页传入既有 `RootViewModel.selectLanguage` 回调，并在 Notion 连接说明之后、`Notion 令牌` 之前显示共享 `languageSection`；移除该共享行的 `chevron.up.chevron.down` 图标，设置页同步生效。
  - `Tests/NotionFloatCoreSmokeTests/main.swift`：新增初始化页的回调接线与布局顺序 smoke 回归检查。
  - `progress.md`：记录本次验证。
- 状态: 已完成代码与自动化验证；桌面 UI 手测受安全限制阻塞。
- 验证:
  - RED: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` — 如预期失败：`onboarding should persist language selection through RootViewModel`。
  - GREEN: 同一 smoke 命令在接线后通过，输出 `All smoke tests passed.`。
  - 布局 RED/GREEN（2026-07-25）: 精确源码检查先确认语言行不在 `Notion 令牌` 正上方；调整后确认 `onboardingHero → languageSection → tokenSection` 顺序成立。
  - 箭头 RED/GREEN（2026-07-25）: 精确源码检查先确认共享语言行仍包含 `chevron.up.chevron.down`；移除后确认该图标不再出现在 `ContentView.swift`。
  - 全量测试（2026-07-25）: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` — 通过，`Executed 43 tests, with 0 failures`。
  - Debug 构建（2026-07-25）: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build` — 通过，`** BUILD SUCCEEDED **`。
  - Smoke 运行现状（2026-07-25）: `swift run NotionFloatCoreSmokeTests --disable-sandbox` 在本次布局断言前停止于既有 `journal database help should explain the required fields and page-body storage`；该断言仍匹配本地化前的中文原文，和本次布局修改无关，未在本次任务内改动。
  - UI 手测: 未执行。当前安装实例可能使用真实 Notion Token 与配置；进入首次初始化状态需要清除 Keychain/设置，属于未获授权的破坏性操作。需在用户的安全测试配置或 Xcode 临时环境中验证三种语言切换与重启恢复。
- 风险/回滚点: 仅调整共享语言行在首次配置页的垂直顺序，可能压缩令牌区的首屏空间；滚回 `ContentView.swift` 的布局顺序，以及 smoke 断言即可恢复原行为，不影响已保存语言或 Notion 数据。

## 2026-07-24 - Complete localization remediation
- 目标: 补齐全部应用界面中文、英语与法语文案；固定保留 `Language` 和三种语言选项名称。
- 状态: 进行中。已补齐设置说明、重置配置和三张帮助弹窗的英语/法语资源，并新增延迟本地化消息基础；帮助弹窗、待办/日记 tab、钥匙串提示、日期标题、待办空状态、日记状态与同步横幅已改为从当前语言状态读取文案。待迁移待办、日记、表单与动态状态文案。
- 验证: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` 通过（45 tests）；`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build` 通过；已实际运行 Debug App，英文状态显示 `Tasks / Journal`、`Jul 25`、`No tasks today` 与 `Just synced`。
- 风险/回滚点: 当前批次只改变本地化资源与消息目录，不接触 Notion、Keychain 或缓存；可回退本批提交。

## 2026-07-24 - Database help copy
- 目标: 更新 Tasks 与 Journal Database 配置说明，明确必填字段、日记正文存储方式与推荐画廊视图；同步 smoke 覆盖。
- 状态: 已完成代码修改与自动化验证。
- 验证: `swift test --disable-sandbox` 通过（41 tests）。
- 风险/回滚点: 仅影响配置帮助文案与对应 smoke 断言；回退 `ContentView.swift` 和 smoke 测试即可。

## 2026-07-24 - Language setting
- 目标: Settings 顶部新增固定标题 `Language`，支持 `简体中文`、`English`、`Français`；默认简体中文，选择后立即刷新并独立持久化。
- 状态: 已完成代码与自动化验证；桌面 UI 手测待完成。
- 验证: `swift run NotionFloatCoreSmokeTests --disable-sandbox` 通过；`swift test --disable-sandbox` 通过（41 tests）；`xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build` 通过。
- 风险/回滚点: 需在真实 app 中确认三语资源的静态文案渲染、菜单栏刷新和重启恢复；回退语言模型、偏好文件、`LanguageStore`、资源与设置行不会触及 Token、数据库或 SQLite 缓存。

## 2026-07-12 - Fix journal save failure with duplicate same-day cache records
- 目标: 修复日记编辑后显示“保存失败”的两条已确认路径：同一天多个日记缓存记录导致 ID 不匹配，以及输入发生在网络写入期间时防抖取消整个保存任务；失败时在底部显示具体可读原因。
- 非目标: 不删除或合并用户 Notion 中既有日记页；不修改 Notion API 契约、数据库字段映射、令牌/设置存储、SQLite 表结构或工程配置。
- 影响路径:
  - `WidgetToDo/Core/Infrastructure/SQLiteCache.swift`（新增按日记 page ID 精确读取缓存的方法）
  - `WidgetToDo/Core/Infrastructure/NotionRepository.swift`（日记保存改为按当前 page ID 获取缓存）
  - `WidgetToDo/JournalViewModel.swift`（分离防抖等待与串行网络保存；显示具体失败消息）
  - `Tests/NotionFloatCoreTests/NotionRepositoryTaskMutationTests.swift`（同日重复记录保存回归测试）
  - `Tests/NotionFloatCoreSmokeTests/main.swift`（自动保存不取消进行中写入的约束）
  - `progress.md`
- 状态: 已完成代码修改与自动化验证；真实 Notion UI 回测待用户完成。
- 根因与修复:
  - 原保存逻辑按日期使用无排序 `LIMIT 1` 读取日记缓存，再比较 page ID；同日存在多个缓存页时会取到另一页并抛出“日记缓存记录不存在”。现改为直接按当前 `entryID` 查询，消除日期歧义。
  - 原防抖任务在每次输入时被取消；一旦其中已进入 Notion 网络写入，URLSession 也会收到取消并产生 `NSURLError -999`。现将 `debounceTask` 与 `saveTask` 分离，输入只替换待保存的最新文本；已开始的保存继续完成，后续内容由同一保存队列跟进。
  - 保存异常的底部状态改为显示 `日记保存失败：<具体原因>`，不再只显示“保存失败”。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter NotionRepositoryTaskMutationTests/testSaveJournalUsesEntryIDWhenSameDayHasMultipleCachedEntries`: 先红，原实现抛出 `日记缓存记录不存在。`；修复后通过。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests`: 先红，新增约束确认旧实现未分离防抖与保存任务；修复后越过本次新增约束，但最终仍停在仓库既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox`: 通过，`Executed 36 tests, with 0 failures`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - UI 手测: 未执行。为避免在真实个人 Notion 日记中写入测试文本，未对当前连接的 App 直接输入/保存；需用户在新构建运行后验证正常输入、连续输入超过 2 秒后继续输入、以及“重试”按钮。
- 风险/回滚点:
  - 同日重复的 Notion 页面不会被本次代码删除；应用会稳定保存当前已加载页面，但远端仍可能保留重复页。若需清理，应先由用户决定保留哪一页，再单独处理。
  - 若需回滚，恢复 `JournalViewModel.swift` 的单一 autosave task、`NotionRepository.saveJournal` 的按日期读取，以及移除 `SQLiteCache.journalEntry(id:)` 与两条回归测试；随后重跑上述测试与构建命令。

## 2026-07-12 - Thicken mini progress ring stroke
- 目标: 增大悬浮窗迷你模式圆形进度条圆环的描边宽度，使视觉上线条更粗壮明显。
- 非目标: 不改变进度条动画逻辑、颜色、数据绑定；不改动窗口管理、Notion/API/缓存/Keychain/设置持久化契约；不动工程配置或其他视图组件。
- 影响路径:
  - `WidgetToDo/MiniCapsuleViews.swift`（`MiniProgressRing` 的 `lineWidth` 与 `ringSize`）
  - `progress.md`
- 状态: 已完成代码修改。
- 修改详情:
  - `lineWidth`: `2.5` → `4.5`
  - `ringSize`: `32` → `36`
  - 同步放大整体尺寸，保持内圆与外形比例协调，描边端点仍使用 `.round`。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox`: 通过，`Executed 35 tests, with 0 failures`。
  - `swift test`: 阻塞，默认工具链触发 `sandbox-exec: sandbox_apply: Operation not permitted`。
  - UI 手测: 当前环境无法启动 app 做肉眼确认；需在 Xcode 运行或用户机器上核对进度环粗细与胶囊整体比例。
- 风险/回滚点: 风险低，仅影响迷你进度环视觉；如需恢复细环，将 `lineWidth` 与 `ringSize` 改回 `2.5` / `32` 即可。

## 2026-07-12 - Fix Xcode preview crash "WidgetToDo may have crashed"
- 目标: 修复 Xcode Canvas 预览 `ContentView.swift` 时出现的 "Cannot preview in this file / WidgetToDo may have crashed" 错误，使各状态预览能正常渲染。
- 非目标: 不改动业务逻辑、不修改窗口管理、不改动 Notion/API/缓存/Keychain/设置持久化契约。
- 影响路径:
  - `WidgetToDo/NewTaskViewModel.swift`（移除 `@AppStorage`，改为直接读写 `UserDefaults.standard`）
  - `progress.md`
- 状态: 已完成代码修改与构建/单测验证；预览需在 Xcode 中由用户重新触发确认。
- 根因: `NewTaskViewModel` 在 `ObservableObject` 中使用了 `@AppStorage("lastFailedDraft")`。在 SwiftUI Preview 进程里，`AppStorage` 的 KVO/发布机制与 `ObservableObject.objectWillChange` 交互会导致 `UserDefaultObserver.observeDefaults` 崩溃（诊断报告中为 `EXC_BAD_ACCESS`/`SIGBUS`，栈顶涉及 `StringProtocol.trimmingCharacters(in:)` 与 `AppStorage.objectWillChange.setter`）。该 ViewModel 在 `RootViewModel` 初始化时即被创建，因此所有包含 `ContentView` 的预览都会触发崩溃。
- 修复: 将 `@AppStorage("lastFailedDraft")` 替换为普通的 `UserDefaults.standard` 读写计算属性。`lastFailedDraftData` 仅用于失败草稿的本地缓存，不需要向 SwiftUI 发布变更，直接读写更安全，也避开了 Preview 对 `AppStorage` 的约束。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox`: 通过，`Executed 35 tests, with 0 failures`。
  - UI 手测: 无法在当前环境直接渲染 Xcode Canvas；已按崩溃日志定位并修复，需在用户 Xcode 中重新打开 `ContentView.swift` 的 Preview 验证。
- 风险/回滚点: 风险低，仅影响新建任务失败草稿的本地缓存读写方式；行为与原来一致。如需回滚，可恢复 `@AppStorage` 属性包装并删除手动 `UserDefaults` 计算属性。

## 2026-07-12 - Floating window mini-mode v1.0
- 目标: 实现 WidgetToDo 悬浮窗迷你模式：支持完整窗口与 220×56pt 胶囊形态切换、待办进度环与日记状态胶囊、窗口位置与当前 tab 持久化、启动恢复；保持现有待办/日记数据流与窗口管理基础不变。
- 非目标: 不新增独立的悬浮窗进程、不改 Notion API 契约、不改 Keychain/缓存/设置持久化的底层格式、不动用 `Package.swift`/`.xcodeproj`/entitlements、不改待办/日记的业务逻辑。
- 影响路径:
  - `WidgetToDo/Core/Models/MiniModeState.swift`（新增）
  - `WidgetToDo/Core/Services/MiniModeLayoutEngine.swift`（新增）
  - `WidgetToDo/MiniCapsuleViews.swift`（新增）
  - `WidgetToDo/Core/Models/AppSettings.swift`（新增 `miniModeState` 字段）
  - `WidgetToDo/Core/Infrastructure/NotionRepository.swift`（新增读写方法）
  - `WidgetToDo/FloatingWindowManager.swift`（collapse/expand/初始状态/持久化 frame）
  - `WidgetToDo/ContentView.swift`（RootViewModel 状态管理与视图切换）
  - `WidgetToDo/AppCoordinator.swift`（启动恢复）
  - `Tests/NotionFloatCoreTests/MiniModeStateTests.swift`（新增）
  - `Tests/NotionFloatCoreTests/MiniModeLayoutEngineTests.swift`（新增）
  - `progress.md`
- 状态: 已完成代码实现与自动化验证；修复了 `MiniModeLayoutEngine.frameConstrained` 原实现仅保证最小可见区域、未在窗口能完整放入屏幕时完全收纳的问题；未做桌面 UI 手测。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox`: 通过，`Executed 35 tests, with 0 failures`。
  - `swift test`: 阻塞，当前环境默认工具链触发 `sandbox-exec: sandbox_apply: Operation not permitted`。
  - UI 手测: 本轮未启动 App 做肉眼确认；需在完整 app runtime / Xcode 中验证展开/收起动画、胶囊显示、tab 切换与位置恢复。
- 风险/回滚点:
  - 窗口状态写入 `AppSettings` 同一 JSON；旧配置无 `miniModeState` 时会解码为 `.default`，不会崩溃。若持久化异常可删除 `~/Library/Application Support/WidgetToDo/settings.json` 回退到欢迎流程。
  - `RootViewModel` 与 `FloatingWindowManager` 通过 `weak var` 协作，状态变更已用 `@MainActor` 包裹；但仍需手测确认动画期间 frame 同步无漂移。
  - 回滚代码可还原上述 3 个新增文件与 5 个修改文件至上一次 `git commit` 基线。

## 2026-07-11 - New task modal title centered without icon
- 目标: 调整“新建任务”弹框标题：移除标题左侧的 `+` 图标，并将标题居中显示；字体大小和样式保持与“编辑任务”弹框标题一致。
- 非目标: 不修改弹框尺寸、内边距、任务/日期/预计时长输入区、按钮样式与位置、阴影/背景视觉；不动编辑任务弹框或其他模块。
- 影响路径:
  - `WidgetToDo/NewTaskFormCard.swift`（标题由带图标的 `HStack` 改为居中的 `Text`，并移除不再使用的 `NewTaskFormTrackingModifier`）
  - `WidgetToDo/progress.md`
- 状态: 已完成代码修改。新建任务弹框标题现在与编辑任务弹框标题使用完全相同的字体 `.system(size: 14, weight: .semibold)` 和前景色，并水平居中。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - `swift test`: 阻塞，当前环境 active developer directory 为 `/Library/Developer/CommandLineTools`，编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - UI 手测: 本轮未启动 App 做肉眼确认；标题居中与图标移除效果已通过源码审查与 app target 构建验证。建议在 Xcode 运行后或用户机器上手动核对新建任务弹框标题布局。
- 风险/回滚点: 风险低，仅影响新建任务弹框标题视觉；如需恢复左侧 `+` 图标，可将标题改回带 `Image(systemName: "plus")` 的 `HStack` 并重新添加 `NewTaskFormTrackingModifier`。

## 2026-07-11 - Edit task modal estimated duration + button alignment
- 目标: 调整“编辑任务”弹框：新增可选“预计时长”输入框；将底部“取消”“保存”按钮的样式与位置保持与“新建任务”弹框一致。
- 非目标: 不修改弹框尺寸、标题/任务名称输入框样式、阴影/背景视觉、窗口管理；不改动 Notion/API/缓存/Keychain/设置持久化契约；不动任务完成状态切换、删除或其他模块。
- 影响路径:
  - `WidgetToDo/ContentView.swift` (`EditTaskFormCard` 新增“预计时长”输入区，按钮改用 `NewTaskPrimaryButtonStyle` / `NewTaskSecondaryButtonStyle` 并右对齐)
  - `WidgetToDo/NewTaskFormCard.swift` (抽出/复用 `NewTaskPrimaryButtonStyle` / `NewTaskSecondaryButtonStyle` 供编辑弹框共享)
  - `WidgetToDo/TodoListViewModel.swift` (新增 `editingEstimatedMinutesText`、`editingEstimatedMinutesError`、`parseEditingEstimatedMinutes()` 与 `saveTaskEdit()` 校验/解析逻辑)
  - `WidgetToDo/Core/Infrastructure/NotionRepository.swift` (`updateTaskTitle(id:title:estimatedMinutes:)` 支持写入预计时长并合并响应)
  - `WidgetToDo/Core/Infrastructure/NotionClient.swift` (`updateTaskTitle(pageID:title:estimatedMinutes:fields:token:)` PATCH 请求体包含预计时长字段)
  - `Tests/NotionFloatCoreTests/NotionRepositoryTaskMutationTests.swift` (新增/更新预计时长相关断言)
  - `Tests/NotionFloatCoreTests/TaskDateSelectionTests.swift` (同步日期标题断言)
  - `progress.md`
- 状态: 已完成代码修改。编辑任务弹框现在包含与新建任务弹框一致的“预计时长”输入（选填，单位分钟，仅接受正整数），取消/保存按钮复用新建任务弹框同款主次按钮样式并右对齐。
- 最近验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`: 通过，`Executed 25 tests, with 0 failures`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`: 通过，`Build complete!`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run NotionFloatCoreSmokeTests`: 构建成功；运行结果仍停在仓库既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - UI 手测: 本轮未启动 App 做肉眼确认；输入框与按钮一致性已通过源码审查与 app target 构建验证。建议在 Xcode 运行后或用户机器上手动核对弹框布局与输入交互。
- 风险/回滚点: 风险低，仅影响编辑任务弹框 UI 与保存预计时长的数据流；如需恢复旧按钮样式，可将 `EditTaskFormCard` 底部 `Button` 的 `.buttonStyle` 改回原实现。如需移除预计时长字段，回退 ViewModel、Repository、Client 与相关测试即可。

## 2026-07-11 - Compact jump-to-today spacing
- 目标: 减小待办工具栏中“回到今天”按钮与右侧日期导航箭头之间的水平间距，消除明显留白，同时保持按钮可点击区域不拥挤。
- 非目标: 不修改日期标题宽度、箭头按钮尺寸、右侧操作按钮组间距、窗口管理、Notion/API/缓存/Keychain/设置持久化契约或工程配置。
- 影响路径:
  - `WidgetToDo/ContentView.swift` (`FloatingWidgetMetrics` 新增 `jumpToTodayLeadingPadding`；`todoToolbar` 中“回到今天”按钮 `.padding(.leading, 8)` 改为使用新常量)
  - `Tests/NotionFloatCoreSmokeTests/main.swift` (新增两条断言锁定新常量定义与使用)
  - `progress.md`
- 状态: 已完成代码修改。产品代码中“回到今天”按钮前导间距由硬编码 8pt 改为共享常量 `jumpToTodayLeadingPadding = 2pt`，并将固定宽度槽由 56pt 缩小到 44pt，消除按钮框内多余留白。
- 最近验证:
  - `swift build`: 通过，`Build complete!`。
  - `swift run NotionFloatCoreSmokeTests`: 构建成功；新增断言已越过，运行结果仍停在仓库既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - `rg -n "jumpToTodayLeadingPadding" WidgetToDo/ContentView.swift Tests/NotionFloatCoreSmokeTests/main.swift`: 通过，确认常量定义、产品代码使用、smoke test 断言均已落地。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`（active developer directory 为 `/Library/Developer/CommandLineTools`）。
  - UI 手测: 本轮未启动 App 做肉眼确认；间距调整已通过源码审查与 app target 构建验证。多屏幕尺寸/响应式效果需在 Xcode 运行后或用户机器上手动完成。
- 风险/回滚点: 风险低，仅影响待办工具栏“回到今天”按钮的水平位置；如需恢复更宽间距，将 `jumpToTodayLeadingPadding` 改回 `8` 并同步 smoke test 断言即可。

## 2026-07-11 - Brighten edit task modal and strengthen shadow
- 目标: 提升编辑任务弹框的视觉突出度：将弹框背景调至更明亮的暖白色高亮状态，并适当增大阴影，使弹框与背景页面形成清晰的视觉层级与立体感；保持弹框内部布局、输入、保存/取消功能不变。
- 非目标: 不修改弹框尺寸、内边距、标题/输入框/按钮布局与字体，不改动编辑任务的保存/校验/加载逻辑，不改动 Notion/API/缓存/Keychain/设置持久化契约，不动窗口管理或工程配置。
- 影响路径:
  - `WidgetToDo/ContentView.swift` (`EditTaskFormCard` 背景、边框、阴影修饰符)
  - `progress.md`
- 状态: 已完成代码修改。将 `EditTaskFormCard` 背景从 `.regularMaterial` 替换为实色暖白 `Color(red: 0.992, green: 0.988, blue: 0.98)`，新增 1pt 浅黑边框 `Color.black.opacity(0.08)`，阴影由 `opacity 0.15/radius 8/y 4` 增强为 `opacity 0.20/radius 20/y 10`。
- 最近验证:
  - `swift build`: 通过，`Build complete!`。
  - `swift run NotionFloatCoreSmokeTests`: 构建成功；本次改动未新增 smoke 断言，运行结果仍停在仓库既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - `rg -n "EditTaskFormCard" WidgetToDo/ContentView.swift`: 通过，确认弹框组件存在且背景/阴影已更新。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - UI 手测: 本轮未启动 App 做肉眼确认；视觉调整效果需在 Xcode 运行后或用户机器上手动验证。
- 风险/回滚点: 风险低，仅影响编辑任务弹框视觉层；如需恢复原有毛玻璃效果，可将背景改回 `.regularMaterial` 并恢复阴影 `Color.black.opacity(0.15)`、`radius: 8`、`y: 4`。

## 2026-07-11 - Remove edit task modal gray backdrop
- 目标: 移除待办面板中编辑任务弹框后方的灰色半透明背景层（`Color.black.opacity(0.3)`），使弹框打开时页面其他元素保持可交互；保留编辑表单本身的显示层级、输入/保存/取消交互。
- 非目标: 不修改新建任务表单的透明点击关闭遮罩，不修改编辑表单的卡片样式、阴影、尺寸与保存逻辑，不改动 Notion/API/缓存/Keychain/设置持久化契约，不动窗口管理或工程配置。
- 影响路径:
  - `WidgetToDo/ContentView.swift` (`todoPanel` 中 `if todoViewModel.editingTask != nil` 分支)
  - `progress.md`
- 状态: 已完成代码修改。已删除编辑任务分支中的 `Color.black.opacity(0.3)` 及其 `onTapGesture` 点击关闭手势，仅保留 `EditTaskFormCard(viewModel: todoViewModel)`。
- 最近验证:
  - `swift build`: 通过，`Build complete!`。
  - `swift run NotionFloatCoreSmokeTests`: 构建成功；本次改动未新增 smoke 断言，运行结果仍停在仓库既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - `rg -n "Color\.black\.opacity\(0\.3\)" WidgetToDo/ContentView.swift`: 通过，确认产品代码中已不含该灰色半透明背景。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`（active developer directory 为 `/Library/Developer/CommandLineTools`）。
  - UI 手测: 本轮未启动 App 做肉眼确认；背景移除效果已通过源码审查与 app target 构建验证。多屏幕尺寸测试需在 Xcode 运行后或用户机器上手动完成。
- 风险/回滚点: 风险低，仅影响编辑任务弹框的遮罩层；如需恢复点击外部关闭行为，可在 `if todoViewModel.editingTask != nil` 分支中重新添加透明 `Rectangle()` 或 `.fullScreenCover`/`.popover` 等系统容器。

## 2026-07-11 - Completed task title gray + strikethrough
- 目标: 在待办任务列表中，对状态为"成功已完成"（`task.isDone == true`）的任务项，标题文本改为灰色（#888888）并添加贯穿线，与未完成任务形成明确视觉区分。
- 非目标: 不修改任务完成状态切换逻辑、Notion/API/缓存/Keychain/设置持久化契约，不修改窗口管理或工程配置，不动日记/欢迎弹窗等其他模块。
- 影响路径:
  - `WidgetToDo/ContentView.swift` (`FloatingWidgetPalette.taskTitleCompleted`、`taskRowView(_:)`)
  - `progress.md`
- 状态: 已完成代码修改。`taskRowView` 中任务标题根据 `task.isDone` 动态切换前景色，并附加 `.strikethrough(task.isDone)`；新增 `FloatingWidgetPalette.taskTitleCompleted = Color(red: 0.533, green: 0.533, blue: 0.533)` 以匹配 #888888。
- 最近验证:
  - `swift build`: 通过，`Build complete!`。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`（active developer directory 为 `/Library/Developer/CommandLineTools`）。
  - `swift run NotionFloatCoreSmokeTests`: 构建并运行成功；本次改动未新增 smoke 断言，运行结果仍停在仓库既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - `rg -n "taskTitleCompleted|strikethrough\(task.isDone\)|task.isDone \? FloatingWidgetPalette.taskTitleCompleted" WidgetToDo/ContentView.swift`: 通过；确认已完成任务标题使用新颜色与删除线修饰符。
  - UI 手测: 本轮未执行；视觉变化通过源码条件修饰符与 app target 构建验证。用户反馈上一轮 HTML 原型修改无效，已识别出实际可交互目标为 SwiftUI 主应用并完成对应修改。
- 风险/回滚点: 风险低，仅影响已完成任务标题显示样式；如需恢复，移除 `taskTitleCompleted` 常量并将标题前景色与删除线改回无条件原样式即可。

## 2026-07-11 - Todo date navigation arrow spacing compacted
- 目标: 缩小待办 tab 日期切换器中左右箭头与中间日期文本之间的水平间距，使整体布局更紧凑、视觉更协调；同时保持整个日期模块左对齐。
- 非目标: 不修改 Notion/API/缓存/Keychain/设置持久化契约，不修改任务加载/同步/新建逻辑，不修改窗口管理或工程配置，不动日记/欢迎弹窗等其他模块。
- 影响路径:
  - `WidgetToDo/ContentView.swift` (`FloatingWidgetMetrics`、`todoToolbar`)
  - `Tests/NotionFloatCoreSmokeTests/main.swift`
  - `progress.md`
- 状态: 已完成代码修改。日期导航组的 `HStack` 间距由写死的 `14` 改为共享常量 `FloatingWidgetMetrics.todoDateNavigationSpacing = 4`；日期标题固定宽度由 `65` 调整为 `60`，对齐方式由 `.leading` 改为 `.center`，使日期文本在左右箭头之间精确水平居中；外层 `todoToolbar` 仍使用 `HStack(spacing: 0)` 配合 `Spacer()`，日期模块整体保持左对齐。
- 最近验证:
  - `swift build`: 通过，`Build complete!`（因 sandbox 限制，使用 `dangerouslyDisableSandbox`）。
  - `swift run NotionFloatCoreSmokeTests`: 构建成功；日期标题宽度、居中对齐、导航间距三项断言均已越过，随后停在仓库既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - `rg -n "todoDateTitleWidth|todoDateNavigationSpacing|alignment: \.center" WidgetToDo/ContentView.swift Tests/NotionFloatCoreSmokeTests/main.swift`: 通过；确认日期标题宽度为 `60`、对齐为 `.center`、导航间距为 `4`，且均在 smoke test 中断言锁定。
  - UI 手测: 未启动 App 做肉眼确认；居中与紧凑效果已通过布局语义与 app target 构建验证。
- 风险/回滚点: 风险低，仅影响日期导航组内部对齐与宽度；如需恢复，将 `todoDateTitleWidth` 改回 `65`、对齐改回 `.leading`，并同步 smoke test 断言即可。

## 2026-07-11 - Task row checkbox vertical centering
- 目标: 调整待办模块任务列表中勾选框的垂直对齐方式，使其在单行/多行任务文本下均精确居中于任务行内容块，同时保持与文本的适当间距和整体 UI 风格一致。
- 非目标: 不修改 Notion/API/缓存/Keychain/设置持久化契约，不修改任务加载/同步/新建逻辑，不修改窗口管理或工程配置，不改动欢迎弹窗 HTML 原型文件。
- 影响路径:
  - `WidgetToDo/ContentView.swift` (`taskRowView(_:)` 与 `FloatingWidgetMetrics`)
  - `WidgetToDo/PendingTodoRowView.swift`
  - `progress.md`
- 状态: 已完成代码修改。任务行容器由 `alignment: .top` 改为 `alignment: .center`，并移除了勾选框顶部的手动偏移 padding（`taskRowCheckboxTopPadding` 常量已删除）。已完成和同步中的任务行均使用同一居中对齐策略。
- 最近验证:
  - `swift build`: 通过，`Build complete!`。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `swift run NotionFloatCoreSmokeTests`: 构建并运行成功；本次改动未新增 smoke 断言，运行结果仍停在仓库既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - `git diff --check -- WidgetToDo/ContentView.swift WidgetToDo/PendingTodoRowView.swift progress.md`: 通过，无空白格式问题。
  - `rg -n "alignment:\s*\.(top|center).*taskRow|taskRowCheckboxTopPadding|padding\(\.top,\s*2\)" WidgetToDo/ContentView.swift WidgetToDo/PendingTodoRowView.swift`: 通过；确认 `taskRowView` 与 `PendingTodoRowView` 已改为 `.center`，不再使用顶部偏移常量或 `.padding(.top, 2)`。
  - UI 手测: 未启动 App 做肉眼确认；垂直居中效果已通过布局语义与 app target 构建验证。
- 风险/回滚点: 风险低，仅影响任务行勾选框垂直对齐；如需要可回滚 `HStack(alignment: .center, ...)` 到 `.top` 并恢复 `taskRowCheckboxTopPadding` 常量。

## 2026-06-23 - Todo date arrows use stable spacing
- 目标: 待办 tab 日期切换时，让“今天日期”和“非今天日期”左右两个箭头的间距保持一致，并让今天/非今天日期使用完全一致的视觉字号；以非今天日期原本的 `14pt` 作为共享字号基准；今日日期标题不再显示“今天”前缀。
- 非目标: 不修改 Notion/API/缓存/Keychain/设置持久化契约，不修改任务加载/同步/新建逻辑，不修改窗口管理或工程配置。
- 影响路径:
  - `WidgetToDo/ContentView.swift`
  - `WidgetToDo/Core/Models/TodoDateDisplayFormatter.swift`
  - `Tests/NotionFloatCoreSmokeTests/main.swift`
  - `progress.md`
- 状态: 已完成代码修改与桌面 UI 手测；待办日期标题现使用固定 `65pt` 宽度槽和共享 `todoDateTitleFontSize = 14`，以非今天日期原字号作为今天/非今天的共同字号，今天/非今天都走同一个 `.font(.system(size: FloatingWidgetMetrics.todoDateTitleFontSize, weight: .bold))`。`TodoDateDisplayFormatter.title(...)` 现对今日和非今日都返回 `M月d日`，不再给今日标题加“今天”前缀；空状态 `今天没有任务` 保持不变。产品代码不再使用 `minimumScaleFactor` 缩放今天日期。上一版误加的日期文字 `.frame(height: 28)` 已移除，今天态占位仍为固定宽度 `Spacer(minLength: 0)`，避免日期筛选器上下间隔变大。
- 最近验证:
  - `swift run NotionFloatCoreSmokeTests`: 先红于新增断言 `todo date title should reserve a fixed width so today and non-today labels keep the same arrow spacing`；实现后已越过本次新增断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift run NotionFloatCoreSmokeTests`: 针对上下间隔回归先红于新增断言 `todo date title should not force a taller vertical slot`；实现后已越过本次新增断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift run NotionFloatCoreSmokeTests`: 针对今天字号回归先红于新增断言 `todo date title should use the non-today date font size as the shared baseline` / `todo date title should not scale today's text smaller than non-today dates`；实现后已越过本次新增断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift run NotionFloatCoreSmokeTests`: 针对 14pt 今天文案完整显示先红于新增断言 `todo date title should reserve enough fixed width for the 14pt today label`；实现后已越过本次新增断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift run NotionFloatCoreSmokeTests`: 针对用户指定宽度从 `90pt` 改为 `80pt`、再改为 `65pt` 均先红后越过对应 `todo date title should reserve enough fixed width for the 14pt today label` 断言；当前仍停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift run NotionFloatCoreSmokeTests`: 针对去掉今日日期标题“今天”前缀先红于 `today date title should not include the today prefix`；实现后已越过本次新增断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `rg -n "todoDateTitleWidth|todoDateTitleFontSize|minimumScaleFactor|TodoDateDisplayFormatter\\.title\\(" WidgetToDo/ContentView.swift Tests/NotionFloatCoreSmokeTests/main.swift WidgetToDo/Core/Models/TodoDateDisplayFormatter.swift`: 通过；确认日期标题使用共享 `14pt` 字号常量，产品代码不再含 `minimumScaleFactor`，固定宽度槽为 `65pt`，且标题 formatter 不再输出“今天”前缀。
  - `rg -n '今天|today date title|emptyStateTitle\\(for: today' WidgetToDo/Core/Models/TodoDateDisplayFormatter.swift Tests/NotionFloatCoreSmokeTests/main.swift`: 通过；`title(...)` 不再含今日前缀，`emptyStateTitle(...)` 仍保留 `今天没有任务`。
  - `rg -n "todoDateTitleWidth|jumpToTodayWidth|frame\\(width: FloatingWidgetMetrics\\.todoDateTitleWidth|allowsTightening\\(true\\)|frame\\(height: 28\\)|Spacer\\(minLength: 0\\)|todoDateNavigationKeepsArrowSpacingStable" WidgetToDo/ContentView.swift Tests/NotionFloatCoreSmokeTests/main.swift`: 通过；确认固定日期槽、回到今天占位、禁止固定高度的 smoke 约束均已落地，产品代码不再含 `.frame(height: 28)`。
  - `rg -n -U "Color\\.clear\\n\\s+\\.frame\\(width: FloatingWidgetMetrics\\.jumpToTodayWidth\\)" WidgetToDo/ContentView.swift Tests/NotionFloatCoreSmokeTests/main.swift`: 通过，无匹配；确认今天态占位不再使用未限高 `Color.clear`。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - UI 手测: 重启并打开 `/Users/chenxiaofeng/Library/Developer/Xcode/DerivedData/WidgetToDo-hidinztoljepfscjpdfzdzmljelp/Build/Products/Debug/WidgetToDo.app`；待办页今天态日期标题显示为 `6月23日`，已去掉“今天”前缀；空状态仍显示 `今天没有任务`。
- 风险/回滚点: 风险低，仅影响待办 tab 日期标题显示层；回滚 `todoDateTitleWidth`、`jumpToTodayWidth`、日期 `Text` frame/缩放修饰符与对应 smoke 断言即可。

## 2026-06-22 - Journal date matches todo switcher style
- 目标: 让日记 tab 日期显示的格式和字体样式与待办 tab 日期切换标题保持一致。
- 非目标: 不修改 Notion/API/缓存/Keychain/设置持久化契约，不修改日记加载/保存/同步逻辑，不调整窗口管理或工程配置。
- 影响路径:
  - `WidgetToDo/ContentView.swift`
  - `Tests/NotionFloatCoreSmokeTests/main.swift`
  - `progress.md`
- 状态: 已完成代码修改；日记日期现复用 `TodoDateDisplayFormatter.title(for:)`，字体改为待办日期同款 `14pt bold`、`FloatingWidgetPalette.todoDateTitle` 和 `TrackingModifier(value: -0.28)`。因此今天会显示为待办同款 `今天6月22日`，非今天显示为 `6月22日` 一类格式。
- 最近验证:
  - `swift run NotionFloatCoreSmokeTests`: 先红于新增断言 `journal date should reuse the todo date display formatter`；实现后已越过本次新增断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift build`: 通过，`Build complete!`。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - `rg -n "journalDateString\\(from|TodoDateDisplayFormatter\\.title\\(for: date\\)|formatter.dateFormat|FloatingWidgetPalette\\.journalDate|Text\\(journalDateString" WidgetToDo/ContentView.swift Tests/NotionFloatCoreSmokeTests/main.swift`: 通过；确认日记日期调用共享 formatter，旧独立 `dateFormat` 不再存在。
  - `git diff --check -- WidgetToDo/ContentView.swift Tests/NotionFloatCoreSmokeTests/main.swift progress.md`: 通过，无空白格式问题。
  - UI 手测: 本轮未执行；尚未在完整 app runtime 中打开日记 tab 肉眼核对与待办日期切换标题的视觉一致性。
- 风险/回滚点: 风险低，仅影响日记 tab 日期显示层；回滚 `journalDateString(from:)`、日期文本修饰符与对应 smoke 断言即可。

## 2026-06-22 - Header action icons unified SF sizing
- 目标: 重新统一待办/日记页右侧图标按钮的视觉大小，解决 `+`、刷新、打开 Notion 混用自绘路径和 SF Symbol 后看起来大小不一致的问题。
- 非目标: 不修改按钮动作、Notion/API/缓存/Keychain/设置持久化契约，不修改按钮点击区、布局间距、窗口管理或工程配置。
- 影响路径:
  - `WidgetToDo/ContentView.swift`
  - `Tests/NotionFloatCoreSmokeTests/main.swift`
  - `progress.md`
- 状态: 已完成代码修改；右侧动作图标统一改为 `Image(systemName:)` + `headerActionSystemName(for:)` 映射 helper 渲染，三枚图标共享 `headerIconSymbolSize = 16`、`.regular` 字重和 16x16 图标 frame，按钮点击区仍为 24x24。移除了已不再使用的本地 `HeaderActionSymbol` 自绘路径和 `headerIconStrokeWidth` 常量。
- 最近验证:
  - `swift run NotionFloatCoreSmokeTests`: 先红于新增断言 `header action icons should render through one shared SF Symbol mapping helper`；实现后已越过本次新增/更新断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift build`: 通过，`Build complete!`。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - UI 手测: 启动 `/Users/chenxiaofeng/Library/Developer/Xcode/DerivedData/WidgetToDo-hidinztoljepfscjpdfzdzmljelp/Build/Products/Debug/WidgetToDo.app`；待办页右侧 `+ / 刷新 / 打开` 与日记页 `刷新 / 打开` 均使用同一图标尺寸规则和同一按钮点击区。
- 风险/回滚点: 风险低，仅影响右侧头部动作按钮图标渲染方式；回滚 `headerActionIcon(systemName:)`、`headerActionSystemName(for:)` 与对应 smoke 断言即可。

## 2026-06-22 - Sync header icon standard clockwise style
- 目标: 替换前两版自绘刷新图标，改用更成熟、可识别的刷新按钮样式，避免同步按钮看起来像扭曲圆形或普通 `C`。
- 非目标: 不修改同步按钮动作、Notion/API/缓存/Keychain/设置持久化契约，不修改按钮点击区、布局间距、窗口管理或工程配置。
- 影响路径:
  - `WidgetToDo/ContentView.swift`
  - `Tests/NotionFloatCoreSmokeTests/main.swift`
  - `progress.md`
- 状态: 已完成代码修改；同步按钮从本地自绘双箭头/单弧路径切换为系统 `arrow.clockwise`，使用 `headerIconSymbolSize` 的 16x16 图标画布和 24x24 按钮点击区。`+` 与打开 Notion 仍走本地路径，避免扩大视觉改动范围。
- 最近验证:
  - `swift run NotionFloatCoreSmokeTests`: 先红于新增断言 `sync header action icon should use the standard clockwise refresh symbol inside the shared icon frame`；实现后已越过本次新增断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift build`: 通过，`Build complete!`。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - UI 手测: 启动 `/Users/chenxiaofeng/Library/Developer/Xcode/DerivedData/WidgetToDo-hidinztoljepfscjpdfzdzmljelp/Build/Products/Debug/WidgetToDo.app`；待办页和日记页右侧同步按钮均显示为标准 clockwise 刷新箭头，较前两版自绘符号更清楚。
- 风险/回滚点: 风险低，仅影响同步头部动作按钮的图标渲染方式；回滚 `headerActionIcon(systemName:)` 中的同步分支与对应 smoke 断言即可。

## 2026-06-22 - Sync header icon refresh shape
- 目标: 重新调整待办/日记页右侧同步按钮图标，让它在 16x16 小尺寸下能明确识别为刷新/同步，而不是接近闭合的圆形符号。
- 非目标: 不修改同步按钮动作、Notion/API/缓存/Keychain/设置持久化契约，不修改按钮尺寸、线宽、窗口管理或工程配置。
- 影响路径:
  - `WidgetToDo/ContentView.swift`
  - `Tests/NotionFloatCoreSmokeTests/main.swift`
  - `progress.md`
- 状态: 已完成代码修改；`HeaderActionSymbol.syncPath` 从接近闭合的双半圆改为两段开放弧线，右上/左下箭头头部改为分离的 V 形线段，保留 `headerIconStrokeWidth = 1.65`、16x16 图标画布与 24x24 点击区。
- 最近验证:
  - `swift run NotionFloatCoreSmokeTests`: 先红于新增断言 `sync header action icon should use open refresh arcs with clear arrow heads`；实现后已越过本次新增断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift build`: 通过，`Build complete!`。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - UI 手测: 启动 `/Users/chenxiaofeng/Library/Developer/Xcode/DerivedData/WidgetToDo-hidinztoljepfscjpdfzdzmljelp/Build/Products/Debug/WidgetToDo.app`；待办页和日记页右侧同步图标均显示为开放刷新箭头形态，尺寸与打开按钮仍保持一致。
- 风险/回滚点: 风险低，仅影响同步头部动作按钮的图标路径；回滚 `syncPath(in:)` 与对应 smoke 断言即可。

## 2026-06-22 - Header action icon lighter stroke
- 目标: 在保持待办/日记两个标签页右侧按钮图标线条规范统一的前提下，将过粗的 `+`、同步、打开 Notion 图标描边调细。
- 非目标: 不修改按钮动作、Notion/API/缓存/Keychain/设置持久化契约，不修改窗口管理、标签切换逻辑或工程配置。
- 影响路径:
  - `WidgetToDo/ContentView.swift`
  - `Tests/NotionFloatCoreSmokeTests/main.swift`
  - `progress.md`
- 状态: 已完成代码修改；右侧动作图标继续使用本地 `HeaderActionSymbol` 矢量路径，统一描边从 `2.2` 调细为 `headerIconStrokeWidth = 1.65`。所有相关图标共享 `lineCap: .round`、`lineJoin: .round`、16x16 图标画布与 24x24 点击区；同步/打开图标保持同一绘制规范和识别性。
- 最近验证:
  - `swift run NotionFloatCoreSmokeTests`: 先红于更新后的 `headerIconStrokeWidth = 1.65` 断言；实现后已越过本次新增/更新断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift build`: 通过，`Build complete!`。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - UI 手测: 启动 `/Users/chenxiaofeng/Library/Developer/Xcode/DerivedData/WidgetToDo-hidinztoljepfscjpdfzdzmljelp/Build/Products/Debug/WidgetToDo.app`；待办页右侧 `+ / 同步 / 打开` 与日记页 `同步 / 打开` 均显示为更轻的同一描边粗细、同一按钮命中区；已切换两个 tab 核对。
- 风险/回滚点: 风险低，仅影响右侧头部动作按钮图标描边参数；回滚 `headerIconStrokeWidth` 与对应 smoke 断言即可。

## 2026-06-21 - Header action icons fixed symbol canvas
- 目标: 重新检查并统一待办/日记两个标签页右侧按钮图标的实际视觉尺寸，使 `+`、同步、打开 Notion 图标整体看起来一致协调。
- 非目标: 不修改按钮动作、Notion/API/缓存/Keychain/设置持久化契约，不修改窗口管理、标签切换逻辑或工程配置。
- 影响路径:
  - `WidgetToDo/ContentView.swift`
  - `Tests/NotionFloatCoreSmokeTests/main.swift`
  - `progress.md`
- 状态: 已完成代码修改；新增 `headerIconButtonSize = 24` 和 `headerIconSymbolSize = 16`，右侧动作按钮点击区统一 24x24，图标统一通过 `headerActionIcon(systemName:)` 以 `resizable + aspectRatio(.fit) + 16x16 frame` 渲染；待办页 `+ / 同步 / 打开` 与日记页 `同步 / 打开` 均走同一 helper。
- 测量:
  - 用户截图 Image #1: 红框内深色像素测量显示 `+` 约 23x23 px、同步图标合并约 32x28 px、打开图标约 25x25 px；点击区视觉间距一致但 SF Symbol 固有图形包围盒不一致。
  - 用户截图 Image #2: 红框内深色像素测量显示同步图标合并约 32x28 px、打开图标约 25x25 px；与待办页同类图标不完全协调。
  - 调整后源码标准: 所有关联按钮点击区 24x24 pt，图标标准画布 16x16 pt；SF Symbol 仍保持矢量缩放，避免位图模糊。
- 最近验证:
  - `swift run NotionFloatCoreSmokeTests`: 先红于新增断言 `header action buttons should define shared click-area and symbol-size constants`；实现后已越过本次新增/更新断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift build`: 通过，`Build complete!`。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - UI 复测: 已尝试启动 Debug app 并截图，但当前可见前台被 Notion 窗口覆盖；Accessibility 报告 `WidgetToDo windows=0`，无法获取调整后的 Widget 窗口做像素复测。本轮不能声称调整后截图测量已通过。
- 风险/回滚点: 风险低，仅影响右侧头部动作按钮图标渲染尺寸；回滚 `headerIconButtonSize`、`headerIconSymbolSize`、`headerActionIcon(systemName:)` 及对应 smoke 断言即可。

## 2026-06-17 - Header action icon size alignment
- 目标: 统一待办页和日记页右侧头部动作按钮图标尺寸，确保打开 Notion、同步等对应按钮视觉大小一致。
- 非目标: 不修改按钮动作、Notion/API/缓存/Keychain/设置持久化契约，不修改窗口管理或工程配置。
- 影响路径:
  - `WidgetToDo/ContentView.swift`
  - `Tests/NotionFloatCoreSmokeTests/main.swift`
  - `progress.md`
- 状态: 已完成代码修改；待办页打开 Notion 图标已从 `13pt medium` 调整为 `14pt semibold`，与待办同步按钮、日记同步按钮和日记打开按钮保持同一 SF Symbol 字号/字重；按钮命中区仍由 `FloatingWidgetIconButtonStyle()` 保持为统一 24x24。
- 最近验证:
  - `swift run NotionFloatCoreSmokeTests`: 先红于新增断言 `todo header open icon should match the shared header action icon size and weight`；实现后已越过本次新增断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift build`: 通过，`Build complete!`。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - UI 手测: 启动 `/Users/chenxiaofeng/Library/Developer/Xcode/DerivedData/WidgetToDo-hidinztoljepfscjpdfzdzmljelp/Build/Products/Debug/WidgetToDo.app`；待办页右侧 `+ / 同步 / 打开` 图标尺寸协调一致；切到日记页后同步与打开按钮同排显示且尺寸一致。
- 风险/回滚点: 风险低，仅影响待办页打开 Notion 图标的显示字号/字重；回滚 `WidgetToDo/ContentView.swift` 中该图标的 `.font(.system(size: 14, weight: .semibold))` 与对应 smoke 断言即可。

## 2026-06-17 - Journal open-in-Notion header icon
- 目标: 将日记页底部“在 Notion 中打开”文字按钮移动到顶部日期行右侧，紧邻同步按钮；按钮只保留图标，图标尺寸与同步按钮一致，间距沿用同类型头部图标按钮标准。
- 非目标: 不修改 Notion/API/缓存/Keychain/设置持久化契约，不修改窗口管理、日记同步/自动保存逻辑，不触碰 `Package.swift`、`.xcodeproj` 或 entitlements。
- 影响路径:
  - `WidgetToDo/ContentView.swift`
  - `Tests/NotionFloatCoreSmokeTests/main.swift`
  - `progress.md`
- 状态: 已完成代码修改；日记页日期行右侧现使用 `HStack(spacing: FloatingWidgetMetrics.headerIconButtonSpacing)` 承载同步按钮与打开 Notion 按钮，打开按钮使用 `FloatingWidgetIconButtonStyle()` 与 `14pt semibold` 图标，底部状态栏已移除“在 Notion 中打开”文字按钮。
- 最近验证:
  - `swift run NotionFloatCoreSmokeTests`: 先红于新增断言 `journal header action buttons should use the shared icon-button spacing`；实现后已越过本次新增断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift build`: 通过，`Build complete!`。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - UI 手测: 已尝试启动 DerivedData Debug app，但 LaunchServices/辅助功能实际绑定到 `/Applications/WidgetToDo.app` 已安装旧版本；`ps/lsof` 确认前台进程来自 `/Applications/WidgetToDo.app/Contents/MacOS/WidgetToDo`，不是本次 22:17 构建的 DerivedData 二进制，因此本轮不能记为 UI 手测通过。
- 风险/回滚点: 风险低，仅影响日记页显示层按钮布局；回滚 `WidgetToDo/ContentView.swift` 中 `headerIconButtonSpacing`、日记 header 按钮组与对应 smoke 断言即可。

## 2026-06-17 - Journal tab date uses Chinese format
- 目标: 将日记 Tab 标题下方日期从英文 `Jun 17, 2026` 改为中文日期形式，例如 `2026年6月17日`。
- 非目标: 不修改待办 Tab 日期逻辑，不修改 Notion API 日期字段、日记页标题写入 Notion 的格式、缓存/Keychain/设置持久化、窗口行为，不修改 `Package.swift`、`.xcodeproj` 或 entitlements。
- 影响路径:
  - `WidgetToDo/ContentView.swift`
  - `Tests/NotionFloatCoreSmokeTests/main.swift`
  - `progress.md`
- 状态: 已完成代码修改；`journalDateString(from:)` 现使用 `zh_CN` locale 与 `yyyy年M月d日` 格式。新增 smoke 约束已先红后绿通过本次断言，但完整 smoke suite 仍停在仓库既有无关断言。
- 最近验证:
  - `swift run NotionFloatCoreSmokeTests`: 先红于新增断言 `journal date should use a Chinese locale`；实现后已越过本次新增断言，随后停在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift build`: 通过，`Build complete!`。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - `swift -e ... DateFormatter zh_CN yyyy年M月d日 ...`: 通过，固定日期 `2026-06-17` 输出 `2026年6月17日`。
  - UI 手测: 已尝试启动 DerivedData Debug app，但前台辅助功能实际抓到 `/Applications/WidgetToDo.app` 旧安装版进程，日记页仍显示旧英文日期；本轮无法把 UI 手测记为通过。代码路径、smoke 约束、formatter 探针和 app target 构建已覆盖本次改动。
- 风险/回滚点: 风险低，仅影响日记 Tab 显示层日期文案；回滚 `WidgetToDo/ContentView.swift` 中 `journalDateString(from:)` 的 locale/dateFormat 与对应 smoke 约束即可。

## 2026-06-17 - Floating window corner radius 12pt
- 目标: 将悬浮窗外层四周圆角从 `20pt` 调整为 `12pt`。
- 非目标: 不修改内部待办/日记面板圆角，不修改窗口尺寸、拖拽/吸附、Notion/API/缓存/Keychain/设置持久化契约，不修改 `Package.swift`、`.xcodeproj` 或 entitlements。
- 影响路径:
  - `WidgetToDo/ContentView.swift`
  - `progress.md`
- 状态: 已完成；`AppWindowChrome.cornerRadius` 已从 `20` 改为 `12`，外层背景与裁切继续共用同一常量。
- 最近验证:
  - `rg -n "static let cornerRadius: CGFloat = 12" WidgetToDo/ContentView.swift`: 先红后绿；修改前无匹配，修改后匹配到 `WidgetToDo/ContentView.swift:6`。
  - `rg -n "static let cornerRadius: CGFloat = 12|AppWindowChrome\\.cornerRadius|panelCornerRadius" WidgetToDo/ContentView.swift`: 通过；确认外层 chrome 使用 `12pt`，内部 `panelCornerRadius` 仍为 `12pt`。
  - `git diff --check -- WidgetToDo/ContentView.swift`: 通过，无空白格式问题。
  - `swift build`: 通过，`Build complete!`。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - UI 手测: 未启动 App 做肉眼确认；本次视觉变化已通过源码常量与 app target 构建验证。

## 2026-06-17 - Journal editor scrollbar alignment
- 目标: 将日记文本编辑区域改为滚动条贴合编辑框右侧边缘，并按内容高度动态显示滚动条；短内容完全隐藏滚动条，只有内容溢出时显示。
- 非目标: 不修改 Notion/API/缓存/Keychain/设置持久化契约，不修改 `Package.swift`、`.xcodeproj`、entitlements，不改待办页或窗口管理逻辑。
- 影响路径:
  - `WidgetToDo/ContentView.swift`
  - `Tests/NotionFloatCoreSmokeTests/main.swift`
  - `progress.md`
- 状态: 已完成代码修改；日记编辑器由 SwiftUI `TextEditor` 改为本地 `NSTextView + NSScrollView` 封装，文本内边距由 `NSTextView.textContainerInset` 承担，`NSScrollView` 右侧滚动条不再被外层 padding 内缩；`hasVerticalScroller` 根据排版后的内容高度动态切换。
- 最近验证:
  - `swift run NotionFloatCoreSmokeTests`: 先红后越过本次新增断言；首次失败于 `journal panel should use the custom AppKit editor instead of SwiftUI TextEditor`，实现后本次新增的编辑器与滚动条契约通过，当前仍停在仓库既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view`。
  - `swift build`: 通过，`Build complete!`；注意 SwiftPM 只覆盖 `WidgetToDo/Core` 与 smoke target，不覆盖 app target。
  - `swift test`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 阻塞，active developer directory 为 `/Library/Developer/CommandLineTools`。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build`: 通过，`** BUILD SUCCEEDED **`。
  - UI 手测: 启动 `/Users/chenxiaofeng/Library/Developer/Xcode/DerivedData/WidgetToDo-hidinztoljepfscjpdfzdzmljelp/Build/Products/Debug/WidgetToDo.app` 并切到日记页；短内容 `45645645645622` 下编辑框右侧无滚动条可见，辅助功能树也不再出现滚动条元素。
  - AppKit 逻辑探针: `swift -e ...` 复用同一内容高度判断，结果 `short=false`、`long=true`，确认短文本不显示滚动条、长文本显示滚动条。
  - `git diff --check -- WidgetToDo/ContentView.swift Tests/NotionFloatCoreSmokeTests/main.swift progress.md`: 通过，无空白格式问题。

## 2026-06-17 - macOS 14 onChange deprecation cleanup
- 目标: 修复 `WidgetToDo/ContentView.swift` 中两个 `onChange(of:perform:)` deprecated warning，保持输入规范化与日记自动保存行为不变。
- 非目标: 不调整 UI 布局、不修改 Notion/API/持久化契约、不触碰 `Package.swift`、`.xcodeproj` 或 entitlements。
- 影响路径:
  - `WidgetToDo/ContentView.swift`
  - `Tests/NotionFloatCoreSmokeTests/main.swift`
  - `progress.md`
- 状态: 已完成；源码迁移完成，自动化验证存在环境/既有 smoke 断言阻塞，见下方记录。
- 最近验证:
  - `swift build`: 通过，Build complete。
  - `swift test --filter NotionFloatCoreSmokeTests`: 阻塞，当前环境编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `swift test`: 阻塞，同样在编译 XCTest 测试目标时报 `no such module 'XCTest'`。
  - `swift run NotionFloatCoreSmokeTests`: 可构建并运行 smoke executable；本次更新过的 database normalization 源码扫描通过，随后在既有无关断言 `settings reset flow should keep a dedicated settingsBackRow view` 处失败。
  - `xcodebuild -list -project WidgetToDo.xcodeproj`: 阻塞，active developer directory 为 `/Library/Developer/CommandLineTools`，当前环境没有可用 Xcode。
  - `rg` 检查旧单参数 `onChange` 形态: 无匹配输出。

## 2026-08-05 - Pomodoro prototype and implementation-plan accumulation rule
- 目标: 将番茄钟交互原型和待交付开发计划统一为“沿用现有预计时长并累计增加”的规则；例如原值 45 分钟完成一轮 25 分钟后显示为 70 分钟。倒计时结束播放提示音、先写回时长、再由用户手动决定是否完成任务。
- 非目标: 不开发 Swift 功能；不改 `WidgetToDo` 生产代码、Notion API、数据库字段、缓存、设置、窗口或任何既有产品 UI。
- 影响路径:
  - `docs/superpowers/prototypes/Pomodoro Task Flow Explorations.html`
  - `docs/superpowers/plans/2026-08-05-pomodoro-task-focus.md`
  - `progress.md`
- 状态: 已完成原型与计划调整。原型已移除“倒计时结束自动完成任务”开关；结束原型事件会累计本轮时长并显示“本轮已完成”确认，任务只有在用户点击“完成任务”后才变更为完成。计划明确生产实现使用现有 `预计时长` 字段，采用 45 + 25 = 70 的增量写回规则、`NSSound.beep()`、时长写入先于任务完成、失败不双计入的重试约束。
- 最近验证:
  - `rg -n "auto|自动完成|预计时长|45.*25|70|NSSound" docs/superpowers/plans/2026-08-05-pomodoro-task-focus.md`: 通过；确认计划含累计契约、45 + 25 = 70、无自动完成开关与系统提示音约束。
  - `rg -n "auto|自动完成|repeatFocus|settleCompleted|recordFocusDuration|playCompletionTone|本轮已完成" docs/superpowers/prototypes/Pomodoro\ Task\ Flow\ Explorations.html`: 通过；旧自动完成和失效的重复专注逻辑无匹配，原型含累计、提示音和结束确认逻辑。
  - `git diff --check`: 通过；文档与原型无空白格式问题。
  - UI 手测: 未执行；本次仅调整本地 HTML 原型与开发计划，in-app Browser 对本地 `file://` 页面访问受当前工具策略限制。生产 App 未改动，因此不存在生产 UI 验证结论。
- 风险/回滚点: 风险仅限原型与交付计划和后续实现的语义约束；回滚这三个文档改动即可，不会影响现有应用或 Notion 数据。

## 2026-08-05 - Pomodoro duration label and explicit completion switch
- 目标: 将番茄钟原型和计划中的用户可见“预计时长”统一为“时长”；在结束专注的最终确认弹框加入默认关闭的“同时完成任务”开关，允许用户只记录时长而不完成任务。
- 非目标: 不重命名实际 Notion 字段或 Swift 的 `estimatedMinutes` 模型属性；不开发生产 Swift 代码；不改其他任务列表、日记、设置、窗口或 Notion 功能。
- 影响路径:
  - `docs/superpowers/prototypes/Pomodoro Task Flow Explorations.html`
  - `docs/superpowers/plans/2026-08-05-pomodoro-task-focus.md`
  - `progress.md`
- 状态: 已完成原型与计划调整。开始弹框不出现完成开关；手动结束弹框关闭开关时主动作是“记录时长”，打开后为“记录并完成任务”。自然结束会先记录时长，关闭开关时为“保持未完成”，打开后为“完成任务”。
- 最近验证:
  - `node -e '... new Function(script[1]) ...'`: 通过，`Pomodoro Task Flow Explorations.html` 内嵌 JavaScript 语法有效。
  - `rg -n "预计时长|auto-complete|autoComplete|自动完成|repeatFocus|settleCompleted" docs/superpowers/prototypes/Pomodoro\ Task\ Flow\ Explorations.html docs/superpowers/plans/2026-08-05-pomodoro-task-focus.md || true`: 通过，无旧“预计时长”、自动完成开关或失效原型逻辑匹配。
  - `git diff --check`: 通过，无空白格式问题。
  - Playwright 截图: 阻塞。`npx playwright screenshot ...` 报当前 CLI 需要的 `chromium_headless_shell-1234` 不存在；本机缓存仅有其他 Chromium 版本。未下载/修改浏览器运行时。in-app Browser 对本地 `file://` 页面访问也受当前工具策略限制。生产 App 未改动。
- 风险/回滚点: 风险仅在未实现功能的原型/计划语义；回滚上述文档和原型改动即可。实际字段名称继续沿用内部 `estimatedMinutes`，避免改动 Notion 数据契约。

## 2026-08-05 - Pomodoro final-dialog single-action alignment
- 目标: 移除最终成功弹框中重复的任务标题，并将单一“知道了”按钮置于弹框操作区正中，避免沿用双按钮网格而偏在左侧。
- 非目标: 不调整开始、暂停、放弃弹框中的任务标题；不改生产 Swift 代码、Notion 逻辑或其他产品布局。
- 影响路径:
  - `docs/superpowers/prototypes/Pomodoro Task Flow Explorations.html`
  - `docs/superpowers/plans/2026-08-05-pomodoro-task-focus.md`
  - `progress.md`
- 状态: 已完成。`结束专注`、`本轮已完成` 及其成功态不重复显示任务名；成功态给操作区增加 `single-action` 网格，唯一“知道了”按钮居中。开始、暂停、放弃继续显示任务名称以保留上下文。
- 最近验证:
  - `node -e '... new Function(script[1]) ... dialog-actions.single-action ...'`: 通过，内嵌 JavaScript 语法有效，成功态单按钮样式和状态切换代码均存在。
  - `git diff --check`: 通过，无空白格式问题。
  - UI 截图: 沿用上一条 Playwright 运行时缺失阻塞，未声称肉眼截图通过。
- 风险/回滚点: 风险仅限本地原型成功态布局；回滚 `single-action` 样式、`finishFocus()` 中的状态类及计划/进度文档即可。

## 2026-08-05 - Pomodoro product specification
- 目标: 为交付其他 AI 的番茄钟开发计划补充独立产品 Spec，作为时长累计、完成开关、最终弹框和非目标的单一产品规则来源。
- 非目标: 不新增生产代码、不改变已有开发计划的实施范围、不改 Notion/Swift 数据契约或其他产品 UI。
- 影响路径:
  - `docs/superpowers/specs/2026-08-05-pomodoro-task-focus-design.md`
  - `docs/superpowers/plans/2026-08-05-pomodoro-task-focus.md`
  - `progress.md`
- 状态: 已完成。Spec 明确“时长”作为用户可见名称、内部仍沿用 `estimatedMinutes`、45 + 25 = 70、最终“同时完成任务”开关默认关闭、自然/手动结束的写入顺序、最终弹框不重复任务标题及单按钮居中。开发计划已链接该 Spec。
- 最近验证:
  - `rg -n "TBD|TODO|预计时长|automatic|自动完成|时长 70|同时完成任务|标题|居中|NotionRepository" docs/superpowers/specs/2026-08-05-pomodoro-task-focus-design.md`: 通过；未发现占位项、旧用户可见字段名或自动完成规则，关键产品约束均存在。
  - `git diff --check`: 通过，无空白格式问题。
- 风险/回滚点: 风险只在文档一致性；回滚该 Spec 文件和计划中的 Spec 链接即可，不影响应用代码或用户数据。

## 2026-08-05 - Pomodoro implementation reference hierarchy
- 目标: 明确交付其他 AI 时的效果参考边界，防止其依据讨论截图或原型外区域扩展 UI 改动。
- 非目标: 不改原型视觉、生产代码或产品行为；不把讨论截图提升为实现来源。
- 影响路径:
  - `docs/superpowers/specs/2026-08-05-pomodoro-task-focus-design.md`
  - `docs/superpowers/plans/2026-08-05-pomodoro-task-focus.md`
  - `progress.md`
- 状态: 已完成。Spec 与计划均规定：Spec 是行为/数据规则来源；`docs/superpowers/prototypes/Pomodoro Task Flow Explorations.html` 是新增番茄钟 UI 的唯一视觉与交互来源；现有生产 Todo UI 是所有非番茄钟区域的不可改动基线；讨论截图只用于评审，不作为实现依据。
- 最近验证:
  - `rg -n -C 1 "source of truth|Reference hierarchy|only visual|only.*reference|Discussion screenshots|生产界面" docs/superpowers/specs/2026-08-05-pomodoro-task-focus-design.md docs/superpowers/plans/2026-08-05-pomodoro-task-focus.md`: 通过；两份文档都包含来源层级和截图排除约束。
  - `git diff --check`: 通过，无空白格式问题。
- 风险/回滚点: 风险仅限开发交接语义；回滚这两段引用层级说明和本进度记录即可。

## 2026-08-06 - Pomodoro core engine and accumulation contract
- 目标: 落地番茄钟核心模块（纯计时引擎 + 本地化契约 + 时长累计写回契约），TDD 验证；本轮严格遵守“仅改动番茄钟相关代码、不改动现有其他功能模块及 UI”，不触碰 ViewModel / ContentView / 窗口层。
- 非目标: 不做 UI 卡片/弹框、不做 ViewModel tick 编排、不改 Package.swift/.xcodeproj/entitlements/NotionClient/SettingsStore/Keychain/SQLite、不重命名 `estimatedMinutes` 或 Notion 字段、不持久化活跃会话。
- 影响路径:
  - 新增 `WidgetToDo/Core/Models/PomodoroSession.swift`
  - 新增 `WidgetToDo/Core/Services/PomodoroSessionEngine.swift`
  - 新增 `Tests/NotionFloatCoreTests/PomodoroSessionEngineTests.swift`
  - 增量改动 `WidgetToDo/Core/Services/AppLocalizer.swift`（仅追加 45 个 `pomodoro*` 键，中/英/法）
  - 增量改动 `Tests/NotionFloatCoreTests/AppMessageLocalizationTests.swift`（追加 4 条断言）
  - 增量改动 `Tests/NotionFloatCoreTests/NotionRepositoryTaskMutationTests.swift`（新增 45+25=70 累计测试）
- 状态: 已完成核心模块代码与全部自动化验证；UI 集成（plan Task 3-5）留待后续。
- 设计要点:
  - `PomodoroSession` 可变字段为 `public private(set)`，引擎跨文件采用“整体替换 via 公开 init”，不 mutate 副本。
  - 引擎基于 `Date` 计算时间推移，避免每秒自减漂移；`advance`/`pause` 把活跃增量钳位到 `remainingSeconds`，跨零不超额累计。
  - `completedMinutes(at:)` 向上取整，手动结束至少 1 分钟，无会话返回 0；自然结束给出整轮时长。
- 最近验证:
  - RED: `cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter PomodoroSessionEngineTests` — 如预期编译失败 `cannot find 'PomodoroSessionEngine' in scope`。
  - 绿: 同上目录 `swift test --disable-sandbox --filter 'PomodoroSessionEngineTests|AppMessageLocalizationTests|NotionRepositoryTaskMutationTests'` — `Executed 29 tests, with 0 failures`。
  - 全量: `swift test --disable-sandbox` — `Executed 62 tests, with 0 failures`。
  - smoke: `swift run --disable-sandbox NotionFloatCoreSmokeTests` — `All smoke tests passed.`。
  - 构建: `xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoPomodoroCoreDerivedData build` — `** BUILD SUCCEEDED **`。
  - 标准入口 `swift test` 仍阻塞于 `sandbox-exec: sandbox_apply: Operation not permitted`，与既有环境问题一致；本轮全部使用 `--disable-sandbox` + `DEVELOPER_DIR`。
  - UI 手测: 本轮无 UI 改动，无需手测。
- 风险/回滚点:
  - 后续在引擎文件内直接 `session.phase = ...` 会因 `private(set)` 编译失败，须保持替换式写法。
  - 本轮无法端到端验证 45→70 在真实界面上的体现，待 ViewModel + UI 接入后补 Xcode 手测。
  - 回滚：还原三处增量文件并删除三个新增文件即可；无数据迁移。

## 2026-08-06 - Pomodoro ViewModel integration and smoke guards
- 目标: 将番茄钟核心引擎接入 `TodoListViewModel`，完成 tick 编排、写回顺序、幂等重试上下文；同步在 smoke 中加入源码守卫，防止后续回归。严格遵守“仅改动番茄钟相关代码、不改动现有其他功能模块及 UI”，不触碰 ContentView / 窗口层 / Package.swift / .xcodeproj / entitlements / NotionClient / SettingsStore / Keychain / SQLite。
- 非目标: 不做 `PomodoroViews.swift` 焦点卡/弹框、不在 `ContentView` 接入开始入口与活动卡、不持久化活跃会话、不重命名 `estimatedMinutes` 或 Notion 字段。
- 影响路径:
  - 增量改动 `WidgetToDo/TodoListViewModel.swift`（新增 `PomodoroPrompt`、`FinishedPomodoroContext`、`@Published` 番茄钟状态、公开动作 `presentPomodoroStart`/`beginPomodoro`/`pausePomodoro`/`resumePomodoro`/`requestPomodoroAbandon`/`confirmPomodoroAbandon`/`requestPomodoroManualCompletion`/`confirmPomodoroManualCompletion`/`confirmPomodoroNaturalEnd`/`retryPomodoroDurationWrite`/`dismissPomodoroLater`/`dismissPomodoroSuccess`，私有 helper `startPomodoroTick`/`cancelPomodoroTick`/`finishPomodoroRound`/`recordPomodoroDuration`，`deinit` 取消 tick；`import AppKit` 用于 `NSSound.beep()`）。
  - 增量改动 `Tests/NotionFloatCoreSmokeTests/main.swift`（新增 `pomodoroViewModelIntegrationKeepsContract()` 源码守卫并在 `main` 中调用）。
  - `progress.md`。
- 状态: 已完成 ViewModel 集成与全部自动化验证；UI 卡片与 ContentView 接入（plan Task 4-5）留待后续。
- 设计要点:
  - Tick 任务以 `Task.sleep(nanoseconds: 1_000_000_000)` 每秒推进 `pomodoroEngine.advance(to: Date())`，收到 `.finished` 后停止本轮 tick 并进入 `finishPomodoroRound`。
  - 写回顺序：自然结束先 `NSSound.beep()` → 写回时长 → 成功后呈现 `.naturalEnd` prompt 让用户决定是否完成任务；手动结束先暂停 → 计算 `completedMinutes` → 写回时长 → 成功后按开关决定是否完成任务。失败进入 `.durationWriteFailed`，不继续完成动作，避免双计入。
  - 幂等重试：`FinishedPomodoroContext.durationWriteSucceeded` 标记本次写回是否成功；`retryPomodoroDurationWrite` 仅在未成功时重试，成功后转回 `.naturalEnd`；每次异步分支后用 `guard finishedPomodoro?.taskID == context.taskID` 防止上下文被另一轮替换。
  - 时长累计：`recordPomodoroDuration` 取当前任务 `estimatedMinutes`（或上下文里的 baseEstimatedMinutes 兜底），`newTotal = (baseMinutes ?? 0) + context.minutesToAdd`，复用既有 `repository.updateTaskTitle(id:title:estimatedMinutes:)`，满足 45 + 25 = 70 契约。
  - `deinit` 取消 tick 任务，避免 ViewModel 释放后仍在推进。
- 最近验证:
  - smoke: `cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` — `All smoke tests passed.`（含新增 `pomodoroViewModelIntegrationKeepsContract` 守卫）。
  - 全量: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` — `Executed 62 tests, with 0 failures`。
  - 构建: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoPomodoroVMDerivedData build` — `** BUILD SUCCEEDED **`。首次构建曾因 TRAE Sandbox 拦截 Keychain 访问导致 CodeSign 失败（非代码错误），重跑增量构建通过。
  - 标准入口 `swift test` 仍阻塞于 `sandbox-exec: sandbox_apply: Operation not permitted`，与既有环境问题一致；本轮全部使用 `--disable-sandbox` + `DEVELOPER_DIR`。
  - UI 手测: 本轮无 UI 改动，无需手测。
- 风险/回滚点:
  - `TodoListViewModel` 现在依赖 `PomodoroSessionEngine` 与 `PomodoroSession`；后续在引擎内直接 `session.phase = ...` 会因 `private(set)` 编译失败，须保持替换式写法。
  - 自然结束的 `finishPomodoroRound` 在 `Task { @MainActor [weak self] in ... }` 中异步写回；若用户在写回未完成时快速开始下一轮，`guard finishedPomodoro?.taskID == context.taskID` 会丢弃旧结果，但 UI 不会自动清掉旧 prompt——待 UI 接入时验证是否需要在 `beginPomodoro` 主动清空 `pomodoroPrompt`。
  - 回滚：还原 `TodoListViewModel.swift` 与 `Tests/NotionFloatCoreSmokeTests/main.swift` 即可；无数据迁移，无 Notion 字段变更。

## 2026-08-06 - Pomodoro UI views and ContentView integration
- 目标: 落地番茄钟 UI 层（plan Task 4-5），创建 `PomodoroViews.swift` 焦点卡/开始弹框/提示弹框，在 `ContentView` 待办路径接入「计时」入口与条件性置顶专注卡。严格遵守"仅改动番茄钟相关代码、不改动现有其他功能模块及 UI"，不触碰 Journal/设置/onboarding/mini-mode/top bar/date nav/正常任务行布局/Package.swift/.xcodeproj/entitlements/NotionClient/SettingsStore/Keychain/SQLite。
- 非目标: 不持久化活跃会话、不重命名 `estimatedMinutes` 或 Notion 字段、不改 Package.swift/.xcodeproj、不改 Notion API 契约。
- 影响路径:
  - 新增 `WidgetToDo/PomodoroViews.swift`（`PomodoroFocusCard` 置顶专注卡、`PomodoroStartCard` 开始弹框、`PomodoroPromptCard` 提示弹框路由 pause/abandon/manualCompletion/naturalEnd/durationWriteFailed/success、`PomodoroTaskRowStartAction` 任务行「计时」按钮；自包含 `PomodoroPalette`/`PomodoroMetrics`/`PomodoroTrackingModifier`，镜像现有 `FloatingWidgetPalette` 色值以保持视觉一致且不改动现有 private 枚举）。
  - 增量改动 `WidgetToDo/ContentView.swift`（仅 3 处接入：`todoPanel` VStack 中 `syncBanner` 之后插入 `PomodoroFocusCard`；`todoPanel` ZStack 中 `EditTaskFormCard` 之后插入 `PomodoroStartCard` + `PomodoroPromptCard`；`taskRowView` action HStack 中菜单按钮前给未完成任务加 `PomodoroTaskRowStartAction`）。
  - 增量改动 `Tests/NotionFloatCoreSmokeTests/main.swift`（新增 `pomodoroViewsKeepContract()` 与 `pomodoroContentViewIntegrationKeepsContract()` 源码守卫并在 `main` 中调用）。
  - `progress.md`。
- 状态: 已完成 UI 层代码与全部自动化验证；UI 手测待用户在 Xcode 运行 App 后确认。
- 设计要点:
  - 焦点卡：左圆环倒计时（`Circle().trim` 按 `remainingSeconds/totalSeconds` 进度，暂停态变橙色）+ 右任务标题/meta + 下方等宽 `放弃/暂停-继续/完成` 三按钮；`pomodoroSession == nil` 时不渲染，无空白占位。
  - 开始弹框：标题居中 + 任务名 + 文案 + hint + 「本轮时长」三等分预设（25/45/自定义）+ 自定义选中时展开 TextField + 取消/开始按钮；无完成开关（spec §1-2）。
  - 提示弹框路由：pause→`放弃本轮`/`继续专注`；abandon→`继续专注`/`确认放弃`（destructive）；manualCompletion→`结束专注`kicker + 文案 + 完成开关（默认关）+ `继续专注`/动态 primary（`记录时长`/`记录并完成任务`）；naturalEnd→`本轮已完成` + 文案 + hint + 完成开关 + 单 primary（`保持未完成`/`完成任务`，spec §5 单按钮）；durationWriteFailed→`稍后决定`/`重试写入`；success→单按钮 `知道了`（spec §6 居中）。
  - 完成开关绑定 `viewModel.pomodoroCompleteTaskToggle`（ViewModel 端在进入 manual/natural prompt 前重置为 false）。
  - 任务行「计时」按钮：任何活跃会话/开始弹框/提示弹框期间禁用（`pomodoroSession != nil || pomodoroStartTask != nil || pomodoroPrompt != nil`），保证单会话。
  - 弹框背景改为透明（`Color.clear`），保留点击空白处交互：开始弹框点击空白处取消；提示弹框点击空白处恢复专注（等效「继续专注」）。
  - 开始弹框视觉重排：宽度收窄到 260pt；标题 18pt 粗体；文案 12pt；移除任务名和 divider；「本轮时长」改为独立 13pt 标题；三个预设按钮改为 40pt 高大圆角胶囊，选中态为浅米色底+棕色边框；取消/开始按钮改为 42pt 高大圆角胶囊并排，开始专注按钮改为深色（近黑棕）底；「不会修改任务状态」hint 移到按钮下方。
  - 严格按 WidgetToDo-Welcome-Modal.html 的 `.pomo-*` CSS 重写全部番茄钟视图：PomodoroPalette 改为镜像 HTML 色值（#fdfbf9/#e1dcd6/#a17c59/#34312e/#68c46b/#bf524b 等）；PomodoroMetrics 改为镜像 HTML 尺寸（focus card 68pt ring/16pt radius，dialog 16pt radius/300pt width，option 38pt 高/9pt radius，button 38pt 高/9pt radius，toggle 40x24）；新增 PomodoroDialogShell/PomodoroScrim/PomodoroKicker/PomodoroDialogTitle/PomodoroDialogBody/PomodoroDialogHint/PomodoroPrimaryButton/PomodoroSecondaryButton/PomodoroCompleteButton/PomodoroDestructiveButton/PomodoroDialogActions/PomodoroDurationPicker/PomodoroCompletionToggle/PomodoroSwitch 等共享组件；scrim 改为 warm dark rgba(39,34,29,.26)+ultraThinMaterial 模糊；focus card ring 改为 conic-gradient 近似+inner disc；completion toggle 改为横向布局+自定义 iOS switch；custom input 带分隔线。同步更新 smoke 守卫匹配新组件名（optionButton/PomodoroSwitch/.pomodoroDone）。
  - 手动结束「继续专注」调 `resumePomodoro()`（会话在 `requestPomodoroManualCompletion` 中已 pause，resume 恢复运行并清 prompt）。
  - 未使用 macOS `confirmationDialog`，全部自定义 SwiftUI overlay，与现有 NewTaskFormCard/EditTaskFormCard 风格一致。
- 最近验证:
  - smoke: `cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` — `All smoke tests passed.`（含新增 `pomodoroViewsKeepContract` + `pomodoroContentViewIntegrationKeepsContract` 守卫）。
  - 全量: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` — `Executed 62 tests, with 0 failures`。
  - 构建: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoPomodoroUIDerivedData build` — `** BUILD SUCCEEDED **`。
  - 标准入口 `swift test` 仍阻塞于 `sandbox-exec: sandbox_apply: Operation not permitted`，与既有环境问题一致；本轮全部使用 `--disable-sandbox` + `DEVELOPER_DIR`。
  - UI 手测: 代码与构建已通过；端到端手测（25/45/自定义启动、暂停排除非活跃时间、放弃不写、自然 25 在 45 上 beep 并显示 70、稍后决定保留 70/未完成、完成按 duration-first 顺序、61 秒手动结束加 2 分钟、duration 失败不完成/双加）待用户在 Xcode 运行 App 后确认。
- 风险/回滚点:
  - `PomodoroPalette` 镜像 `FloatingWidgetPalette` 色值；若未来生产调色板变更，需同步更新 `PomodoroPalette` 以保持一致。
  - 焦点卡圆环 `trim(from: 0, to: max(0.02, progress))` 在 remaining=0 时仍显示极小弧段，避免完全消失的视觉跳变；若需精确归零可调整。
  - 自然结束单按钮设计与 spec §5 一致；若用户反馈需要 secondary action，需同时更新 spec 与 ViewModel。

## 2026-08-07 - Pomodoro success dialog shows recorded minutes
- 目标: 修复番茄钟完成弹框未显示具体保存时长数字的问题。
- 非目标: 不改其他弹框、不调整 UI 样式、不动 Notion API 或持久化。
- 影响路径:
  - 增量改动 `WidgetToDo/TodoListViewModel.swift`：`PomodoroPrompt.success` 关联值由 `(completedTask: Bool)` 扩展为 `(completedTask: Bool, minutesToAdd: Int)`；`confirmPomodoroManualCompletion` 与 `confirmPomodoroNaturalEnd` 中 7 处 `.success(...)` 全部传入 `context.minutesToAdd`。
  - 增量改动 `WidgetToDo/PomodoroViews.swift`：`success` case 匹配改为 `(completedTask, minutesToAdd)`，`successDialog` 接收 `minutesToAdd` 并调用 `languageStore.text(copy, minutesToAdd)` 注入分钟数。
  - 增量改动 `Tests/NotionFloatCoreSmokeTests/main.swift`：更新 success prompt 守卫，断言 `case .success(let completedTask, let minutesToAdd)` 与 `languageStore.text(copy, minutesToAdd)`。
- 状态: 已完成；构建与 smoke 均通过。
- 设计要点:
  - 时长数字来自本轮写回时实际使用的 `FinishedPomodoroContext.minutesToAdd`，与自然结束/手动结束/重试后的成功状态保持一致。
- 最近验证:
  - 构建: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoPomodoroUIDerivedData build` — `** BUILD SUCCEEDED **`。
  - smoke: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` — `All smoke tests passed.`。
- 风险/回滚点:
  - `PomodoroPrompt` 是文件内私有 enum，影响面仅限 ViewModel 与 PromptCard，无外部依赖。
  - 回滚：还原上述三处 `.success` 关联值与调用即可。

## 2026-08-07 - Remove bracket wrapping around Int localization arguments
- 目标: 修复所有使用 `LanguageStore.text(key, intValue)` 的地方把整型参数渲染成 `[x]`（如 `[1] 分钟`、`开始 [25] 分钟专注`）的问题。用户框选了任务列表时长、开始弹框按钮、结束专注弹框、成功弹框共 4 处。
- 非目标: 不改本地化文案字符串本身、不改番茄钟业务逻辑、不动 Notion API 或持久化。
- 影响路径:
  - 修复 `WidgetToDo/LanguageStore.swift`：`text(_:_:)` 原来把 `CVarArg...` 数组直接传给 `AppText.string` 的 variadic 重载，导致 `[CVarArg]` 被当作单个参数后 `String(describing:)` 输出数组描述 `[x]`；改为显式 `arguments.map { String(describing: $0) }` 后调用 `[String]` 重载。
  - 增量改动 `Tests/NotionFloatCoreTests/AppMessageLocalizationTests.swift`：新增 `testCVarArgIntArgumentsAreNotWrappedInBrackets()`，覆盖 minutesValue 和 3 处番茄钟文案，断言 `AppText.string` 的 CVarArg 重载不会输出 `[x]`。
- 状态: 已完成；构建、全量测试、smoke 均通过。
- 设计要点:
  - 该修复位于通用本地化入口，收益范围覆盖整个 App 所有带整型参数的本地化调用（如 wordCount、completedTasksCount 等），但改动本身只改一行代码，且保持 `LanguageStore.text` 的签名与现有调用点完全兼容。
- 最近验证:
  - 构建: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoPomodoroUIDerivedData build` — `** BUILD SUCCEEDED **`。
  - 全量: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` — `Executed 63 tests, with 0 failures`（新增 1 个 localization 回归测试）。
  - smoke: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` — `All smoke tests passed.`。
- 风险/回滚点:
  - `LanguageStore.text` 是全局本地化入口，若某处调用依赖之前的错误行为（理论上不存在），修复后会暴露；目前已通过全量测试与 smoke 验证。
  - 回滚：还原 `LanguageStore.swift` 的一行改动并删除新增测试即可。

## 2026-08-07 - Fix resume focus from abandon dialog + remove grey scrim
- 目标: 修复放弃确认弹框中「继续专注」按钮点击无反应的问题；按用户要求移除番茄钟弹框后的灰色蒙版。
- 非目标: 不改其他弹框文案/样式、不动业务逻辑（除 resume 入口外）、不动 Notion API 或持久化。
- 影响路径:
  - 修复 `WidgetToDo/TodoListViewModel.swift`：`resumePomodoro()` 原先用 `guard pomodoroSession?.phase == .paused else { return }`，在放弃确认弹框中会话 phase 仍为 `.running`，导致按钮无响应；改为 `if phase == .paused { resume + startTick }` 后统一 `pomodoroPrompt = nil`，使运行态下点击「继续专注」也能关闭弹框。
  - 修复 `WidgetToDo/PomodoroViews.swift`：`PomodoroScrim` 由 `PomodoroPalette.scrimBg + .ultraThinMaterial` 改为 `Color.clear`，保留 `contentShape` 与点击空白处关闭行为。
- 状态: 已完成；构建、全量测试、smoke 均通过。
- 设计要点:
  - 「继续专注」在暂停态恢复计时，在运行态仅关闭弹框，符合用户从暂停/放弃两个入口点击同一文案的直觉。
  - 透明 scrim 保留点击空白处关闭（开始弹框取消、提示弹框继续），同时满足用户不要灰色遮罩的要求。
- 最近验证:
  - 构建: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoPomodoroUIDerivedData build` — `** BUILD SUCCEEDED **`。
  - 全量: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` — `Executed 63 tests, with 0 failures`。
  - smoke: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` — `All smoke tests passed.`。
- 风险/回滚点:
  - `resumePomodoro()` 是公开入口，改动后行为更宽容；如需严格暂停态才响应，可恢复 guard，但需为放弃弹框单独提供关闭方法。
  - 回滚：还原 `TodoListViewModel.swift` 的 `resumePomodoro()` 与 `PomodoroViews.swift` 的 `PomodoroScrim` 即可。
