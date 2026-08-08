# Pomodoro Task Focus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` and implement the checked tasks in order.

**Product spec:** [2026-08-05-pomodoro-task-focus-design.md](../specs/2026-08-05-pomodoro-task-focus-design.md)

**Goal:** Add one in-memory Pomodoro session to an incomplete task. It provides 25/45/custom durations, pause, abandon, and an explicit completion switch. At the end of a successful round, add its active focus time to the task's existing Notion **时长** field, play a system sound, then let the user decide whether the task should also be completed.

**Cumulative rule:** User-facing copy calls the existing duration value `时长`; code continues to use the existing `estimatedMinutes` mapping without renaming the Notion property. The value is deliberately accumulated, not replaced: **45 分钟** plus one **25 分钟** round becomes **70 分钟**. No new Notion field, Pomodoro history, or “actual duration” field is introduced.

**Architecture:** The pure timer state machine lives in `Core`; `TodoListViewModel` owns it, schedules one-second UI refreshes, and is the only app-layer caller of `NotionRepository`. New SwiftUI views are mounted only in the Todo path, immediately above the existing task list. Reuse `updateTaskTitle(id:title:estimatedMinutes:)` for the duration write and `toggleTask(id:isDone:)` only for an explicit task-completion decision.

**Tech stack:** Swift 6.2, SwiftUI/AppKit, Swift Concurrency, SwiftPM/XCTest, existing `NotionRepository`, existing `AppText` localization catalog.

---

## Scope lock

- **Reference hierarchy before any UI work:** use [Pomodoro Task Flow Explorations.html](../prototypes/Pomodoro%20Task%20Flow%20Explorations.html) as the only visual/interaction reference for newly added Pomodoro elements. Use [2026-08-05-pomodoro-task-focus-design.md](../specs/2026-08-05-pomodoro-task-focus-design.md) for product behavior. Treat current production UI as the immutable baseline for every non-Pomodoro area. Discussion screenshots are not implementation references.
- Do not modify `Package.swift`, `WidgetToDo.xcodeproj`, entitlements, `SettingsStore`, `KeychainTokenStore`, `SQLiteCache`, `NotionClient`, or the Notion API contract.
- Reuse only the already mapped duration number property (`estimatedMinutes` internally; `时长` in the UI). Do not create a Notion property or persist an active session in AppSettings, SQLite, or UserDefaults.
- Do not add Pomodoro counts/history, breaks, notifications, global shortcuts, cross-device recovery, background execution, or a new audio asset. Use `NSSound.beep()` for the end cue.
- Do not change Journal, settings/onboarding/welcome, mini-mode, top bar, date navigation, normal task-list layout, or existing new/edit/delete flows.
- Existing Todo changes are limited to: an incomplete-task focus affordance; a conditional active card immediately above the task list; and focus-only overlays. With no active session or focus overlay, Todo must look and work exactly as before.
- Only one session can run or pause. Other focus-start controls are disabled; no task switching is automatic.
- The final completion dialog has one **off-by-default** “同时完成任务” switch. When off, the action records only duration and keeps the task incomplete; when on, it records duration first and then completes the task. Timer end never completes a task without that explicit enabled switch and confirmation.
- The session is process-local. App quit discards it; no recovery behavior is added.

## Behavior contract

1. An incomplete task has a small "计时"/timer action. Its start dialog is titled `开始进行专注` with copy `结束后本次时长将累计到"时长"。` and a hint `不会修改任务状态`. It includes 25 minutes, 45 minutes, and custom whole minutes `1...480`; completion choice does not appear until the final confirmation dialog.
2. Start reveals a conditional timer card **above**, never instead of, the unchanged list. It uses the approved layout: large countdown ring left; title plus metadata right; equal `放弃 / 暂停（或继续） / 完成` actions below. The card meta shows `专注中 · 本轮 %@ 分钟`; when paused it shows `已暂停 · 计时不会继续`.
3. Pause freezes countdown and active elapsed seconds. Resume continues from that exact state. The pause dialog is titled `专注已暂停` with copy `计时已暂停，当前任务仍保持未完成。你可以继续专注，或选择放弃本轮。`; its buttons are `放弃本轮` (secondary, routes to abandon confirmation) and `继续专注` (primary). Abandon needs confirmation via a dialog titled `确认放弃？` with copy `放弃后，本轮专注不会记录任何时长，任务会继续保留在列表中。`; its buttons are `继续专注` (secondary) and `确认放弃` (destructive). Abandon changes neither duration nor task completion.
4. At zero, cancel the tick once, call `NSSound.beep()`, calculate active duration, and write `newTotal = (task.estimatedMinutes ?? 0) + minutesToAdd` through the existing repository update method. Natural end adds the selected duration exactly (for example 45 + 25 = 70).
5. After a successful natural-end duration write, hide the card and show a dialog titled `本轮已完成` with copy `已将 %@ 分钟累计到"时长"。` and a hint `可同时完成任务，或保持未完成继续后续专注`. The final dialog does not repeat the task title; it shows the off-by-default "同时完成任务" switch. When off, its action is `保持未完成`; when on, it is `完成任务` and uses the existing checkbox mutation.
6. Manual card completion opens a dialog with kicker `结束专注` and copy `确认后，将 %@ 分钟累计到"时长"。剩余时间不会计入时长。` using the same title-free final-dialog layout and switch. When off, its primary action is `记录时长`; when on, it is `记录并完成任务`. On confirmation, stop the timer and add active elapsed time only (pause excluded). If enabled, set the checkbox done only after the duration write succeeds. Use `max(1, ceil(activeElapsedSeconds / 60))`; do not add remaining countdown time.
7. Write order is non-negotiable: duration update first, completion checkbox second. A duration-write failure must never complete the task. Show a localized failure prompt with `重试写入` / `稍后决定`; retry reuses the same precomputed minutes and must not double-add. A checkbox failure after duration success retains the new duration, leaves task visually unfinished/failed, and displays the normal task-update error.
8. On duration write success, replace the matching value in `tasks` using the returned `TaskItem`, so the existing task-row display immediately reflects the new cumulative total without a full reload. The task row displays the cumulative value as `时长 %@ 分钟`.
9. After the user confirms either final flow (manual or natural end), the success state shows `已将 %@ 分钟累计到"时长"。任务已完成。` (switch was on) or `已将 %@ 分钟累计到"时长"。任务保持未完成。` (switch was off) with a single centered `知道了` button.
10. All new copy comes from `LanguageStore`/`AppText`, in Simplified Chinese, English, and French.

## File map

- Create `WidgetToDo/Core/Models/PomodoroSession.swift`: `Sendable` session, phases/events, `1...480` boundary.
- Create `WidgetToDo/Core/Services/PomodoroSessionEngine.swift`: pure start/advance/pause/resume/abandon/elapsed-time state machine.
- Create `Tests/NotionFloatCoreTests/PomodoroSessionEngineTests.swift`: deterministic transition and duration-rounding tests.
- Create `WidgetToDo/PomodoroViews.swift`: start dialog, active card, and focus prompt views only.
- Modify `WidgetToDo/TodoListViewModel.swift`: session/prompt state, ticking, safe update order, and retry context.
- Modify `WidgetToDo/ContentView.swift`: minimal Todo-only mounting and start affordance.
- Modify `WidgetToDo/Core/Services/AppLocalizer.swift` and `Tests/NotionFloatCoreTests/AppMessageLocalizationTests.swift`: new messages and coverage.
- Modify `Tests/NotionFloatCoreTests/NotionRepositoryTaskMutationTests.swift`: verify the existing field receives a cumulative `70` value.
- Modify `Tests/NotionFloatCoreSmokeTests/main.swift`: narrow app-target source guards.
- Modify `progress.md` after implementation with real verification evidence.

## Task 1: Build the pure timer engine first

**Files:** `PomodoroSession.swift`, `PomodoroSessionEngine.swift`, `PomodoroSessionEngineTests.swift`.

- [ ] Write the failing engine tests with fixed dates. Required cases:
  - Start 45 minutes yields `.running` and `2_700` remaining seconds.
  - Advancing a 25-minute session by 1,500 seconds emits `.finished` once, never again, and yields 1,500 active seconds.
  - Pause at 70 seconds, wait 600 seconds, resume for 30 seconds: active duration is 100 seconds, not 700.
  - Invalid durations `0` and `481` are rejected; abandon clears the session; paused/final sessions do not advance.
  - Rounding policy: 1 second → 1 minute, 60 seconds → 1 minute, 61 seconds → 2 minutes.

- [ ] Run red:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter PomodoroSessionEngineTests
```

- [ ] Implement this stable API:

```swift
public enum PomodoroPhase: Equatable, Sendable { case running, paused, finished }
public enum PomodoroTimerEvent: Equatable, Sendable { case none, finished }

public struct PomodoroSession: Equatable, Sendable {
    public let taskID: String
    public let taskTitle: String
    public let durationMinutes: Int
    public private(set) var phase: PomodoroPhase
    public private(set) var remainingSeconds: Int
    public private(set) var activeElapsedSeconds: Int
    public private(set) var lastResumedAt: Date?
}

public struct PomodoroSessionEngine: Sendable {
    public private(set) var session: PomodoroSession?
    public mutating func start(task: TaskItem, durationMinutes: Int, at date: Date)
    public mutating func advance(to date: Date) -> PomodoroTimerEvent
    public mutating func pause(at date: Date)
    public mutating func resume(at date: Date)
    public mutating func abandon()
    public func completedMinutes(at date: Date) -> Int
}
```

`advance(to:)` calculates active wall-clock deltas from `lastResumedAt`, clamps at zero, and returns `.finished` only on the first terminal transition. `completedMinutes(at:)` includes the current active interval and excludes paused intervals. The view model invokes it only for a timer end or confirmed manual completion, never abandon.

- [ ] Re-run the focused command until green, then commit this Core-only slice:

```bash
git add WidgetToDo/Core/Models/PomodoroSession.swift WidgetToDo/Core/Services/PomodoroSessionEngine.swift Tests/NotionFloatCoreTests/PomodoroSessionEngineTests.swift
git commit -m "feat: add pomodoro session engine"
```

## Task 2: Lock the Notion accumulation and localization contract

**Files:** `NotionRepositoryTaskMutationTests.swift`, `AppLocalizer.swift`, `AppMessageLocalizationTests.swift`.

- [ ] Write a repository test with a task whose `estimatedMinutes == 45`; invoke the existing update method with `estimatedMinutes: 70`; assert returned/cached value is 70 and mock request body contains `"number":70`. This confirms reusing the existing field rather than inventing a second API.
- [ ] Add localization assertions for parameterized 25-minute accumulation copy in Chinese, English, French.
- [ ] Add concise keys equivalent to:

| Key | Chinese copy |
| --- | --- |
| `pomodoroTaskStartAction` | `计时` |
| `pomodoroStartDialogTitle` | `开始进行专注` |
| `pomodoroStartDialogCopy` | `结束后本次时长将累计到"时长"。` |
| `pomodoroStartDialogHint` | `不会修改任务状态` |
| `pomodoroStartDialogCancel` | `取消` |
| `pomodoroStartDialogBegin` | `开始 %@ 分钟专注` |
| `pomodoroDurationFieldLabel` | `本轮时长` |
| `pomodoroDurationPreset25` | `25 分钟` |
| `pomodoroDurationPreset45` | `45 分钟` |
| `pomodoroDurationCustom` | `自定义` |
| `pomodoroDurationCustomPlaceholder` | `输入分钟数（1–480）` |
| `pomodoroDurationUnit` | `分钟` |
| `pomodoroDurationError` | `请输入 1 到 480 之间的整数分钟数` |
| `pomodoroFocusCardMeta` | `专注中 · 本轮 %@ 分钟` |
| `pomodoroFocusCardPausedMeta` | `已暂停 · 计时不会继续` |
| `pomodoroAbandon` | `放弃` |
| `pomodoroPause` | `暂停` |
| `pomodoroComplete` | `完成` |
| `pomodoroPauseDialogTitle` | `专注已暂停` |
| `pomodoroPauseDialogCopy` | `计时已暂停，当前任务仍保持未完成。你可以继续专注，或选择放弃本轮。` |
| `pomodoroPauseAbandonRound` | `放弃本轮` |
| `pomodoroResumeFocus` | `继续专注` |
| `pomodoroAbandonDialogTitle` | `确认放弃？` |
| `pomodoroAbandonDialogCopy` | `放弃后，本轮专注不会记录任何时长，任务会继续保留在列表中。` |
| `pomodoroConfirmAbandon` | `确认放弃` |
| `pomodoroEndFocusKicker` | `结束专注` |
| `pomodoroEndFocusDialogCopy` | `确认后，将 %@ 分钟累计到"时长"。剩余时间不会计入时长。` |
| `pomodoroRecordDuration` | `记录时长` |
| `pomodoroRecordAndComplete` | `记录并完成任务` |
| `pomodoroRoundComplete` | `本轮已完成` |
| `pomodoroRoundCompleteCopy` | `已将 %@ 分钟累计到"时长"。` |
| `pomodoroRoundCompleteHint` | `可同时完成任务，或保持未完成继续后续专注` |
| `pomodoroKeepIncomplete` | `保持未完成` |
| `pomodoroCompleteTask` | `完成任务` |
| `pomodoroDurationAdded` | `已将 %@ 分钟累计到"时长"。` |
| `pomodoroCompleteTaskToggle` | `同时完成任务` |
| `pomodoroCompleteTaskToggleOffHint` | `关闭则只记录本轮时长，任务保持未完成` |
| `pomodoroCompleteTaskToggleOnHint` | `开启则记录时长，且任务设为已完成` |
| `pomodoroSuccessCompleted` | `已将 %@ 分钟累计到"时长"。任务已完成。` |
| `pomodoroSuccessIncomplete` | `已将 %@ 分钟累计到"时长"。任务保持未完成。` |
| `pomodoroDone` | `知道了` |
| `pomodoroTaskDurationLabel` | `时长 %@ 分钟` |
| `pomodoroDurationWriteFailed` | `本轮已结束，但时长未能写入。` |
| `pomodoroRetryDurationWrite` | `重试写入` |
| `pomodoroLater` | `稍后决定` |

Do not add a completion toggle to the start dialog. The only completion toggle belongs in the final record/finish dialog and defaults to off.

- [ ] Verify:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter 'NotionRepositoryTaskMutationTests|AppMessageLocalizationTests'
```

Expected evidence: the test proves **45 + 25 = 70** writes to the mapped duration property.

## Task 3: Add view-model orchestration and idempotent retry state

**Files:** `TodoListViewModel.swift`, `Tests/NotionFloatCoreSmokeTests/main.swift`.

- [ ] Add failing smoke guards for `PomodoroSessionEngine`, `presentPomodoroStart`, `beginPomodoro`, `pausePomodoro`, `confirmPomodoroAbandon`, `confirmPomodoroManualCompletion`, `recordPomodoroDuration`, `NSSound.beep`, `repository.updateTaskTitle`, `repository.toggleTask`, and `Task.sleep`. Also guard against `NotionClient` and `SettingsStore` inside Pomodoro methods.
- [ ] Add only focus-specific state:

```swift
@Published private(set) var pomodoroSession: PomodoroSession?
@Published var pomodoroStartTask: TaskItem?
@Published var pomodoroSelectedMinutes = 25
@Published var pomodoroCustomMinutesText = ""
@Published var pomodoroDurationError: AppMessage?
@Published var pomodoroPrompt: PomodoroPrompt?
@Published var pomodoroDurationWriteError: AppMessage?

private var pomodoroEngine = PomodoroSessionEngine()
private var pomodoroTickTask: Task<Void, Never>?
private var finishedPomodoro: FinishedPomodoroContext?
```

`FinishedPomodoroContext` must store immutable `taskID`, title, `minutesToAdd`, and a duration-write-success flag. This is the retry/double-count guard; never calculate a fresh delta once a round has stopped.

- [ ] Implement these public actions:

```swift
func presentPomodoroStart(for task: TaskItem)
func selectPomodoroPreset(_ minutes: Int)
func validatePomodoroCustomMinutes() -> Int?
func beginPomodoro()
func pausePomodoro()
func resumePomodoro()
func requestPomodoroAbandon()
func confirmPomodoroAbandon()
func requestPomodoroManualCompletion()
func confirmPomodoroManualCompletion() async
```

Add private `finishPomodoroRound()` and `recordPomodoroDuration(for:) async -> Bool` helpers. `recordPomodoroDuration` finds the current task, calculates `(task.estimatedMinutes ?? 0) + context.minutesToAdd`, calls:

```swift
let updated = try await repository.updateTaskTitle(
    id: task.id,
    title: task.title,
    estimatedMinutes: newTotal
)
tasks = TaskSorting.sort(tasks.map { $0.id == updated.id ? updated : $0 })
```

Terminal order: tick reaches zero → cancel it → compute context → `NSSound.beep()` → hide card → duration write → final switch dialog. Manual route: user chooses the final switch, then confirms → cancel tick → compute context → duration write → call `toggleTask(..., true)` only when the switch is on. Abandon makes no repository call. On duration failure present retry/later and never call `toggleTask`; on success set the context’s recorded flag before presenting actions. In `deinit`, cancel the tick task. After each await, confirm the task/session identity is still current before changing focus UI.

- [ ] Run the smoke executable after guards are satisfied:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests
```

## Task 4: Build isolated focus views

**Files:** `WidgetToDo/PomodoroViews.swift`, smoke source guard.

- [ ] Create `PomodoroFocusCard`, `PomodoroStartCard`, and `PomodoroPromptCard`. Add a guard that the start card has 25/45/custom and no completion toggle; require a switch/toggle in `PomodoroPromptCard` bound to a default-false completion choice.
- [ ] Match the existing product surface: warm whites, thin beige borders, neutral actions, green only for “完成”, red only for “放弃”. No literal reference-image colors, blue palette, image asset, or macOS `confirmationDialog`.
- [ ] Start card: selected task, three duration controls, hidden-until-selected custom `TextField`, disabled start while invalid, and copy saying completed focus time is added to `时长`.
- [ ] Prompt card routes: pause (resume/abandon), abandon (continue/confirm), manual completion (exact active minutes plus the completion switch), natural end (round complete plus the same completion switch), and duration-write failure (retry/later without a success claim). The manual-completion and natural-end dialogs omit the repeated task title; default switch off gives `记录时长` or `保持未完成`; enabled gives `记录并完成任务` or `完成任务`. The one-button success state hides the repeated title and centers the single “知道了” action instead of leaving it in a two-column action grid.
- [ ] Use `LanguageStore` for every visible string.

## Task 5: Integrate only in the Todo path

**Files:** `ContentView.swift`, smoke source guard.

- [ ] In `todoPanel`, place `PomodoroFocusCard` after the existing sync banner and before the current `taskListView`, rendered only when `pomodoroSession != nil`.
- [ ] Add one compact timer-start action to incomplete task rows; disable it during any active session/prompt. Preserve all existing edit/delete/retry controls, row styling, sort order, top bar, and date navigation.
- [ ] Add the start/prompt views only beside the current Todo overlays in the Todo `ZStack`. Assert `journalPanel` has none of the Pomodoro view names.
- [ ] Do not reserve blank vertical space when the card is absent. The timer may continue while the user views another date/Journal, but renders only in the Todo tab.
- [ ] Build without modifying the project file:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project WidgetToDo.xcodeproj -scheme WidgetToDo -configuration Debug -derivedDataPath /private/tmp/WidgetToDoPomodoroDerivedData build
```

Expected: `** BUILD SUCCEEDED **`.

## Task 6: Verification, progress, and handoff

- [ ] Run:

```bash
cd /Users/chenxiaofeng/Documents/Tare\ code\ file/widgets\ for\ notion/WidgetToDo
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter PomodoroSessionEngineTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter 'AppMessageLocalizationTests|NotionRepositoryTaskMutationTests'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox NotionFloatCoreSmokeTests
git diff --check
```

- [ ] Manually verify: idle Todo unchanged; 25/45/custom starts; invalid 0/481/decimal rejected; pause excludes inactive time; abandon makes no write; natural 25 on 45 beeps and displays 70 then asks completion; “稍后决定” retains 70/incomplete state; complete uses duration-first ordering; 61 active seconds manually completed adds 2 minutes; duration failure cannot complete/double-add; checkbox failure retains successfully written duration.
- [ ] Update `progress.md` with command output, manual evidence or UI-test blocker, non-persistence boundary, affected files, and rollback commits. Update `bugs.md` only for a reproducible verified defect.
- [ ] Commit feature and documentation separately after green verification.

## Definition of done

- [ ] No focus card exists before start or after session cleanup; task list remains visible while active.
- [ ] No automatic or implicit task completion exists; only the default-off final completion switch and its confirmation can complete a task.
- [ ] Natural 25-minute completion on “时长 45 分钟” writes and shows “时长 70 分钟”.
- [ ] `NSSound.beep()` gives the terminal cue without new app assets/project changes.
- [ ] Manual completion records active time only and writes duration before task checkbox.
- [ ] All mutations go through `NotionRepository`; unrelated UI and product flows remain unchanged.
- [ ] Automated checks, macOS UI verification, and evidence are recorded in `progress.md`.

## Rollback

Revert Pomodoro commits in reverse order. This removes only the new timer model/service, views, localized copy, tests, and Todo integration. No migration is needed. Existing accumulated Notion duration values are intentional user data and must not be reversed automatically.
