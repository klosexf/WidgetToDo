# Progress

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
