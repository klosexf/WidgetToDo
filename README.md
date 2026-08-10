<p align="center">
  <img src="./assets/readme/hero.svg" width="100%" alt="WidgetToDo — macOS 桌面浮窗，把 Notion 今日任务和当日日记装进一块常驻桌面的悬浮面板">
</p>

<p align="center">
  <a href="#下载与安装"><img alt="platform" src="https://img.shields.io/badge/platform-macOS%2015%2B-blue"></a>
  <a href="#系统要求"><img alt="swift" src="https://img.shields.io/badge/Swift-6.2-orange"></a>
  <a href="#许可证"><img alt="license" src="https://img.shields.io/badge/license-MIT-green"></a>
  <a href="#下载与安装"><img alt="version" src="https://img.shields.io/badge/version-v1.1.0-lightgrey"></a>
</p>

> 把 Notion 今日任务和当日日记，装进一块常驻桌面的悬浮面板——不开浏览器，不切 Notion 客户端。

## 它解决什么

用 Notion 管任务的人，每次看一眼今日待办、勾一个完成、写一段日记，都要切到浏览器或 Notion 客户端。WidgetToDo 把这两件事变成桌面常驻浮窗：

- **常驻桌面**：可拖拽、网格吸附、多档布局；一键缩为迷你胶囊，只留标题与关键操作。
- **直连 Notion**：读写 Tasks 数据库与日记数据库；令牌存 macOS Keychain，断网时 SQLite 缓存仍可查看上次拉取的任务。
- **原生 macOS**：SwiftUI + AppKit 构建，菜单栏常驻图标，简中 / 英 / 法三语本地化。

<p align="center">
  <img src="./docs/screenshots/app-main-light.png" width="60%" alt="WidgetToDo 主界面：待办/日记 tab、日期导航、番茄钟卡片、任务行与时长徽章">
</p>

<p align="center">
  <img src="./assets/readme/section-features.svg" width="100%" alt="功能特性">
</p>

## 功能特性

- **悬浮面板**：可拖拽、吸附、缩为迷你胶囊。
- **今日待办**：勾选、新建、编辑 Notion 任务。
- **新建任务**：标题/优先级/状态/预计时长，校验有中文提示。
- **当日日记**：编辑当日日记，手动同步到 Notion。
- **番茄钟**：专注计时，与任务状态联动。
- **状态栏图标**：左键唤起浮窗，右键弹菜单。
- **多语言**：简中 / 英 / 法。
- **本地缓存**：SQLite 断网可查。
- **安全令牌**：Keychain 存放，不进源码与日志。

<p align="center">
  <img src="./assets/readme/section-getting-started.svg" width="100%" alt="下载与配置">
</p>

## 系统要求

| 项 | 要求 |
| --- | --- |
| 操作系统 | macOS 15.0 或更高 |
| Swift 工具链 | Swift 6.2 |
| Xcode | 推荐 Xcode 16+（CommandLineTools 下 `swift test` 会报 `no such module 'XCTest'`，需完整 Xcode） |
| Notion | 一个 Notion 账户 + 一个 Tasks 数据库 + 一个日记数据库 |

## 下载与安装

### 方式一：下载 DMG（普通用户）

前往 [Releases](https://github.com/klosexf/WidgetToDo/releases) 下载最新版 `WidgetToDo-V1.1.dmg`，挂载后把 `WidgetToDo.app` 拖到「应用程序」即可。

> 当前版本面向开发者分发，未做付费 Apple Developer 代码签名。首次启动若提示「无法验证开发者」，请在「系统设置 → 隐私与安全性」点击「仍要打开」放行。

### 方式二：从源码构建（开发者）

```bash
git clone git@github.com:klosexf/WidgetToDo.git
cd WidgetToDo
open WidgetToDo.xcodeproj
```

在 Xcode 中选择 `WidgetToDo` scheme，`⌘R` 运行。首次运行时引导界面会要求填入 Notion 集成令牌并选择 Tasks / 日记数据库。

## 配置 Notion 集成

1. 在 Notion 创建一个 **internal integration**，拿到 `secret_xxx` 形式的集成令牌。
2. 把这个集成**显式共享**到你的 Tasks 数据库和日记数据库（Notion 要求集成被共享后才能访问）。
3. 启动 WidgetToDo，在引导界面填入令牌并选择数据库。
4. Tasks 数据库支持一个可选的 `number` 字段用于映射「预计时长（分钟）」；没有该字段也能正常使用，只是不显示时长。

令牌会写入 macOS Keychain，配置信息走 `SettingsStore` 持久化到 Application Support，均不进入源码。

<p align="center">
  <img src="./assets/readme/section-architecture.svg" width="100%" alt="架构与开发">
</p>

## 架构与分层

仓库是一个单仓库原生 macOS 项目，核心可测逻辑通过 SwiftPM 暴露为 `NotionFloatCore` library，App 层用 Xcode project 组装。UI 层不直接发 Notion 请求，统一走：

<p align="center">
  <img src="./assets/readme/architecture-flow.svg" width="100%" alt="分层架构：View/ViewModel → NotionRepository → NotionClient / SQLiteCache / KeychainTokenStore / SettingsStore">
</p>

窗口拖拽、吸附、布局等可复用纯逻辑放在 `Core/Services/`，便于 `swift test` 覆盖；AppKit / SwiftUI 层只消费计算结果。

### 目录结构

```text
WidgetToDo/
├── WidgetToDo/                     # App 层
│   ├── WidgetToDoApp.swift         # 入口
│   ├── AppCoordinator.swift        # 应用协调器
│   ├── FloatingWindowManager.swift # 浮窗与窗口管理
│   ├── StatusBarController.swift   # 菜单栏图标
│   ├── ContentView.swift           # 主面板（待办 / 日记 / 设置）
│   ├── TodoListViewModel.swift     # 待办列表 ViewModel
│   ├── JournalViewModel.swift      # 日记 ViewModel
│   ├── NewTaskFormCard.swift       # 新建任务弹框
│   ├── PomodoroViews.swift         # 番茄钟
│   ├── MiniCapsuleViews.swift      # 迷你胶囊模式
│   ├── WelcomeView.swift           # 引导流程
│   ├── LanguageStore.swift         # 多语言文本
│   ├── Core/
│   │   ├── Models/                 # 共享模型（TaskItem / NewTaskDraft / AppSettings）
│   │   ├── Infrastructure/         # NotionClient / NotionRepository / SQLiteCache / KeychainTokenStore / SettingsStore
│   │   └── Services/               # 纯逻辑服务（字段映射 / 窗口吸附算法 / 校验器）
│   ├── WidgetToDo.entitlements     # 仅声明 network.client
│   └── *.lproj/                    # 本地化资源（zh-Hans / en / fr）
├── Tests/
│   ├── NotionFloatCoreTests/       # XCTest 单元测试
│   └── NotionFloatCoreSmokeTests/  # 可执行 smoke 合约
├── docs/superpowers/
│   ├── specs/                      # 设计文档
│   └── plans/                      # 实施计划
├── Package.swift                   # SwiftPM 定义（NotionFloatCore）
└── progress.md                     # 跨会话执行状态与最近验证
```

> 仓库外（本地工作目录）还维护着 `AGENTS.md`（协作约定）和 `bugs.md`（已知问题 / 失败方案）两份文档，它们不进入 git，仅用于本地开发参考。

## 构建与测试

```bash
# 构建 Core 库
swift build

# 跑全量单元测试（需完整 Xcode 工具链）
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# 跑单个测试套件
swift test --filter WindowSnapLayoutEngineTests

# 跑 smoke 合约（可执行）
swift run NotionFloatCoreSmokeTests

# 用 Xcode 构建 App（当前环境若 active developer directory 指向 CommandLineTools，需显式指定）
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build
```

## 打包发布

DMG 产物用 `create-dmg` 生成，文件名形如 `WidgetToDo-V1.1.dmg`，通过 GitHub Release 分发。`*.dmg` 已加入 `.gitignore`，不会进入仓库。

## 开发约定

本仓库有一份 AI 代理与人类贡献者通用的协作约定（`AGENTS.md`，本地维护、不进入 git），涵盖任务分级、标准执行顺序、验证闭环、回滚协议与硬性禁止项。提 PR 前建议先向维护者索取或在 issue 中沟通。

要点速览：

- 令牌走 Keychain，配置走 SettingsStore，**禁止硬编码**。
- 网络错误与字段校验错误必须保留**可读中文描述**，不能只抛裸英文系统错误。
- 新的窗口拖拽 / 吸附 / 布局算法优先做成**纯计算**，再由 UI 层消费。
- 修改 `Package.swift`、`.xcodeproj`、`entitlements`、持久化或 Notion API 契约属于高风险改动，提 PR 时请说明影响。
- 不要把 Notion token 写入源码、日志、截图说明或测试快照。

## 已知问题与风险

历史踩坑与失败方案记录在本地 `bugs.md`（不进入 git）。修 bug 前请先检索该文件，避免重复踩坑。如需了解已知风险，请在 issue 中询问维护者。

## 许可证

本项目基于 [MIT License](LICENSE) 开源，欢迎使用、修改与分发，请保留版权声明。
