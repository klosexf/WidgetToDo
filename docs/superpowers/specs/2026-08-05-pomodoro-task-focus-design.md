# Pomodoro Task Focus Design

## Goal

Let a user focus on one existing incomplete task from the Todo widget and keep the focused task visible above the unchanged task list. A completed focus round records its active time into the task’s existing duration value. Whether that action also completes the task is always the user’s explicit choice.

The user-facing name of the field is **“时长”**. The existing implementation/data mapping remains `estimatedMinutes`; this design does not rename a Notion property or migrate user data.

## Scope

In scope:

- one active, in-memory Pomodoro session for one incomplete task
- 25-minute and 45-minute presets plus a custom whole-minute value from 1 through 480
- a conditional focus card above the existing Todo list while the session is active
- pause, resume, abandon, manual end, natural timer end, and a brief system sound at timer end
- cumulative duration writeback: 45 minutes plus a completed 25-minute round becomes 70 minutes
- a final, default-off “同时完成任务” switch that determines whether the task is also marked complete
- concise focus-specific dialogs and localized user-facing copy

Out of scope:

- a new Notion property, actual-time history, tomato counts, break flow, notifications, global shortcuts, or cross-device session recovery
- persistence of an active timer after app quit
- changes to Journal, settings, onboarding, mini mode, top bar, date navigation, normal task-row layout, or existing task create/edit/delete flows
- renaming the internal `estimatedMinutes` property or the existing Notion field mapping

## Existing Context

The Todo UI already renders tasks from `TodoListViewModel`; task changes travel through `NotionRepository`. `TaskItem.estimatedMinutes` is an optional integer and the existing repository mutation can write it together with the existing task title. Task completion already uses the task checkbox mutation.

The new feature must preserve those boundaries:

- views never call `NotionClient` directly
- the focus flow uses the current mapped duration field, rather than creating another field
- normal task behavior is unchanged when no session or focus dialog is visible

## Product Decisions

### Duration is cumulative

“时长” accumulates focus time rather than being replaced by a selected timer duration.

| Before round | Completed active time | After write |
| --- | --- | --- |
| 时长 45 分钟 | 25 分钟 | 时长 70 分钟 |
| no duration | 25 分钟 | 时长 25 分钟 |
| 时长 45 分钟 | manual end after 61 active seconds | 时长 47 分钟 |

For manual completion, only active focus time counts. Paused time and unused countdown time do not. Active seconds round up to a whole minute, with one minute as the minimum recorded duration after an explicit manual completion.

### Completion is a separate choice

Recording duration and marking a task done are different outcomes.

- The final “同时完成任务” switch is **off by default**.
- When off, the focus time is recorded but the task remains incomplete.
- When on, duration is recorded first; only after that succeeds is the task checkbox set to completed.
- A timer ending never completes a task implicitly.

This lets a user record today’s work on a multi-session task without prematurely completing it.

## User Flow

### 1. Start a focus round

1. An incomplete task exposes a small focus-start action.
2. The start dialog shows the selected task, 25 minutes, 45 minutes, and custom minutes.
3. Starting shows the active card above the task list. No active-card space exists before start.

The start dialog has no completion switch. Completion is relevant only when the user is ending a round.

### 2. Active focus card

The card keeps the task list visible and uses this fixed hierarchy:

- left: large countdown ring
- right: task title and current-round metadata
- below: equal `放弃 / 暂停（或继续） / 完成` controls

Only one task can be focused at a time. Other task focus-start controls are disabled while the session runs or is paused.

### 3. Pause and abandon

- Pause freezes both countdown and active-duration accumulation. The pause dialog allows resume or proceeding to abandon confirmation.
- Abandon requires confirmation. It removes the local session and writes neither duration nor task completion.

Both dialogs retain the task name because they are choices about the currently active task.

### 4. Manual end

Clicking `完成` on the active card opens a final dialog titled **“结束专注”**. It omits the repeated task title and shows:

- the exact active minutes that will be added to “时长”
- the default-off “同时完成任务” switch
- a remaining-time note
- `继续专注` and the dynamic primary action

| Switch state | Primary action | Result after confirmation |
| --- | --- | --- |
| Off | `记录时长` | Add active minutes to duration; task remains incomplete. |
| On | `记录并完成任务` | Add active minutes to duration, then complete the task. |

### 5. Natural timer end

At zero seconds the app stops the tick once, plays the system completion sound, calculates the completed round’s duration, and writes it to “时长”. When that write succeeds, the active card is removed and a final dialog titled **“本轮已完成”** appears.

It omits the repeated task title and states that the duration has already been recorded. The same completion switch remains off by default.

| Switch state | Primary action | Result |
| --- | --- | --- |
| Off | `保持未完成` | Retain the written duration; task remains incomplete. |
| On | `完成任务` | Retain the written duration and mark the task complete. |

### 6. Success state

After the user finishes either final flow, the success state shows concise result copy and one `知道了` button.

- Do not repeat the task title.
- Center the single button in the dialog; do not leave it in the left half of a two-button grid.

## Data and Error Rules

### Write ordering

When task completion is enabled, write operations are strictly ordered:

1. update the existing duration value
2. update the task completion checkbox

If duration writeback fails, do not complete the task. The final error state must state that the round ended but duration was not saved, offer retry/later, and reuse the same precomputed minute delta on retry so time is not double-counted.

If duration writeback succeeds but checkbox completion fails, retain the written duration and leave the task incomplete with the existing task-update error/retry behavior.

### Timer lifetime

The active session is memory-only. Quitting the app discards it and performs no automatic mutation. The timer should calculate elapsed time from dates rather than blindly decrementing state, preventing drift when the app is temporarily busy.

## UI Boundaries

- **Pomodoro visual and interaction source of truth:** [Pomodoro Task Flow Explorations.html](../prototypes/Pomodoro%20Task%20Flow%20Explorations.html). The implementation may reference this file only for the new Pomodoro UI: the start dialog, 25/45/custom duration controls, active card above the list, pause/abandon dialogs, final completion switch, and one-button success state.
- **Existing-product baseline:** the current production Todo UI is the source of truth for every area outside that new Pomodoro slice. It must remain visually and behaviorally unchanged; do not reinterpret, restyle, or reorganize surrounding task-list, top-bar, Journal, settings, or window UI from the prototype.
- **Reference hierarchy:** this Spec controls product behavior and data rules; the prototype controls the approved new Pomodoro layout, dialog composition, and visible copy; existing production UI controls all unchanged areas. If a screenshot or earlier conversation detail conflicts with the current prototype, follow the current prototype. If the prototype conflicts with this Spec’s behavior rules, follow this Spec and update the prototype before implementation.
- Screenshots in the discussion are review references only; they are not additional implementation sources and must not be used to introduce colors, layout, or controls absent from the approved prototype.
- Use the current WidgetToDo warm-white surface, thin beige borders, neutral actions, green completion state, and red abandonment state.
- Do not copy the reference image palette literally or introduce an unrelated blue palette.
- Do not move or restyle existing Todo list UI beyond the small focus action and conditional card/overlays.
- “时长” is the only user-visible field label in the focus flow. The internal `estimatedMinutes` name remains an implementation detail.

## Acceptance Criteria

- A task at “时长 45 分钟” becomes “时长 70 分钟” after a completed 25-minute round.
- The active card appears only after start, above the list, and disappears without empty spacing.
- The final completion switch is absent from start, default-off in final dialogs, and is the sole way a Pomodoro flow can complete a task.
- Manual end excludes pause and remaining time; natural end records the completed round duration.
- Final manual and natural-end dialogs omit duplicate task titles.
- Single-action success dialogs center “知道了”.
- All duration and completion mutations use `NotionRepository`; no unrelated UI or feature is changed.

## Risks and Rollback

The main product risk is conflating duration recording with task completion. The default-off switch and duration-first write order are mandatory safeguards. The feature is additive and has no migration; rollback removes the Pomodoro flow but must not automatically reverse duration values the user deliberately recorded.
