# 暖棕 Craft 质感 UI 正式落地

用户于 2026-11-11 确认开始开发。视觉基准为外层 `work/2026-11-06-craft-native-prototype-v3-warm/`，不是早期蓝色方案。

## 目标

迁移已确认的暖白/暖灰表面、暖棕强调、深色主要按钮、系统字体层级、轻边缘和原生材质。完成/进度绿、错误红、时长橙、日记标记蓝和输入焦点蓝保持原有语义。

覆盖主面板与日记、待办/日记胶囊、日期月历、新建/编辑任务、专注区与提示、设置及帮助。用户追加话术展示条验收，覆盖其开关、空文案、宋体短句、长句横向滚动、编辑保存与取消。保留原有尺寸、字段顺序、列表/网格、长日期显示、滚动预算、窗口展开/收起和拖拽逻辑。Token 帮助保持尺寸，正文滚动以免长文截断。

## 代码边界

- 新增 `WidgetToDo/WidgetTheme.swift`，只提供共用颜色及不接收鼠标事件的材质背衬。
- 更新 `ContentView.swift`、`NewTaskFormCard.swift`、`PomodoroViews.swift`、`CalendarPopoverView.swift`、`MiniCapsuleViews.swift` 的视觉部分。
- `MotivationStripView.swift` 和 `MotivationEditorCard.swift` 接入共用暖色样式；宋体、28pt 高度、跑马灯、编辑按钮显隐与存储逻辑保持原样。
- 现有 smoke test 同步日期标题的半粗体样式，移除旧版禁止表单材质的样式断言；布局、滚动和业务断言保留。
- 不迁移样板 PreviewTrace、示例数据、URLProtocol、控制条或独立窗口宿主。不改变 ViewModel、Repository、缓存、Keychain 或 Notion API。
- 不修改 Package.swift、Xcode 工程和 entitlements，不删除文件。

## 验收

1. `swift test` 与现有 smoke test；完整 Xcode 应用构建。
2. 用当前生产组件进行原生 UI 核验：主面板、胶囊、日历、新建/编辑、专注、设置及相关校验/保存状态。
3. 单独覆盖生产 ContentView / FloatingWindowManager 的材质、尺寸与展开/收起；桌面拖拽实际操作若受连接限制，保留限制，不能用纯计算测试冒充实测。
4. 确认业务逻辑与基础设施文件未变，样板调试代码不进入产品；记录实际截图与验证结果。

本轮开发不包含部署、发布、替换已安装 App、真实 Notion 数据写入或自动 Notion 项目同步。

## 用户视觉微调：任务标题

2026-11-11 用户要求每条任务标题更粗：从 regular 调为 semibold，继续使用系统 12pt，字号/字距/行间距/单行截断不变；普通与已完成任务共用样式。此项覆盖样板的原标题字重。
