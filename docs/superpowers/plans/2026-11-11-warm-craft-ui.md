# 暖棕 UI 正式开发计划

**Goal:** 将已确认的暖棕原生样板视觉应用到真实产品代码，保留原布局与功能。

**Architecture:** 新增共用 WidgetTheme 和被动材质视图，迁移七个现有视图文件的样式。业务 ViewModel、窗口算法、数据基础设施沿用现有实现。

**Tech Stack:** SwiftUI / AppKit / SwiftPM / Xcode。

- [x] 新增 WidgetTheme.swift；材质视图 hitTest 返回 nil，避免抢走窗口拖拽或控件点击。
- [x] 从 v0.3 迁移五个视图的已审核差异；去掉所有样板探针，保留生产预览与原逻辑。
- [x] ContentView 接入原生材质与暖棕强调；不改 FloatingWindowManager。
- [x] 审查 diff，确认 RootViewModel、表单回调和基础设施未变。
- [x] 运行 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox`、`swift run --disable-sandbox NotionFloatCoreSmokeTests`。
- [x] `xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath <独立构建目录> CODE_SIGNING_ALLOWED=NO build`。
- [x] 使用隔离示例数据的原生宿主验证当前生产视图，补 ContentView/FloatingWindowManager 核验，保存图像与操作证据。宿主位于仓库外，不进入正式 App。
- [x] 话术条与编辑卡片接入共用样式，实际验证开关、短句、长句滚动、编辑保存/取消和窗口收起展开。
- [x] 完成差异/引用校验，更新 progress.md，说明构建产物、实际覆盖与限制。

证据保存到外层 `work/2026-11-11-warm-ui-development/`。不对视觉常量编写逐值镜像测试；使用既有行为测试与实际原生画面校验。

2026-11-11 验收结果：148 项 XCTest / 0 failures，smoke test 与正式 Xcode build 通过。25 次状态观察、25 张原生截图及源码散列核验见外层 `work/2026-11-11-warm-ui-development/`。拖拽/吸附因 CUA noWindowsAvailable 未复测；完整深色、真实 Notion 和话术悬停暂停未验收。计划中的 UI 核验按已记录边界完成，不将这些限制标记为通过。

2026-11-26 补验：用户反馈旧版拖动卡顿。标题区和胶囊改用系统拖拽后，用户亲自复测并确认浮窗拖动顺畅。原生窗口位置保存、标签切换和胶囊展开收起均已通过验证。本版沿用自由拖拽。
