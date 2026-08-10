<p align="center">
  <a href="README.md">简体中文</a> | <a href="README.en.md">English</a>
</p>

<p align="center">
  <img src="./assets/readme/hero.svg" width="100%" alt="WidgetToDo — A macOS desktop floating panel that puts your Notion today's tasks and daily journal into a always-on floating window">
</p>

<p align="center">
  <a href="#download--installation"><img alt="platform" src="https://img.shields.io/badge/platform-macOS%2015%2B-blue"></a>
  <a href="#system-requirements"><img alt="swift" src="https://img.shields.io/badge/Swift-6.2-orange"></a>
  <a href="#license"><img alt="license" src="https://img.shields.io/badge/license-MIT-green"></a>
  <a href="#download--installation"><img alt="version" src="https://img.shields.io/badge/version-v1.1.0-lightgrey"></a>
</p>

> Put your Notion today's tasks and daily journal into an always-on desktop floating panel — no browser, no switching to the Notion app.

## The Problem It Solves

If you manage tasks in Notion, every time you want to glance at today's to-dos, check one off, or jot down a journal entry, you have to switch to a browser or the Notion app. WidgetToDo turns these two things into a persistent desktop floating panel:

- **Always on desktop**: Draggable, grid-snapping, multi-layout; collapses into a mini capsule that keeps only the title and key actions.
- **Direct Notion integration**: Reads/writes your Tasks database and journal database; token stored in macOS Keychain, SQLite cache keeps your last-fetched tasks available offline.
- **Native macOS**: Built with SwiftUI + AppKit, menu bar icon, localized in Simplified Chinese / English / French.

<p align="center">
  <img src="./docs/screenshots/app-main-light.png" width="60%" alt="WidgetToDo main interface: Todo/Journal tabs, date navigation, pomodoro card, task rows with duration badges">
</p>

## Features

- **Floating panel**: Draggable, snap-to-grid, collapses into a mini capsule.
- **Today's tasks**: Check off, create, and edit Notion tasks.
- **New task**: Title/priority/status/estimated duration, with readable validation messages.
- **Daily journal**: Edit today's journal, manually sync to Notion.
- **Pomodoro timer**: Focus timer with task status integration.
- **Status bar icon**: Left-click to summon the panel, right-click for menu.
- **Multi-language**: Simplified Chinese / English / French.
- **Local cache**: SQLite offline access.
- **Secure token**: Stored in Keychain, never in source code or logs.

## System Requirements

| Item | Requirement |
| --- | --- |
| OS | macOS 15.0 or later |
| Swift toolchain | Swift 6.2 |
| Xcode | Xcode 16+ recommended (CommandLineTools-only setups will fail `swift test` with `no such module 'XCTest'`) |
| Notion | A Notion account + a Tasks database + a journal database |

## Download & Installation

### Option 1: Download the DMG (regular users)

Go to [Releases](https://github.com/klosexf/WidgetToDo/releases), download the latest `WidgetToDo-V1.1.dmg`, mount it, and drag `WidgetToDo.app` to your Applications folder.

> The current release is distributed for developers and is **not** signed with a paid Apple Developer certificate. On first launch, macOS may show "cannot verify the developer" or "cannot check for malicious software" — this is normal Gatekeeper behavior for unsigned apps. Use any of these methods to bypass:
>
> 1. **System Settings**: Go to **System Settings → Privacy & Security**, then click "Open Anyway".
> 2. **Right-click open**: In Finder, locate `WidgetToDo.app`, **right-click → Open**, then confirm in the dialog.
> 3. **Terminal (remove quarantine attribute)**:
>
>    ```bash
>    xattr -cr /Applications/WidgetToDo.app
>    ```
>
>    Then double-click the app again.

### Option 2: Build from source (developers)

```bash
git clone git@github.com:klosexf/WidgetToDo.git
cd WidgetToDo
open WidgetToDo.xcodeproj
```

In Xcode, select the `WidgetToDo` scheme and press `⌘R` to run. On first launch, the welcome screen will prompt you for a Notion integration token and ask you to select your Tasks and journal databases.

## Configure Notion Integration

1. Create an **internal integration** in Notion and copy the integration token (in `secret_xxx` format).
2. **Explicitly share** this integration with your Tasks database and journal database (Notion requires integrations to be shared before they can access content).
3. Launch WidgetToDo, paste the token in the welcome screen, and select your databases.
4. The Tasks database supports an optional `number` field for "estimated duration (minutes)". The app works fine without it — it just won't display the duration.

The token is stored in macOS Keychain; configuration is persisted via `SettingsStore` to Application Support. Neither ever enters the source code.

## Architecture & Layers

This is a single-repo native macOS project. The testable core logic is exposed as a `NotionFloatCore` SwiftPM library, while the app layer is assembled via an Xcode project. The UI layer never makes Notion requests directly — everything goes through:

<p align="center">
  <img src="./assets/readme/architecture-flow.svg" width="100%" alt="Layered architecture: View/ViewModel → NotionRepository → NotionClient / SQLiteCache / KeychainTokenStore / SettingsStore">
</p>

Reusable pure logic for window dragging, snapping, and layout lives in `Core/Services/` for `swift test` coverage; the AppKit/SwiftUI layer only consumes the computed results.

### Directory Structure

```text
WidgetToDo/
├── WidgetToDo/                     # App layer
│   ├── WidgetToDoApp.swift         # Entry point
│   ├── AppCoordinator.swift        # App coordinator
│   ├── FloatingWindowManager.swift # Floating window management
│   ├── StatusBarController.swift   # Menu bar icon
│   ├── ContentView.swift           # Main panel (Todo / Journal / Settings)
│   ├── TodoListViewModel.swift     # Todo list ViewModel
│   ├── JournalViewModel.swift      # Journal ViewModel
│   ├── NewTaskFormCard.swift       # New task form
│   ├── PomodoroViews.swift         # Pomodoro timer
│   ├── MiniCapsuleViews.swift      # Mini capsule mode
│   ├── WelcomeView.swift           # Onboarding flow
│   ├── LanguageStore.swift         # Localization strings
│   ├── Core/
│   │   ├── Models/                 # Shared models (TaskItem / NewTaskDraft / AppSettings)
│   │   ├── Infrastructure/         # NotionClient / NotionRepository / SQLiteCache / KeychainTokenStore / SettingsStore
│   │   └── Services/               # Pure logic (field mapping / window snap algorithm / validators)
│   ├── WidgetToDo.entitlements     # Only declares network.client
│   └── *.lproj/                    # Localization resources (zh-Hans / en / fr)
├── Tests/
│   ├── NotionFloatCoreTests/       # XCTest unit tests
│   └── NotionFloatCoreSmokeTests/  # Executable smoke contracts
├── docs/superpowers/
│   ├── specs/                      # Design documents
│   └── plans/                      # Implementation plans
├── Package.swift                   # SwiftPM definition (NotionFloatCore)
└── progress.md                     # Cross-session execution status and recent verifications
```

> Outside the repo (in the local working directory), there are also `AGENTS.md` (collaboration conventions) and `bugs.md` (known issues / failed approaches) — these are not committed to git and serve as local development references.

## Build & Test

```bash
# Build the Core library
swift build

# Run the full unit test suite (requires full Xcode toolchain)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# Run a single test suite
swift test --filter WindowSnapLayoutEngineTests

# Run smoke contracts (executable)
swift run NotionFloatCoreSmokeTests

# Build the app with Xcode (if the active developer directory points to CommandLineTools, specify explicitly)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug build
```

## Packaging & Release

DMG artifacts are generated with `create-dmg`, named like `WidgetToDo-V1.1.dmg`, and distributed via GitHub Releases. `*.dmg` is added to `.gitignore` and never enters the repo.

## Development Conventions

This repo follows a set of collaboration conventions shared between AI agents and human contributors (`AGENTS.md`, maintained locally, not in git), covering task classification, standard execution flow, verification loops, rollback protocols, and hard prohibitions. Before opening a PR, please request a copy from the maintainer or discuss in an issue.

Key points:

- Tokens go in Keychain, configuration goes in SettingsStore — **never hardcode**.
- Network errors and field validation errors must keep **readable Chinese descriptions** — no bare English system errors.
- New window dragging / snapping / layout algorithms should be implemented as **pure computation** first, consumed by the UI layer afterward.
- Modifying `Package.swift`, `.xcodeproj`, `entitlements`, persistence logic, or the Notion API contract is considered high-risk — please explain the impact in your PR.
- Never write Notion tokens into source code, logs, screenshot annotations, or test snapshots.

## Known Issues & Risks

Historical pitfalls and failed approaches are recorded in a local `bugs.md` (not in git). Before fixing a bug, please search that file first to avoid repeating mistakes. To learn about known risks, ask the maintainer in an issue.

## License

This project is open-sourced under the [MIT License](LICENSE). You are welcome to use, modify, and distribute it — just keep the copyright notice.
