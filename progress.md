# Progress

## 2026-09-06 - Calendar today button copy unified (弹层「今天」改「回到今天」)
- 目标: 月历弹层头部的「今天」按钮文案与导航栏统一为「回到今天」。
- 改动: `CalendarPopoverView.swift` 弹层按钮 textProvider 从 `.calendarToday` 改为复用 `.backToToday`（中/英/法三语现成）；`AppLocalizer.swift` 删除不再使用的 `calendarToday` key（enum case + 三处翻译）。
- 验证: `swift test` -> `Executed 122 tests, with 0 failures`（calendarToday 无其他引用，删除无破坏）。
- 回滚点: 还原 CalendarPopoverView.swift + AppLocalizer.swift 两文件。

## 2026-09-06 - I-beam final root cause: NSTextView cursor leak + isSelectable toggle (I-beam 终局修复)
- 用户关键线索：「待办 tab 正常、日记 tab 有 I-beam」。查代码确认差异：日记 tab 底部是 AppKit `NSTextView`（`JournalTextEditor` → `OverflowAwareTextScrollView` + `NSTextView`，`isSelectable = true`），待办 tab 无 NSTextView。
- 根因定论: `NSTextView` 是 AppKit 控件，其 I-beam 光标会**泄漏到整个浮窗**（包括叠在上方的 SwiftUI 月历弹层），`.textSelection(.disabled)` / `onHover+NSCursor`（set 或 push/pop）都只能管 SwiftUI 视图，压不过 AppKit 控件的 tracking area——前三轮方案全部无效的原因。
- 根治: `JournalTextEditor` 新增 `isSelectable` 参数（月历弹层打开时 `activeCalendarTab != .journal` 传 false）；`makeNSView` 用该值初始化、`updateNSView` 在弹层开合时同步切换。弹层打开 → NSTextView 不可选 → I-beam 消失；弹层关闭 → 恢复可选 → 正常编辑。
- 验证: `swift test` -> `Executed 122 tests, with 0 failures`；剥离 #Preview 副本 `xcodebuild build` -> `** BUILD SUCCEEDED **`。UI 手测: 待用户在 Xcode 重跑——日记 tab 弹层上应为箭头/手型（不再是截图里的 I-beam）。
- 教训（四轮迭代）: SwiftUI Text 的 I-beam 可用 .textSelection(.disabled) 关；但**AppKit NSTextView 的光标泄漏只能关掉它自己的 isSelectable**，外层 SwiftUI 修饰器都压不住。
- 回滚点: 还原 ContentView.swift 单文件。

## 2026-09-06 - Calendar popover I-beam root fix: textSelection(.disabled) (I-beam 根治)
- 用户提供截图证据：鼠标悬停在日期格「3」上仍是 I-beam——push/pop 版仍被 Text/Button 自身的 NSTrackingArea 抢回。
- 根因定论: macOS 给**可选择的文本**自动配 I-beam 光标；SwiftUI 弹层里的日期数字/星期表头是普通 Text，系统默认认为可选 → I-beam。`onHover+NSCursor`（无论 set 还是 push/pop）都无法压过 Text 自身的 tracking area。
- 根治: `CalendarPopoverView.body` 加 `.textSelection(.disabled)`——关闭弹层内所有 Text 的文本选择能力，系统不再为它们配 I-beam，日期格自然呈现箭头/按钮手型。容器 `.cursor(.arrow)` 保留作空白处兜底。
- 验证: 剥离 #Preview 副本 `xcodebuild build` -> `** BUILD SUCCEEDED **`。UI 手测: 待用户在 Xcode 重跑——日期格上应为箭头（不再是截图里的 I-beam）。
- 教训（三轮迭代）: set/restore 会被抢 → push/pop 仍被抢 → 正确约束是**关掉文本选择**（.textSelection(.disabled)），让系统根本不给 Text 配 I-beam。
- 回滚点: 还原 CalendarPopoverView.swift 单文件。

## 2026-09-06 - Cursor push/pop stack + date nav bar coverage (光标修复二连)
- 用户反馈弹层光标仍为 I-beam（上一轮的 set/restore 版本未完全生效）。同时用户澄清问题域是「日期弹框本身」而非导航栏——但导航栏同样缺覆盖，一并补齐。
- 根因修正: macOS 光标用 `push()`/`pop()` 栈才可靠——`set()` 在嵌套视图（弹层容器=箭头、内部日期格=手型）+快速移动时会互相踩掉、卡在错误形状；且容器级 `onHover` 只在空白处触发，移到 Text 上被其自身 I-beam 抢回。
- 修复:
  - `CalendarPopoverView.swift`: `View.cursor(_:)` 从 set/restore 重写为 `shape.push()` / `NSCursor.pop()` 栈式（嵌套时各压各的、退出自动回上一层）；扩展从 `private` 提升为文件内公共（ContentView 也要用）。
  - `ContentView.swift`: 日期导航栏补齐光标——日期标题按钮/左右箭头/「回到今天」均 `.cursor(.pointingHand)`，导航栏整体 `.cursor(.arrow)` 兜底（按钮间空隙、Spacer 不再 I-beam）。
- 验证: `swift test` -> `Executed 122 tests, with 0 failures`；剥离 #Preview 副本 `xcodebuild build` -> `** BUILD SUCCEEDED **`。UI 手测: 待用户在 Xcode 运行——弹层空白/文字=箭头、日期格/箭头/今天=手型；导航栏同理。
- 注意: 上一轮结论「set/restore 已修好」实际未生效（用户本轮复测发现），此处更正——正确约束是 push/pop 栈。
- 回滚点: 还原 CalendarPopoverView.swift + ContentView.swift 两文件。

## 2026-09-06 - Calendar popover cursor fix (弹层鼠标光标异常)
- 现象: 日记 tab 点日期弹出月历后，鼠标移入弹层呈文本选取光标（I-beam）而非箭头/手型。
- 根因: macOS 的 SwiftUI `Text` 悬停默认呈 I-beam（系统行为），弹层内日期数字/星期表头/标题均为 Text，无任何光标覆盖。
- 修复（`WidgetToDo/CalendarPopoverView.swift`）: 新增私有 `View.cursor(_:)` 修饰器（onHover + NSCursor.set，移出恢复箭头；嵌套时内层后触发/后恢复层级正确）；弹层容器整体 `.cursor(.arrow)`（覆盖所有 Text 的 I-beam），可点元素单独 `.cursor(.pointingHand)`: 日期格 Button、翻月箭头 Button、「今天」Button。补充 `import AppKit`（NSCursor 所在模块）。
- 验证: `swift test` -> `Executed 122 tests, with 0 failures`；剥离 #Preview 副本 `xcodebuild build` -> `** BUILD SUCCEEDED **`。UI 手测: 待用户在 Xcode 运行——弹层空白/文字区域=箭头，日期格/箭头/今天按钮=手型。
- 回滚点: 还原 CalendarPopoverView.swift 单文件。

## 2026-09-06 - Journal mark still missing: stale binary + paragraph-only text extraction (印记仍缺失二连修)
- 用户反馈「有内容的日期仍无印记」。取证（未改代码先查证据）:
  1. 缓存库 `journal_entries` 无任何 9 月新记录（远端刷新应 upsert 补入）——带上一轮修复的代码没跑过。
  2. DerivedData 最新构建（今日 19:25）的 `WidgetToDo.debug.dylib` 里 `strings` 检查: 有 `CalendarMarkContext`（上上轮）✓、**无 `refreshJournalMarks`（上一轮远端刷新修复）**——结论: 用户测试用的是修复之前的旧二进制（Xcode 未重新构建成功或未重跑）。
- 顺手修复的真实隐患（避免重建后再次「仍无印记」）: `fetchJournalText` 只提取 `paragraph` 类型 block——在 Notion 客户端用标题/列表/引用写的日记正文取出来是空串 → 印记仍不显示。`NotionClient.BlockResponse` 重写为按 `type` 动态解码同名 key 下的 `rich_text`（AnyCodingKey），覆盖 heading_1…3 / bulleted / numbered / quote / to_do / toggle / callout / code 等所有文本类 block；非文本 block（divider 等）跳过；空行保留维持往返保真。删除不再使用的 `ParagraphBlock`。
- 新增测试 `RefreshJournalMarksTests.swift`（2 用例，按 URL 路由的 RoutingMockURLProtocol）: 非 paragraph block（heading_2 + bulleted_list_item + quote）必须算「有内容」、divider-only 页面不算；远端刷新补缓存缺失条目且不覆盖已有条目（含 localPending 状态保持）。
- 验证: `swift test` -> `Executed 122 tests, with 0 failures`；剥离 #Preview 副本 `xcodebuild build` -> `** BUILD SUCCEEDED **`。
- 待用户: 在 Xcode **重新构建并运行**（⌘R 前先确认构建成功，若构建失败会是 TASK-058 宏环境问题需先解决）——打开日记 tab 月历，9 月写过内容的日期应先无后有印记（远端补全约需 1-2 秒/月）。若重建后印记仍缺失，下一怀疑点: 远端请求静默失败（`refreshMonthContentDays` 吞错），届时需加错误上报排查。
- 回滚点: 还原 `NotionClient.swift` + 删 `RefreshJournalMarksTests.swift`。

## 2026-09-06 - Calendar marks remote refresh + day-query fix (印记远端拉取与按日查询修复)
- 排查（用户报告「有日记内容但印记不显示」）: 直接检查本地缓存库 `~/Library/Application Support/NotionFloat/cache.sqlite` 确认两个根因:
  1. 主因: 月历印记只读本地 SQLite 缓存，用户在 Notion 客户端写的日记（app 未查看过的日期）本地无记录 → 印记缺失。缓存库仅 6 条记录、最新停在 8-11。
  2. 次因: `SQLiteCache.journalEntry(for:)` 用完整 ISO 时间戳等值匹配 `WHERE notion_date = ?`，而历史数据混存「本地午夜」（2026-08-10T16:00:00Z）与「UTC 午夜」（2026-05-22T00:00:00Z）两种格式，其中一种永远查不到。任务侧 `loadTasks(for:)` 本就是范围匹配（无此 bug）。
- 修复:
  - `SQLiteCache.journalEntry(for:)` 改为本地自然日范围匹配（`>= dayStart AND < dayEnd`，复用 dayBounds），两种历史格式都能命中，且不越界到相邻日。
  - `NotionClient` 新增两个只读范围查询（用户已确认「打开月历时拉取」策略）: `findJournalEntries(from:to:)`（and filter on_or_after/before + 逐页 fetchJournalText 填充正文，不创建页面）、`queryTasks(from:to:)`（任务一次 query 拿整月，无逐页请求）。
  - `NotionRepository` 新增 `refreshJournalMarks(containing:)` / `refreshTaskMarks(containing:)`: 拉远端当月数据，只把本地缓存缺失的条目补进缓存（已有条目一律不覆盖，避免踩本地未保存编辑/冲突状态），返回 day->有内容。
  - `JournalViewModel.refreshMonthContentDays` / `TodoListViewModel.refreshMonthTaskDays`: 网络失败吞错返回空表（保持缓存印记不变）。
  - `ContentView.reloadCalendarMarks` 改两段式: 第一段本地缓存即时渲染；第二段远端刷新与缓存 OR 合并（远端有内容即点亮），带竞态防护（远端期间翻月/收起/切 tab 则丢弃结果）。
- 新增测试: `Tests/NotionFloatCoreTests/JournalCacheDayQueryTests.swift`（4 用例）: UTC 午夜格式命中、本地午夜格式命中、不越界到相邻日、当天任意时刻写入命中。
- 验证: `swift test` -> `Executed 120 tests, with 0 failures`；剥离 #Preview 副本 `xcodebuild build` -> `** BUILD SUCCEEDED **`。UI 手测: 待用户在 Xcode 验证——打开日记 tab 月历应显示 Notion 里写过内容的日期印记（首开为缓存印记、稍后远端补全）；翻月时旧月远端请求会被取消。
- 已知边界: (1) 远端刷新只补缓存缺失条目——「缓存空但远端有内容」的日期印记会通过 OR 合并正确点亮，但缓存条目本身不更新（下次打开该日日记时 loadOrCreateJournal 会刷新）；(2) 日记印记逐页拉正文，当月页面数多时请求数=页面数（Notion date 范围 query 1 次 + 每页 blocks 1 次）。
- 回滚点: 还原 SQLiteCache/NotionClient/NotionRepository/JournalViewModel/TodoListViewModel/ContentView 六文件 + 删两个新测试文件。

## 2026-09-06 - Calendar marks scoped per tab (印记按模块上下文切换)
- 目标: 月历弹层印记按所在模块显示专属维度——待办 tab 只显示任务印记（棕色圆点），日记 tab 只显示日记印记（蓝色短横），两类印记永不混排；图例与统计条同步只展示对应维度；视觉框架保持一致，靠印记样式（圆点 vs 短横 + 颜色）直观区分内容类型。
- 改动:
  - `WidgetToDo/CalendarPopoverView.swift`: 新增 `CalendarMarkContext` 枚举（todo/journal）与 `context` 属性；`markIndicator` 按 context 只画对应印记（shouldShowMark 过滤，同格永不出现双印记）；header 图例按 context 只显示「● 任务」或「▬ 日记」；footer 统计条按 context 只显示「N 天有任务」或「N 天有日记」（contextMarkDays 只统计对应维度）。
  - `WidgetToDo/ContentView.swift`: 挂载处传 `context: calendarTab == .todo ? .todo : .journal`；`reloadCalendarMarks` 改为按 tab 只查对应数据源（待办只查任务缓存、日记只查日记缓存，非当前维度的 bool 恒 false——省一半只读查询）。
- 验证: `swift test` -> `Executed 116 tests, with 0 failures`；剥离 #Preview 副本 `xcodebuild build` -> `** BUILD SUCCEEDED **`（期间修一个 ViewBuilder 语法错误: @ViewBuilder 内不能先声明 `let` 再用 switch 赋值，改为普通私有函数 shouldShowMark）。UI 手测: 待用户在 Xcode 验证——待办 tab 月历只出棕点、日记 tab 只出蓝横、图例/统计条各自单一维度。
- 回滚点: 还原 CalendarPopoverView.swift + ContentView.swift 两文件即可。

## 2026-09-06 - Calendar popover on date title (方案二·暖纸月历，任务/日记印记)
- 目标: 待办/日记 tab 的日期行，点击日期标题在下方展开月历弹层（定稿 HTML 原型方案二「暖纸」）：按月展示每一天，周一起始，带印记（棕色圆点=当日有任务、蓝色短横=有日记内容，只示有无不示数量）+ 图例 + 今天按钮 + 前后翻月 + 底部统计条；点某天跳转到该日期（复用现有日期切换路径，不新增同步机制）。
- 非目标: 不改 Notion API 契约、不发整月网络请求（印记基于本地 SQLite 缓存，即 app 内加载过的日期）；不动持久化/Keychain；两个 tab 日期保持各自独立。
- 影响路径:
  - 新增 `WidgetToDo/CalendarPopoverView.swift`（月历弹层视图，PBXFileSystemSynchronizedRootGroup 自动入 target）
  - `WidgetToDo/ContentView.swift`：dateNavigationBar 日期标题变可点击 Button（新参数 onDateTap/isCalendarActive，默认值不影响其他调用方）；FloatingWidgetView 增加弹层状态（activeCalendarTab/calendarMonth/calendarMarks）、ZStack 挂载弹层 + 点击外部收起、tab 切换时收起、印记按月缓存加载、点某天走 todoViewModel.load(for:)/journalViewModel.switchDate(to:)
  - `WidgetToDo/TodoListViewModel.swift`：新增只读 `hasCachedTasks(on:)`
  - `WidgetToDo/JournalViewModel.swift`：新增只读 `hasCachedJournalContent(on:)`（contentText 非空才算有日记）
  - `WidgetToDo/Core/Infrastructure/NotionRepository.swift`：新增只读透传 `cachedTasks(for:)`（SQLiteCache.loadTasks 已 public，无行为变更）
  - `WidgetToDo/Core/Services/AppLocalizer.swift`：新增 3 个 key（calendarToday / calendarDaysWithTasks / calendarDaysWithJournal）× 中英法三语
- 验证:
  - 全量: `swift test` -> `Executed 105 tests, with 0 failures`。
  - 构建: 剥离 #Preview 的副本 `xcodebuild build`（沿用已知 PreviewsMacros/swift-plugin-server workaround）-> `** BUILD SUCCEEDED **`；直接构建 Debug/Release 均阻塞于既有 #Preview 宏环境问题（TASK-058 已记录），非本次改动引入。
  - UI 手测: 未执行——需用户在 Xcode 运行验证：(1) 点日期标题弹月历、再点收起、点弹层外收起；(2) 待办/日记两个 tab 弹层各自独立且印记一致；(3) 点某天日期跳转并加载内容；(4) 翻月/今天按钮；(5) 弹层偏移量（x:20/y:100，Metrics 常量）与窗口 340×460 的贴合度可能需微调。
- 风险/回滚点: 印记只反映本地缓存（未在 app 内查看过的日期无印记，属数据源固有限制，非 bug）；NotionRepository 仅新增只读方法无行为变更。回滚: 还原上述 6 文件 + 删除 CalendarPopoverView.swift。
- 已知取舍: 月历无 hover 淡底（macOS 保持克制）；日记印记以缓存 contentText 非空为准（loadOrCreateJournal 会创建空页面，空页面不算有日记）。
- 追加（同日二）: 用户反馈 (1) 日历弹框不要从上往下弹出，要原地从中间弹出；(2) 弹框 UI 希望更有苹果原生质感。修改: 弹层入场 transition 由 `.opacity+.move(edge:.top)` 改为 `.scale(scale:0.92,anchor:.top)+.opacity`（Pop in 原地缩放浮现，无位移），toggle/dismiss 动画由 easeOut 改为 `.spring(response:dampingFraction:)`（弹出 0.32/0.86 带 Q 弹、收起 0.22/0.95 干脆）；弹层背景由纯平色 #FBF9F4 改为苹果原生材质 `.thickMaterial`（厚半透明高斯模糊，像系统 popover/通知中心浮层）+ 极淡漠纸色 overlay(0.42) 保留暖灰语言 + 顶部白色渐变高光描边（0.5pt）+ 柔和多层阴影（0.5/28 两层）。影响文件: `WidgetToDo/CalendarPopoverView.swift`（背景/阴影）、`WidgetToDo/ContentView.swift`（transition/动画）。验证: 剥离 #Preview 副本 `xcodebuild build` -> `** BUILD SUCCEEDED **`。UI 手测: 待用户在 Xcode 运行看材质模糊/弹入质感/暖色调性是否满意（材质在不同壁纸下呈半透明磨砂，暖色 overlay 浓度 0.42 可调）。
- 追加（同日）: 用户反馈月历表头星期错位（显示为「六日一二三四五」）且月首前出现镂空/日期与星期对不上——根因: `veryShortWeekdaySymbols` 旋转方向写反（把周六挪到表头开头），而网格按周一起始摆放，表头与列错开，月首补位空格全部落在错误列。修复: 新增 `WidgetToDo/Core/Services/MonthGridCalculator.swift` 纯计算模块（月首归一、按 firstWeekday 计算前导数、真实连续日期网格 + 相邻月补位凑整周、表头符号按 firstWeekday 旋转），`CalendarPopoverView` 全部委托该计算器；相邻月日期浅灰补位（任何月份不再镂空，行为与 macOS 日历一致），相邻月日期同样可点跳转但无印记。新增 `Tests/NotionFloatCoreTests/MonthGridCalculatorTests.swift`（11 用例）: 列↔真实星期一致性（跨 2023–2100 九个月份）、2026年7月（周三起始 lead=2）/8月（周六起始 lead=5）锚点、闰年 2024-02（29 天含 2/29）、平年 2023-02（28 天且 2/28 下一天是 3/1）、百年闰 2000-02（29 天）/平年百年 2100-02（28 天）、跨年 2026-12→2027-01 滚动、日期严格连续（86400s）、isInMonth 计数、表头符号两种 firstWeekday 旋转。时区: app 跟随系统本地时区，测试固定 UTC 保证确定性。验证: `swift test` -> `Executed 116 tests, with 0 failures`（新增 11 用例全过，期间修掉一个测试自身陷阱——平年不能用 date(2023,2,29) 断言，Calendar 会归一化成 3/1）；剥离 #Preview 副本 `xcodebuild build` -> `** BUILD SUCCEEDED **`。UI 手测: 待用户在 Xcode 运行核对月历表头为「一二三四五六日」且无镂空。

## 2026-09-06 - Frequent chip rail restyled to tinted (淡底) design per finalized HTML prototype
- 目标: 按定稿 HTML 原型（v2.2「淡底」方案）调整高频任务标签行的视觉样式：中性暖灰淡底 chip + 细描边 + hover 底色加深，行标签改为小竖条 + 加宽字距样式。纯 UI 调整，不改任何功能/交互逻辑。
- 非目标: 不改点击行为、滚动/溢出箭头逻辑、数据链路（`FrequentTaskName`、store、scorer 均不动）；不动其他文件配色。
- 影响路径: 仅 `WidgetToDo/FrequentTaskChipRail.swift`（L1 单文件）——`FrequentChipPalette` 配色从白底改为淡底（fill #F5F2EB / hover #EEE9DD / border #EAE5D9 / 文字 #4A453D）；`chip` 增加 `hoveredIndex` hover 态（onHover + 0.18s 动画）；行标签增加 3×10 竖条（#D8D1C2）与 0.6 tracking。
- 验证:
  - 全量: `swift test --disable-sandbox` -> `Executed 105 tests, with 0 failures`。
  - smoke: `swift run --disable-sandbox NotionFloatCoreSmokeTests` -> `All smoke tests passed.`（chip 行契约断言结构而非配色，不受影响）。
  - 构建: 剥离 #Preview 的副本 `xcodebuild build`（沿用已知 workaround，本机 CLI 直跑因 PreviewsMacros/swift-plugin-server 异常必失败）-> `** BUILD SUCCEEDED **`。
  - UI 手测: 待用户在 Xcode 运行验证——(1) chip 为暖灰淡底非纯白；(2) 鼠标悬停 chip 底色加深；(3) 行标签前有小竖条。
- 风险/回滚点: 单文件纯视觉改动，`git checkout -- WidgetToDo/FrequentTaskChipRail.swift` 即回滚。已知取舍: hover 无上浮/阴影（macOS 上保持克制），仅底色反馈。
- 追加（同日）: 用户反馈"标签好像有阴影"——chip 本身无阴影，阴影来自溢出箭头小圆钮（arrowShadow opacity 0.16/radius 3）；按用户意见移除箭头阴影及 `arrowShadow` 色值，箭头保留淡底+描边。表单「常用」行与主窗口「快速添加」行共用同一组件，淡底样式两处已同步生效，无需单独改表单。追加验证: smoke -> All passed；全量 105/0；剥离 #Preview 副本 xcodebuild -> BUILD SUCCEEDED。
- 追加（同日·二）: 用户确认去掉 chip 描边——chip 只保留淡底色块（无描边、无阴影）；箭头小圆钮改为独立配色（白底 + 原 #E2DBC9 系描边），因其浮在 chip 上滚动需要分层。期间磁盘文件再次被 IDE 旧缓冲部分覆盖（hover 态与竖条标签丢失），整文件重写为最终状态。验证: smoke -> All passed；全量 105/0；剥离 #Preview 副本 xcodebuild -> BUILD SUCCEEDED。

## 2026-09-06 - Fix unused-result warning in AppCoordinator drain callback
- 目标: 消除 `AppCoordinator.swift:56` 的编译警告 "Result of call to 'run(resultType:body:)' is unused"。
- 根因: `await MainActor.run { Task { @MainActor in ... } }` —— 闭包体只有一条 Task 表达式，闭包把 Task 作为返回值传出、`MainActor.run` 再返回给调用方后被丢弃；包装层本身多余。
- 修复: `WidgetToDo/AppCoordinator.swift` MutationSyncScheduler 回调内去掉 `MainActor.run` 包装，直接 `Task { @MainActor in ... }`（fire-and-forget 主线程刷新语义不变，且 scheduler 的 drain 不再为创建 Task 等一次主线程跳转）。
- 验证: `swift test --disable-sandbox` -> 86/0；剥离 #Preview 的副本 `xcodebuild build` -> BUILD SUCCEEDED，AppCoordinator 无警告残留（AppCoordinator 为 app 层源文件，swift test 不编译，沿用副本编译验证 workaround）。
- 风险/回滚: 单文件小改，无持久化/API 变更；还原该文件即可。

## 2026-09-06 - Frequent chips carry task type (能力维度) on quick add & form fill
- 目标: 「快速添加」与表单「常用」标签在成功添加时记录对应任务类型（能力维度 choice 值），之后一键还原：快速添加直接以记录的类型创建；表单点常用 chip 时连标题带类型一起填入。
- 非目标: 不改 Notion API 契约（类型即 createTask 的 priority choice 参数，沿用既有链路）；标签上不显示类型文字；不做按类型分组的统计。
- 影响路径:
  - `Core/Services/TaskNameFrequencyScorer.swift`: `TaskNameUsage` 新增 `lastPriority: String?`（旧 JSON 无该 key 解码为 nil，向后兼容）；新增 `FrequentTaskName { name, priority }` 与 `topEntries` 接口。
  - `Core/Infrastructure/TaskNameFrequencyStore.swift`: `record(name:priority:now:)` 记录最近使用类型（每次覆盖为最新）；`topNames` → `topEntries` 返回带类型的条目。
  - `TodoListViewModel.swift`: `frequentTaskNames` 类型改为 `[FrequentTaskName]`；`onCreateSuccess` 记录 `task.title + task.priority`；`quickAddTask(_ entry:)` 携带类型。
  - `NewTaskViewModel.swift`: `quickAdd(title:priority:date:)` 将类型传给 `createTask`（`hasPriorityField: choiceField != nil` 沿用既有判断）。
  - `FrequentTaskChipRail.swift`: 入参 `names: [String]` → `entries: [FrequentTaskName]`，chip 文案仍只显示任务名。
  - `NewTaskFormCard.swift`: 常用 chip 点击填入标题；若记录了类型则同时填入 `viewModel.priority`，未记录过类型不覆盖当前选择（避免清空用户已选值）。
  - 测试: ScorerTests +1（topEntries 携带类型）、StoreTests 重写为带 priority 签名并 +4 用例（覆盖最新类型覆盖、topEntries 携带类型、旧 JSON 兼容）；smoke 契约 `frequentTaskQuickAddKeepsContract` 更新为带类型链路（+2 断言）。
- 状态: 代码与全部自动化验证完成；UI 手测待用户验证。
- 验证:
  - 全量: `swift test --disable-sandbox` -> `Executed 105 tests, with 0 failures`（上一轮 101 + 净增 4）。
  - smoke: `swift run --disable-sandbox NotionFloatCoreSmokeTests` -> `All smoke tests passed.`（含更新后的带类型契约）。
  - 构建: `xcodebuild build` -> `** BUILD SUCCEEDED **`。
  - UI 手测: 待用户验证——(1) 表单里选类型创建任务后，再点快速添加 chip，新任务应带上同类型；(2) 表单点常用 chip，类型选择器应自动选中记录的类型；(3) 旧统计数据（无类型）不崩溃，chip 行为等同未记录类型。
- 风险/回滚点: 纯增量改动，无 API/持久化结构破坏（lastPriority 为 optional 新字段，旧文件自动兼容）。回滚还原本次 6 个修改文件即可。已知取舍: 类型记录的是「最近一次」而非各类型分别计数（同名任务换类型创建后，chip 跟随最新类型）。

## 2026-09-06 - Frequent task name quick-add chips (top 5, time-decay scoring)
- 目标: 统计「成功创建」的任务名，按时间衰减评分取 Top 5，在两处提供快捷标签行方便快速添加任务：主窗口日期行下方「快速添加」行（点击跳过表单直接以默认值创建）、新建任务表单标题输入框下方「常用」行（点击填入标题可继续编辑）。两处均为单行横向排列，放不下时两侧出现悬浮圆形箭头（HTML 原型 S1 方案，用户已确认），点击平滑滑动；标签不带次数角标。
- 非目标: 不改 Notion API 契约；不触碰 Keychain/SQLite/settings.json 既有持久化；不改 Package.swift/.xcodeproj（新文件经 PBXFileSystemSynchronizedRootGroup 自动同步）；不做手动置顶/收藏。
- 影响路径:
  - 新增 `WidgetToDo/Core/Services/TaskNameFrequencyScorer.swift`: 纯评分逻辑，`score = count × 0.5^(距上次使用天数/7)`（7 天半衰期，老任务名不霸榜）；排序规则 评分降序→最近使用优先→字典序。
  - 新增 `WidgetToDo/Core/Infrastructure/TaskNameFrequencyStore.swift`: actor，独立 JSON 持久化（`Application Support/NotionFloat/task-name-frequency.json`），去空白合并同名，磁盘失败静默降级为内存模式。
  - 新增 `WidgetToDo/FrequentTaskChipRail.swift`: 标签行组件（SwiftUI），`onScrollGeometryChange` 跟踪溢出状态，ScrollViewReader 按平均宽度估算目标索引平滑滑动。
  - 修改 `WidgetToDo/TodoListViewModel.swift`: 新增 `frequentTaskNames`（@Published, top5）、`quickAddTask(title:)`；`onCreateSuccess` 钩子记录任务名并刷新；init 注入 store（默认值，调用点无感）。
  - 修改 `WidgetToDo/NewTaskViewModel.swift`: 新增 `quickAdd(title:date:)`，复用 submit 的 pending→成功/失败回调链路，默认无优先级/时长。
  - 修改 `WidgetToDo/ContentView.swift`: todoPanel 日期行下方接入「快速添加」行；`NewTaskFormCard` 调用点传入 `frequentTaskNames`；新增 `quickAddRailBottomSpacing` 常量。
  - 修改 `WidgetToDo/NewTaskFormCard.swift`: 标题输入框下方接入「常用」标签行（`frequentTaskNames` 参数，默认 []）。
  - 修改 `WidgetToDo/Core/Services/AppLocalizer.swift`: 新增 `.quickAddSection` / `.frequentTaskSection` 词条（简中/英/法）。
  - 新增 `Tests/NotionFloatCoreTests/TaskNameFrequencyScorerTests.swift`（8 用例）与 `TaskNameFrequencyStoreTests.swift`（7 用例）。
  - 修改 `Tests/NotionFloatCoreSmokeTests/main.swift`: 更新 `newTaskFormKeepsCreateTaskContract`（表单卡调用新签名）；新增 `frequentTaskQuickAddKeepsContract`（两处标签行 + 记录链路 + S1 溢出箭头契约）。
- 设计要点: 快速添加默认日期=当前查看日期（selectedDate），走 pendingTask 乐观插入与失败高亮既有链路；统计只记 `onCreateSuccess`（表单创建与快速添加共用该钩子）；store 磁盘错误静默降级不影响任务创建流程。
- 状态: 代码与全部自动化验证完成；UI 手测待用户在 Xcode 运行验证。
- 验证:
  - 单测: `swift test --filter TaskNameFrequencyScorerTests` -> 8/8 通过；`--filter TaskNameFrequencyStoreTests` -> 7/7 通过。
  - 全量: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` -> `Executed 101 tests, with 0 failures`（原 86 + 新 15）。
  - smoke: `swift run --disable-sandbox NotionFloatCoreSmokeTests` -> `All smoke tests passed.`（含新契约；期间捕获并修复英文词条遗漏、表单卡契约更新两处）。
  - 构建: `xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build` -> `** BUILD SUCCEEDED **`（非沙箱执行，产物在 /private/tmp/WidgetToDoFreqDerivedData）。
  - UI 手测: 待用户验证——(1) 创建几次同名任务后，主窗口日期行下方出现「快速添加」标签行，点标签直接入列并 toast；(2) 打开新建表单，标题下方出现「常用」行，点标签自动填入可改；(3) 标签超过一行时行尾出现圆形 › 箭头，点击滑动，滑出后行首出现 ‹；(4) 7 天前的旧任务名权重减半，新习惯用几次可进榜。
- 风险/回滚点: 无 Notion API 与既有持久化变更；统计文件为新增独立 JSON，删除即重置。回滚还原上述 5 个修改文件并删除 3 个新增源文件与 2 个测试文件即可。已知取舍: 箭头点击目标索引按平均宽度估算，长任务名混排时步进不精确（视觉可接受）；标签行初始为空（统计从零开始），首日体验依赖用户实际创建行为。

## 2026-09-06 - Journal date switch UX: instant loading feedback + disable nav while loading
- 目标: 修复日记 tab 切换日期时的体验问题——`switchDate` 先 `await forceSave()`（网络保存，慢则数秒）再 `load(for:)`，期间既不更新日期标题也不显示加载态，用户面对无反馈死等误以为"该日期没有日记"；加载中箭头可连点，产生并发无效请求。
- 非目标: 不改 Notion API 契约与持久化；不改 Package.swift/.xcodeproj；不动待办侧加载逻辑（仅对称接入禁用参数）。
- 影响路径:
  - 修改 `WidgetToDo/JournalViewModel.swift`：`switchDate(to:)` 重排——入口立即 `loadGeneration += 1` 快照、`selectedDate = target`、`isLoading = true`（点击瞬间日期标题更新 + 加载态出现），再 `await forceSave()`（保存走 entry.id/entry.date，不受 selectedDate 提前变化影响），代际守卫防过期落地，最后 `load(for: target)`；`isShowingToday` 等其余逻辑不变。
  - 修改 `WidgetToDo/ContentView.swift`：`dateNavigationBar` 新增 `isLoading: Bool = false` 参数——左右箭头 `.disabled(isLoading)` + `.opacity(isLoading ? 0.4 : 1)`，「回到今天」`.disabled(isLoading)`；待办与日记调用点各自传入 `todoViewModel.isLoading` / `journalViewModel.isLoading`（两 tab 日期仍独立，仅共享组件样式）；日记头部「刷新」「打开 Notion」按钮加载中也禁用。
  - 更新 `Tests/NotionFloatCoreSmokeTests/main.swift`：新增 `journalDateSwitchShowsImmediateLoadingFeedback()` 契约（switchDate 在 forceSave 之前设置 selectedDate+isLoading；dateNavigationBar 接受 isLoading；>=3 处 .disabled(isLoading)；两 tab 各自传入；日记头部按钮 >=2 处禁用），并注册进运行列表。
- 设计要点: 即时反馈放在 View 层状态而非延迟到网络返回；forceSave 期间编辑器已被加载态替换，避免旧内容误导；代际守卫确保 forceSave 期间再次切换日期时旧流程静默退出、isLoading 由最新流程收尾（不卡加载态）。
- 状态: 代码与自动化验证完成；UI 瞬态手测存在环境阻塞（见下），待用户手动回测。
- 验证:
  - 全量: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` -> `Executed 86 tests, with 0 failures`。
  - smoke: `DEVELOPER_DIR=... swift run --disable-sandbox NotionFloatCoreSmokeTests` -> `All smoke tests passed.`（含新契约）。
  - 编译验证(沙箱阻塞 workaround): 本会话起 xcodebuild 在 TRAE 沙箱内必败（`#Preview` 宏的 swift-plugin-server IPC 被拦截，7 个宏错误；requires_approval 也仍走沙箱）。改用副本验证: rsync 仓库至 /tmp/wtd_nopreview，用 /tmp/strip_previews.py 剥离 6 个文件的 #Preview 块（括号配平），对副本 `xcodebuild build` -> `** BUILD SUCCEEDED **`。#Preview 仅影响 Xcode 预览，不影响运行时行为，副本编译可证明本次改动（JournalViewModel/ContentView 均为 app 层源文件，`swift test` 不覆盖）编译通过。
  - 运行时: 副本构建产物已启动（PID 37091，运行 1 分钟+无崩溃、无错误日志）。
  - UI 手测阻塞说明: 会话早期可用的 computer_use 桌面自动化子代理现已不可用（Task 工具报 subagent_type 无效）；`screencapture` 被屏幕录制权限拒绝；无法自行点击/截图验证瞬态加载效果。待用户手动验证: 日记 tab 点左箭头应立即(1)日期标题变(2)出现"正在加载日记…"转圈(3)箭头淡化禁用；加载完成后内容出现、箭头恢复；加载中连点无效；待办 tab 日期不受影响。
- 风险/回滚点: 无持久化与 API 变更；回滚还原 `JournalViewModel.swift` / `ContentView.swift` / `Tests/NotionFloatCoreSmokeTests/main.swift` 三处。/tmp/wtd_nopreview 与 /private/tmp/WidgetToDoNoPreviewDerived 为临时验证产物，可随时删除。

## 2026-09-06 - Remove todo/journal date synchronization (independent per-tab dates)
- 目标: 按用户要求移除日记 tab 与待办 tab 的日期联动同步——两个 tab 的日期各自独立，互不影响；统一日期切换组件（左右箭头 + 日期 + 回到今天）保留，但状态与动作由各 tab 自己的 ViewModel 提供。
- 非目标: 不改 Notion API 契约与持久化；不改 Package.swift/.xcodeproj；JournalViewModel 的 loadGeneration 过期响应守卫保留（日记自身快速切日期仍需要）。
- 影响路径:
  - 修改 `WidgetToDo/ContentView.swift`：`dateNavigationBar` 参数化（title / isShowingToday / onPreviousDay / onNextDay / onJumpToToday + trailing actions），待办与日记各自传入自己的状态与动作；删除统一的 `switchDay(by:)` / `jumpToToday()` 联动方法；新增 `journalTitle`（复用 TodoDateDisplayFormatter + 语言）；删除不再使用的 `calendar` 属性。
  - 修改 `WidgetToDo/JournalViewModel.swift`：新增 `isShowingToday` 计算属性（与待办侧语义一致）。
  - 更新 `Tests/NotionFloatCoreSmokeTests/main.swift`：`journalDateUsesSelectedLanguage()` 契约更新——`dateNavigationBar(` 参数化调用 >= 2 处、`title: todoTitle` 与 `title: journalTitle` 并存、各 tab 走各自 VM 的 showPreviousDay、禁止 `switchDay` / `journalViewModel.switchDate(to: target)` / `todoViewModel.load(for: target)` 耦合写法回归。
- 设计要点: Model 层两 VM 本就各自持有 `selectedDate`，联动只存在于 View 层入口；移除后待办恢复原始的 `todoViewModel.showPrevious/NextDay/jumpToToday` 直调路径，日记走 `journalViewModel` 同名方法；`reloadFromNotion` 仍按日记自身 selectedDate 刷新。
- 状态: 代码与全部自动化验证完成；UI 手测待用户在 Xcode 重新运行验证（本机留有用户自己的 Xcode 实例运行旧代码，未代为终止）。
- 验证:
  - 全量: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` -> `Executed 86 tests, with 0 failures`。
  - smoke: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` -> `All smoke tests passed.`（含更新后的日期契约）。
  - 构建: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoDateLinkDerivedData build` -> `** BUILD SUCCEEDED **`。
  - UI 手测: 待用户验证——待办切到昨天后切日记 tab，日记应仍停在自己之前选中的日期（不同步）；两侧各自切日期互不影响。
- 风险/回滚点: 无持久化与 API 变更；回滚还原 `ContentView.swift` / `JournalViewModel.swift` / `Tests/NotionFloatCoreSmokeTests/main.swift` 三处即可。

## 2026-09-06 - Journal date link: discard stale load responses (date/content mismatch fix)
- 目标: 修复用户反馈"日期能切换，但日记内容没有对应上该日期"。根因: `JournalViewModel.load(for:)` 与 `reloadFromNotion()` 均无过期响应保护——快速连续切换日期时多个加载并发乱序完成，旧日期的响应后到会用旧日期的 entry/editorText 覆盖当前日期，造成日期标题与日记内容错位（此后输入还会写错页面）；刷新途中切日期存在对称竞态。
- 非目标: 不改 Notion API 契约与持久化；不改 Package.swift/.xcodeproj（曾尝试在 NotionFloatCoreTests 新增 JournalViewModel 单测，因 VM 在 app 层不在 SPM target 内而放弃，未改 target 结构）；不引入 Task 取消（改动面大）。
- 影响路径:
  - 修改 `WidgetToDo/JournalViewModel.swift`：新增 `loadGeneration` 代际计数；`load(for:)` 与 `reloadFromNotion()` 发起前 `loadGeneration += 1` 快照代际，响应归来（成功/失败/决策落地前）`guard generation == loadGeneration else { return }` 丢弃过期结果（共 4 处守卫）；移除两处 `defer { isLoading = false }`，改为最新一次加载自己收尾（过期分支不代为复位 loading，避免新加载被误标结束）。
  - 更新 `Tests/NotionFloatCoreSmokeTests/main.swift`：新增 `journalDateLinkDiscardsStaleLoadResponses()` 源码契约（loadGeneration 存在、≥3 处 stale 守卫、发起前 bump、禁用 defer isLoading），并注册进运行列表。
- 设计要点: 代际守卫在"成功落地 entry/editorText 之前"与"失败写 errorMessage 之前"都生效，过期响应完全不触碰状态；`switchDate` 先 forceSave 再加载的顺序不变，未保存编辑仍先落旧日期页面。
- 状态: 代码与全部自动化验证完成；单次切换路径已桌面实测正常；快速连点竞态场景的桌面自动化验证被用户中止，待用户手动回测。
- 验证:
  - 复现: 桌面自动化在修复前实测单次切换（今天→昨天→前天→回今天）内容均正确跟随日期，确认错位仅出现在乱序竞态场景。
  - 全量: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` -> `Executed 86 tests, with 0 failures`。
  - smoke: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` -> `All smoke tests passed.`（含新契约）。
  - 构建: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoDateLinkDerivedData build` -> `** BUILD SUCCEEDED **`；新构建已启动运行（进程 21027）。
  - UI 手测（竞态场景）: 待用户手动验证——日记 tab 快速连点左右箭头多次后停 2-3 秒，日期与内容须一致（空日期只显示占位），切回今天内容恢复。
- 风险/回滚点: 无持久化与 API 变更；回滚还原 `JournalViewModel.swift` 与 `Tests/NotionFloatCoreSmokeTests/main.swift` 两处即可。

## 2026-09-06 - Journal/todo date-linked switching with shared date navigation bar
- 目标: 日记 tab 与待办 tab 日期联动切换——设计统一日期切换组件（左右箭头 + 当前日期 + 回到今天），两个 tab 共享同一日期，任一侧切换另一侧同步；日记支持加载任意日期（此前仅"今日"）。
- 非目标: 不改 Notion API 契约与持久化（`loadOrCreateJournal(for:)` / `saveJournal(entryID:text:date:)` 已支持任意日期，零改动）；不动 mini 模式与冲突合并逻辑。
- 影响路径:
  - 修改 `WidgetToDo/JournalViewModel.swift`：新增 `selectedDate`（private(set) @Published，init 归一化到当天零点）；`load(for:)` 按日期加载；`switchDate(to:)` 先 `forceSave()` 落盘未保存编辑再加载（不丢输入）；`showPreviousDay/showNextDay/jumpToToday`；`reloadFromNotion()` 改用 `loadOrCreateJournal(for: selectedDate)`。
  - 修改 `WidgetToDo/ContentView.swift`：新增 `dateNavigationBar<Actions>` 统一日期切换组件（左右箭头 + `todoTitle` + 条件「回到今天」+ trailing actions），`todoToolbar` 与 `journalPanel` header 共用；新增联动入口 `switchDay(by:)` / `jumpToToday()`（以 `todoViewModel.selectedDate` 为唯一真源，同时驱动两个 VM）；日记 header 不再依赖 `entry` 存在（日期恒显示）；删除无引用的 `journalDateString(from:)`。
  - 更新 `Tests/NotionFloatCoreSmokeTests/main.swift`：`journalDateUsesSelectedLanguage()` 守卫从"独立 journalDateString + entry.date"旧契约更新为"dateNavigationBar 统一组件 + 复用 TodoDateDisplayFormatter/语言/样式"新契约。
- 设计要点:
  - 日期唯一真源为 `todoViewModel.selectedDate`，日记侧显示与切换均引用它，两侧永不分叉；`RootViewModel.refreshWorkspace` / `MutationSyncScheduler` 无需改动（联动入口保证两 VM selectedDate 一致）。
  - 切日期前 `forceSave()`：防抖/在途保存先写完旧日期页面再换 entry；`load(for:)` 后 `editorText == entry.contentText`，`scheduleAutosave` 的空闲守卫防止回填触发伪保存。
  - 日记加载失败时保留旧 entry（后续编辑仍写回旧页面，不会写错），仅提示错误，与待办侧"失败清空列表"行为差异保持既有约定。
- 状态: 已完成；全量测试、smoke、构建、UI 手测均通过。
- 验证:
  - 全量: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` -> `Executed 86 tests, with 0 failures`。
  - smoke: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` -> `All smoke tests passed.`
  - 构建: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoDateLinkDerivedData build` -> `** BUILD SUCCEEDED **`（沙箱内 `#Preview` 宏 IPC 会被拦截，须非沙箱执行，与 2026-09-06 上一条目记录一致）。
  - UI 手测（桌面自动化实测新构建 app）: 待办右箭头 9月6日→9月7日且出现「回到今天」；切日记 tab 日期仍 9月7日（联动同步，箭头可用）；日记左箭头 → 9月5日；「回到今天」→ 9月6日；切回待办日期同步 9月6日、任务列表恢复。7/7 步 PASS。
- 风险/回滚点:
  - 切日期时日记串行执行 forceSave + 加载，慢网下连续快速点击箭头会排队执行（async Task 串行 await，不会竞态写错页面，但 UI 响应可能滞后）。
  - 回滚：还原 `JournalViewModel.swift` / `ContentView.swift` / `Tests/NotionFloatCoreSmokeTests/main.swift` 三处即可；无持久化与 API 变更。

## 2026-09-06 - Edit-aware journal sync: never overwrite in-progress edits
- 目标: 修复日记编辑中内容被同步覆盖丢失的问题。用户正在输入时，头部刷新按钮 / 日记刷新按钮触发的同步会用远端内容覆盖 `editorText`，且 `load()` 不取消防抖、不等待在途保存——覆盖后 SwiftUI `onChange` 以远端文本再次触发 `scheduleAutosave`，取消掉用户待保存文本的入队，导致输入永久丢失；`reloadFromNotion()` 旧实现直接 `debounceTask?.cancel()` 也会丢弃最近 ≤2 秒输入。
- 非目标: 不改 Notion API 契约、SQLiteCache/Keychain/SettingsStore 持久化行为、Package.swift/.xcodeproj；不改任务列表同步；不做云端三方合并算法（仅提供本地+云端追加合并）。
- 影响路径:
  - 新增 `WidgetToDo/Core/Services/JournalSyncConflictEngine.swift`：纯决策引擎，输入 `JournalSyncContext`（本地文本/远端文本/是否有未落盘编辑/最近保存是否失败）→ 输出 `applyRemote / keepLocal / conflict`。
  - 重写 `WidgetToDo/JournalViewModel.swift`：`reloadFromNotion()` 改为编辑感知——先把防抖文本立即 `enqueueSave(text: editorText)` 入队（不丢弃）并 `await saveTask.value` 等待在途保存，再拉取远端，由引擎决策；新增 `hasUnsavedEdits` 检测（防抖中/在途/待写队列/保存失败/文本与已同步不一致）、`conflict` 发布属性、`resolveConflictKeepingLocal/UsingCloud/ByMerging()` 三个冲突解决方法；`scheduleAutosave` 增加守卫（文本与已同步内容一致且管道空闲时跳过，防止同步回填触发伪自动保存）；`load()` 保留仅供 bootstrap。
  - 修改 `WidgetToDo/ContentView.swift`：`refreshWorkspace()` 的 `journalViewModel.load()` 改为 `reloadFromNotion()`（编辑感知路径）；journalPanel 新增 `journalConflictBanner`（警告色提示条：保留本地 / 使用云端 / 合并内容）。
  - 修改 `WidgetToDo/Core/Services/AppLocalizer.swift`：新增 5 个 key（journalEditsKeptDuringSync / journalConflictNotice / journalConflictKeepLocal / journalConflictUseCloud / journalConflictMerge），简中/英/法三语补齐。
  - 更新 `Tests/NotionFloatCoreSmokeTests/main.swift`：日记刷新守卫改为新契约（flush-before-fetch、引擎决策、hasUnsavedEdits、三个冲突解决方法、refreshWorkspace 禁用裸 load）；同时修复 2 个陈旧守卫（type picker / edit picker 的 `.frame(height: optionsListHeight)` 断言，commit 215aa87 已移除该写法但守卫未同步，2026-08-23 条目已记录该存量失败）。
  - 新增 `Tests/NotionFloatCoreTests/JournalSyncConflictEngineTests.swift`（6 用例：无编辑→applyRemote、拉取期间输入→keepLocal、保存失败且远端分叉→conflict、写成功响应超时远端一致→keepLocal、防抖中永不冲突、无编辑文本相同→applyRemote）。
- 设计要点:
  - 决策时点在拉取远端之后：拉取期间用户继续输入会被 `hasUnsavedEdits` 捕获，判定 keepLocal 而非伪冲突。
  - conflict 仅在"本地保存失败 && 远端 != 本地"时触发：写成功但响应超时（云端与本地一致）不弹冲突。
  - keepLocal 只更新 entry 元数据与提示文案，不触碰 editorText；本地后续自动保存会推进同步。
  - "使用云端"直接回填刚拉取的远端文本（与 entry.contentText 一致，守卫使其不触发多余写回）；"合并"为本地 + `———` 分隔 + 云端追加，走正常自动保存。
- 状态: 代码与全部自动化验证完成；UI 手测待用户在 Xcode 运行确认。
- 验证:
  - 全量: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` -> `Executed 86 tests, with 0 failures`（含新增 6 个决策引擎用例）。标准入口 `swift test` 仍阻塞于既有 sandbox-exec 环境问题。
  - smoke: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` -> `All smoke tests passed.`（含更新的日记守卫；2 个陈旧守卫修复后整套恢复绿色）。
  - 构建: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoJournalSyncDerivedData4 build` -> `** BUILD SUCCEEDED **`。注意：在 Trae 命令沙箱内运行 xcodebuild 会导致存量 `#Preview` 宏展开失败（swift-plugin-server IPC 被拦截），须在非沙箱终端执行（已用改动前工作区复现确认与代码无关）。
  - UI 手测（待用户）: ① 输入中点头部刷新/日记刷新按钮 → 文本不丢失、状态提示"正在编辑，已保留本地内容"；② 断网写日记（保存失败）→ 在 Notion 网页端改同一篇日记 → 恢复网络点刷新 → 出现冲突提示条，三个选项行为正确；③ 弱网下边输入边刷新 → 输入不中断。
- 风险/回滚点:
  - `refreshSyncStatus()`（后台重试链路）未动，行为与 2026-08-23 条目一致（不触碰 editorText）。
  - 冲突提示条出现在编辑器与状态行之间，日记面板高度会临时增加；不影响布局约束（VStack 自适应）。
  - 回滚：还原 JournalViewModel.swift / ContentView.swift / AppLocalizer.swift / main.swift 四处修改，删除 JournalSyncConflictEngine.swift 与 JournalSyncConflictEngineTests.swift 即可；无持久化与 API 变更。

## 2026-08-23 - Auto-retry pending mutations on launch and network recovery
- 目标: 待定变更队列（PendingMutation）实现自动重放：App 启动时 flush 一次、网络恢复时（NWPathMonitor）自动重试；401/403 不重试并停止；同一目标 last-write-wins 只重放最新一条；已被更新内容取代或目标已不存在的旧变更跳过并结案。对应 Reddit 反馈承诺的"flush on next launch + retry when network comes back"。
- 非目标: 不做 429 指数退避（drain 首次失败即停、等下次触发，等效简单退避）；不改 Notion API 契约、SQLite 表结构、字段映射与令牌存储；不改 UI 布局；不新增用户可见设置项。
- 影响路径:
  - 修改 `WidgetToDo/Core/Infrastructure/SQLiteCache.swift`：新增 `pendingMutations(statuses:)` 读取（queued+failed，按 created_at/rowid 升序）与 `readPendingMutation` 解码；`markMutation` 等既有方法未动。
  - 修改 `WidgetToDo/Core/Infrastructure/NotionRepository.swift`：新增 `drainPendingMutations()`（last-write-wins、已同步跳过、401/403 停止、失败保留队列）、`PendingMutationDrainResult` 类型、`cachedJournal(id:)` 按 entryID 读缓存（规避同日多页坑）。
  - 新增 `WidgetToDo/Core/Services/MutationSyncScheduler.swift`：纯逻辑 actor，去抖（默认 5s）+ 串行 drain + drain 期间触发排队追加一轮；clock 可注入。
  - 修改 `WidgetToDo/AppCoordinator.swift`：init 末尾构造 scheduler（闭包捕获局部 repository/rootViewModel，避免 init 中捕获未初始化 self）；`start()` 中启动后 requestDrain + NWPathMonitor `.satisfied` 时 requestDrain；drain 有重放时仅刷新任务列表与日记同步状态。
  - 修改 `WidgetToDo/JournalViewModel.swift`：新增 `refreshSyncStatus()`，按 entryID 读缓存只更新 entry/提示文案，不触碰 editorText（防打断输入）；有待保存编辑时跳过。
  - 新增 `Tests/NotionFloatCoreTests/PendingMutationDrainTests.swift`（7 个用例：重放勾选、last-write-wins、已同步跳过、失败保留、401 停止、未配置不动队列、目标不存在跳过）、`Tests/NotionFloatCoreTests/MutationSyncSchedulerTests.swift`（3 个用例：去抖、窗口外再触发、drain 中排队追加一轮）。
- 设计要点:
  - 被同目标更新变更取代的旧条目在 drain 开头统一结案（标记 synced + "已被更新的变更取代"），避免队列无限累积。
  - 重放前检查目标缓存记录：`syncStatus == .synced` 说明已有更新内容同步成功，旧变更作废跳过；记录不存在（任务已删除）也跳过，均不发起网络请求。
  - 401/403 时停止整个 drain 且不清队列（token 失效后续请求必然失败，需重新授权）；其余错误（网络/限流）同样立即停止，队列保留等下次触发。
  - UI 刷新只调 `todoListViewModel.load()` + `journalViewModel.refreshSyncStatus()`，不走 `refreshWorkspace()` 整页 reload，避免后台重试打断正在输入的日记。
- 状态: 代码完成；自动化验证通过（全量 XCTest 80 过，含新增 10 个）。App target xcodebuild 构建被环境问题阻塞（详见验证），UI 手测待用户在 Xcode 运行确认。
- 验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` -> `Executed 80 tests, with 0 failures`（含新增 PendingMutationDrainTests 7 个、MutationSyncSchedulerTests 3 个）。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -destination 'platform=macOS' -configuration Debug build` -> BLOCKED：全部错误为 `ContentView.swift` 存量 `#Preview` 宏展开失败（`swift-plugin-server produced malformed response`，15 处）；已用干净 HEAD worktree 复现同样 15 处错误，确认与本次改动无关（本次未改 ContentView.swift，AppCoordinator/JournalViewModel 文件级编译已通过，失败仅在模块 emit 阶段）。怀疑与当前终端环境 `~/Library/org.swift.swiftpm` 不可写有关。
  - `swift run --disable-sandbox NotionFloatCoreSmokeTests` -> 在存量已知失败守卫处停止（`type picker should reserve visible height`，progress.md 上一条已记录与代码无关），未执行到新增守卫（本次未新增 smoke 守卫）。
  - UI 手测（待用户）: ① 断网勾选任务/写日记 -> 重启 App + 恢复网络 -> 变更自动同步到 Notion；② 断网写日记 -> 不重启、直接恢复网络 -> 自动同步；③ 重放期间不打断正在输入的日记文本。
- 风险/回滚点:
  - 网络恢复触发为一次性 drain（去抖 5s），网络频繁抖动时最多每 5s 一轮重放，每轮首败即停，不会请求风暴。
  - journal 重放以 mutation payload 为准（队列里最新意图），若用户在失败后继续编辑，新编辑会产生新 mutation，仍按最新重放；极端情况下（失败后无新编辑）重放文本与 cache/编辑器一致。
  - 回滚：还原 4 个修改文件 + 删除 2 个新测试文件与 `MutationSyncScheduler.swift` 即可；无数据迁移、无表结构变更，`pending_mutations` 表语义向后兼容（旧数据仍可被 drain 消费）。

## 2026-08-15 - Enter key triggers begin focus in pomodoro start dialog
- 目标: 在「开始进行专注」弹框中按回车触发与点击「确定」完全相同的专注启动逻辑；弹框关闭时回车不产生任何影响；自定义分钟输入框聚焦时按回车也能启动专注。
- 非目标: 不改其他番茄钟弹框（暂停/放弃/结束等）的键盘行为、不改 ViewModel 业务逻辑、不动 Notion API / 持久化 / 工程配置。
- 影响路径:
  - 修改 `WidgetToDo/PomodoroViews.swift`：`PomodoroStartCard` 确定按钮追加 `.keyboardShortcut(.defaultAction)`（窗口默认回车动作，仅在弹框挂载时存在，disabled 时回车不触发）；`PomodoroDurationPicker` 自定义输入框追加 `.onSubmit`，经 `validatePomodoroCustomMinutes()` 门控后复用 `viewModel.beginPomodoro()`。
  - 增量改动 `Tests/NotionFloatCoreSmokeTests/main.swift`：`pomodoroViewsKeepContract()` 新增 3 条源码守卫（defaultAction 存在、全文件仅 1 处绑定防止波及其他弹框、onSubmit 门控复用 beginPomodoro）。
- 设计要点:
  - 快捷键加在 `PomodoroStartCard` 调用点而非共享组件 `PomodoroPrimaryButton`（6 处弹框共用），确保只有开始弹框响应回车。
  - 双路径防重: `beginPomodoro()` 自带 `guard pomodoroSession == nil, let task = pomodoroStartTask` 幂等保护，回车与点击即使极端情况下同时触发也不会双重启动。
  - 非法自定义分钟时确定按钮禁用，onSubmit 同步门控，回车行为与点击禁用按钮完全一致（不触发）。
- 状态: 代码完成；自动化验证通过（全量 XCTest 70 过 + smoke 新守卫真实执行通过 + xcodebuild BUILD SUCCEEDED）。UI 手测（弹框打开按回车、弹框关闭按回车、输入框聚焦按回车三场景）待用户在运行中的 App 回测确认。
- 验证:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` -> 70 XCTests 全过，exit 0。
  - 临时注释 2 条存量失败守卫（沿用上一条记录的验证惯例）后运行 `.build/debug/NotionFloatCoreSmokeTests` -> `All smoke tests passed.`（含新增 3 条回车守卫真实执行）；守卫已恢复原样，`git diff` 确认无残留。
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -destination 'platform=macOS' -configuration Debug build` -> BUILD SUCCEEDED。
- 已知遗留: `type/edit picker should reserve visible height` 两条 smoke 存量失败（`215aa87` 移除固定高度所致，上一条记录已确认与代码改动无关），与本次无关；修复需更新守卫以匹配现行设计，待单独任务处理。

## 2026-08-15 - Auto-focus custom duration input in pomodoro start dialog
- 目标: 在「开始进行专注」弹窗中，用户点击「自定义」时长选项后 0.5 秒内自动聚焦下方的分钟输入框；聚焦时展示视觉反馈（原生光标闪烁 + 边框高亮/光圈）；不影响其他交互、不引发滚动异常。
- 非目标: 不改时长选项布局与文案、不改番茄钟业务逻辑（ViewModel 状态流不变）、不动 Notion API / 持久化 / 工程配置。
- 影响路径:
  - 修改 `WidgetToDo/PomodoroViews.swift`：`PomodoroPalette` 新增 `customFocusedBorder`(#b9ab9c) 与 `customFocusRing`(rgba(161,124,89,.12))，镜像 HTML 原型 `.custom-duration:focus-within` 样式；`PomodoroDurationPicker` 新增 `@FocusState isCustomMinutesFocused`，TextField 绑定 `.focused($isCustomMinutesFocused)`，`customInput` 插入时（即选中自定义那一刻）通过 `onAppear + DispatchQueue.main.async` 置焦（下一 runloop tick，毫秒级完成，满足 0.5s 要求，且避开视图刚插入时的 first responder 竞态）；聚焦时边框切换 `customFocusedBorder` 并叠加外圈 `customFocusRing` 光圈，0.15s easeInOut 过渡。
  - 增量改动 `Tests/NotionFloatCoreSmokeTests/main.swift`：`pomodoroViewsKeepContract()` 新增 3 条源码守卫（FocusState 声明、`.focused` 绑定、置焦语句）。
- 设计要点:
  - 弹窗悬浮于 `todoPanel` ZStack 顶层、不在任何 ScrollView 内，聚焦不会触发列表滚动；未使用 `ScrollViewReader/scrollTo`，无滚动跳动风险。
  - 沿用仓库既有 `@FocusState` 惯例（同 `NewTaskFormCard` 标题自动聚焦）；弹窗每次打开会重置选中为 25 分钟（`presentPomodoroStart`），因此 `onAppear` 仅在用户真正点击「自定义」时触发，不会在弹窗打开时误聚焦。
- 状态: 代码完成；自动化验证通过（构建 + 全量 XCTest + smoke 新守卫）。UI 手测（点击自定义后光标聚焦、闪烁与边框反馈、切回 25/45 后焦点自然释放、无滚动异常）待用户在运行中的 App 回测确认。
- 最近验证:
  - 构建: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoFocusDerivedData build` - `** BUILD SUCCEEDED **`。
  - 全量: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox` - `Executed 70 tests, with 0 failures`。
  - smoke: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests` - 临时注释 2 条存量失败守卫后 `All smoke tests passed.`（含新增 3 条 pomodoro 聚焦守卫）；守卫已恢复原样（diff 仅剩 +13 行新守卫）。
- 风险/回滚点:
  - 存量问题（与本次改动无关，已在干净 HEAD 复现）：smoke 的 `type picker should reserve visible height for filtered options` 与 `edit picker should reserve visible height for filtered options` 两条守卫失败，因 `NewTaskFormCard.swift` 中 `optionsListHeight`/`typeOptionsListHeight` 已无 `.frame(height:)` 用法（某次提交改实现未同步守卫）；未在本任务中处理，待后续单独修复（改回 frame 用法或更新守卫）。
  - 回滚：还原 `PomodoroViews.swift` 改动并删除 smoke 中 3 条新守卫即可，无数据/契约影响。

## 2026-08-15 - Add interaction demo GIF to README
- 目标: 把官网落地页（仓库外 `index.html`）的交互动画录制为 GIF，嵌入 README 中英文版的 tagline 下方，展示「勾选待办 -> 同步 Notion -> 写日记 -> 新建任务 -> 番茄钟」完整交互。
- 非目标: 不改 Swift 源码、测试、构建配置；不改 README 其他章节；不提交 git（等用户确认后再 commit）。
- 影响路径:
  - 新增 `WidgetToDo/assets/readme/demo-interaction.gif`（640×747、280 帧、11fps、无限循环、9.9MB，GitHub README 渲染安全范围内）。
  - 修改 `WidgetToDo/README.md`：GIF 定位语下方 -> 后移至「它解决什么」与「功能特性」模块之间（替换原 `docs/screenshots/app-main-light.png` 应用截图位，截图引用已移除、文件保留）。
  - 修改 `WidgetToDo/README.en.md`：同步英文版（GIF 移至 The Problem It Solves 与 Features 之间，移除截图引用）。
- 状态: 已完成；GIF 已生成并嵌入两版 README，位置按用户要求调整至功能特性模块上方（2026-08-15 二次迭代提升清晰度：2 倍分辨率源重录）。
- 录制方式（外部工具链，不入仓库）:
  - Playwright headless Chromium（deviceScaleFactor=2）+ CDP `Page.captureScreenshot`（clip + scale=2，JPEG q92，约 32ms/帧、~30fps 真实采样），Python Pillow 按时间戳重采样到 11fps、LANCZOS 缩到 640px、轻柔去噪 + 全局调色板合成 GIF；录制 URL 带 `?plain=1` 隐藏氛围动画层。
  - 踩坑记录：① 本机 Trae 内置 ffmpeg 仅支持 mp4/libx264（无 GIF/PNG 输出）；② CDP `Page.startScreencast` 只出 CSS 像素帧（忽略 DPR）；③ `body.style.zoom` 会破坏页面布局（舞台被挤压变形），不可用于超采样；④ playwright 的 `pg.screenshot()` 太慢（全视口 2x PNG 约 667ms/帧）；⑤ CDP clip 截图默认 scale=1 出 CSS 分辨率，需显式 `scale:2`。
- 最近验证:
  - 命令: `python3 -c "from PIL import Image, ImageStat; ..."`（读取 demo-interaction.gif）- 通过：size 640×747、280 帧、loop=0，抽样多帧均有正常内容（暖色均值/标准差合理）。
  - 命令: `ls -lh assets/readme/demo-interaction.gif` - 通过，9.9M。
  - 命令: `grep -n "demo-interaction.gif" README.md README.en.md` - 通过，两处引用路径一致。
  - 无 `swift test`：本次仅新增资源与文档，不涉及代码或测试变更。
- 风险/回滚点:
  - 纯资源+文档改动；回滚 `git checkout -- README.md README.en.md progress.md` 并删除 `assets/readme/demo-interaction.gif` 即可。
  - GIF 9.9MB 接近 GitHub README 渲染安全线（<10MB）；如需更小可将 `record_gif.py` 中 OUT_W 降到 600 或 FPS 降到 10 重录（外层工作目录保留可复用）。

## 2026-08-10 - Add "What Is This" product positioning section to README
- 目标: 在 README 中补充产品定位描述——明确 WidgetToDo 是一款什么样的 APP（原生 macOS 桌面应用、Notion 的轻量入口、聚焦三件事），中英文版同步。
- 非目标: 不改 Swift 源码、测试、构建配置；不改动 README 其他章节。
- 影响路径:
  - 修改 `WidgetToDo/README.md`：在 tagline 与「它解决什么」之间新增「这是什么」章节。
  - 修改 `WidgetToDo/README.en.md`：同步新增「What Is This」章节。
- 状态: 已完成；两版 README 内容对齐。
- 内容要点:
  - 一句话定位：原生 macOS 桌面应用（SwiftUI + AppKit），把 Notion 数据库变成常驻桌面的悬浮面板，改动实时同步回 Notion。
  - 三个「不是」划清边界：不是独立任务管理器（数据在 Notion）、不是浏览器插件（独立 App）、不是全功能 Notion 客户端（只聚焦今日待办 + 当日日记 + 番茄钟）。
  - 目标用户：用 Notion 管理日常任务、希望待办清单「钉」在桌面上随时可见的人。
- 最近验证:
  - 命令: `grep -n "## 这是什么" README.md` — 通过，章节已插入 tagline 之后、「它解决什么」之前。
  - 命令: `grep -n "## What Is This" README.en.md` — 通过，英文版同步。
  - 无 `swift test`：本次仅修改文档，不涉及代码或测试变更。
- 风险/回滚点:
  - 纯文档改动；回滚 `git checkout -- README.md README.en.md` 即可。

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
