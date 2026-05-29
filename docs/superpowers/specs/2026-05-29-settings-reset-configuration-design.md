# Settings Reset Configuration Design

## Goal

Add a dedicated `初始化配置` module to the settings screen so a user can intentionally clear the current Notion setup and restart the full configuration flow from the welcome screen.

The reset must clear:

- saved Notion token
- saved tasks database ID
- saved journal database ID
- in-memory configuration flow state shown by the app UI

The reset must not clear:

- cached tasks
- cached journal content
- local SQLite cache files

## Scope

This design applies only to the existing settings flow rendered from `RootViewModel.Screen.settings`.

In scope:

- a new destructive section inside the settings screen
- a prominent reset button
- explicit confirmation before destructive execution
- visible reset progress and completion / failure feedback
- navigation back to the welcome screen after a successful reset
- resetting in-memory onboarding form state so the user can start from scratch

Out of scope:

- changing `Package.swift`, `.xcodeproj`, or entitlements
- changing `NotionRepository` persistence contracts beyond reusing the existing reset entry point
- deleting or clearing SQLite cache content
- changing the welcome screen design or onboarding validation rules
- adding a second reset entry point outside the settings page

## Existing Context

Current relevant behavior:

- `RootViewModel` owns the app screen state: `.loading`, `.welcome`, `.onboarding`, `.settings`, `.widget`
- `ContentView.swift` renders `OnboardingView` in `.settings` mode
- `OnboardingViewModel` already holds editable configuration state:
  - `token`
  - `tasksDatabaseInput`
  - `journalDatabaseInput`
  - `statusMessage`
  - `isWorking`
  - `isErrorState`
- `NotionRepository.resetConfiguration()` already clears only:
  - `KeychainTokenStore`
  - `SettingsStore`

This means the required persistence boundary already exists. The missing behavior is the settings-screen UX and the app-level navigation/state reset after success.

## Constraints

### 1. Reset boundary is intentionally narrow

The feature must clear only the configuration needed to reconnect Notion.

Do not clear:

- `SQLiteCache`
- cached task rows
- cached journal entries
- pending local content unrelated to token / database ID persistence

### 2. Confirmation is mandatory

The reset is destructive because it removes the active connection credentials and database bindings.

The user must explicitly confirm after pressing the visible reset button. A single-click destructive action is not acceptable.

### 3. Feedback must stay readable and in Chinese

During reset:

- the user must see that work is in progress
- the destructive control must become unavailable
- failure messages must remain readable Chinese descriptions

### 4. Successful reset must return to the welcome flow

After a successful reset:

- the settings screen must no longer remain visible
- the app must navigate to `RootViewModel.Screen.welcome`
- the next press on the welcome CTA must allow a full restart through `.onboarding`

### 5. Keep repository layering intact

The settings screen must not bypass `OnboardingViewModel -> NotionRepository`.

No view or window-layer code may directly manipulate `KeychainTokenStore` or `SettingsStore`.

## Recommended Approach

Implement the feature as a settings-only destructive module inside `OnboardingView.Mode.settings`, backed by a new app-level reset flow coordinated by `RootViewModel` and executed through `OnboardingViewModel`.

Recommended responsibilities:

- `OnboardingView`
  - renders the destructive section
  - presents confirmation UI
  - shows local in-flight feedback for reset
  - triggers a provided reset action
- `OnboardingViewModel`
  - exposes a reset operation that reuses `NotionRepository.resetConfiguration()`
  - clears in-memory form and status state after success
  - surfaces readable failure state on error
- `RootViewModel`
  - owns the post-reset navigation decision
  - moves the app to `.welcome` after successful reset
  - prepares the onboarding flow for a clean restart

This keeps persistence, UI state, and navigation responsibilities separated along existing boundaries.

## UX Design

## Section Placement

Show the new module only in `settings` mode.

Recommended placement:

- below the existing configuration fields
- below any current status banner
- visually separated from the main save action

The destructive section should read as a separate capability, not as a variant of `保存设置`.

## Section Composition

The module should include:

1. a heading such as `初始化配置`
2. a short explanatory description
3. a high-contrast destructive button

The description must:

- explain that the action clears the current Notion token and database configuration
- explain that local cached tasks and journal content are retained
- explain that the app will return to the welcome page

The button should be visually more cautionary than the primary save button, using a destructive color treatment.

## Confirmation Design

After the user presses `初始化配置`, present a confirmation dialog / alert.

The confirmation copy must make these points explicit:

- this will clear the current Notion configuration
- this will not clear local cached tasks or journal cache
- after reset the app will return to the welcome page

Required actions:

- confirm reset
- cancel

Cancel must leave all current form content unchanged.

## Reset Progress Feedback

When the user confirms:

- disable the destructive button
- disable duplicate reset submission
- show a visible in-progress message such as `正在重置配置...`

If the existing settings save button is also present, it should not compete visually with the active reset state. At minimum, the reset path itself must be protected from double submission.

## Success Behavior

On success:

1. clear the in-memory onboarding fields
2. clear error styling for the old configuration session
3. set a success-state message only if it is visible before navigation, otherwise avoid stale messaging
4. navigate immediately to the welcome screen

After navigation:

- the welcome screen becomes the visible restart point
- pressing `开始配置` enters the normal onboarding flow with empty inputs

The user should not bounce back into `settings` after reset.

## Failure Behavior

If reset fails:

- remain on the settings screen
- keep the current app screen unchanged
- show a readable Chinese error message through the existing status-message system when possible
- re-enable the destructive button for retry

Do not partially navigate to the welcome screen on failure.

## State Model

The reset feature needs one transient UI concern beyond the current save flow:

- whether reset confirmation is presented

The actual reset execution can reuse `OnboardingViewModel.isWorking` if that state is intentionally shared with save, or use a dedicated reset-in-flight flag if separate feedback is clearer.

Recommendation:

- keep save and reset mutually exclusive from the UI perspective
- prefer a dedicated reset action path that still updates the shared status banner

This avoids ambiguous button states where the user cannot tell whether the app is validating, saving, or resetting.

## Architecture

Preferred change surface:

- `WidgetToDo/WidgetToDo/ContentView.swift`
  - add settings-only destructive section UI
  - add confirmation presentation
  - wire a reset callback from `RootViewModel`
- `WidgetToDo/WidgetToDo/OnboardingViewModel.swift`
  - expand reset behavior to clear in-memory fields and status state after repository reset
- `WidgetToDo/WidgetToDo/ContentView.swift` `RootViewModel`
  - add a reset coordinator method that awaits the view-model reset and then sets `screen = .welcome`
- `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift`
  - add a source-level smoke guard for the new destructive section and reset flow contract

Do not move this behavior into window-management classes.

## Testing Strategy

### Smoke guard first

Add a failing smoke test before production changes that asserts the source contract for:

- settings mode contains `初始化配置`
- confirmation copy exists
- settings reset path calls the reset API
- successful reset path returns to `.welcome`

This is a source-level guard consistent with the existing smoke-test style in the repo.

### Functional verification

Required automated verification:

- `swift test --filter NotionFloatCoreSmokeTests`
- `swift test`

If `swift test` is blocked by the current local XCTest environment, record the exact blocker instead of claiming success.

### Manual UI verification

Because this is a settings-screen interaction change, manual validation is required:

1. open settings from a configured app state
2. verify the destructive section is visible and visually distinct
3. press the reset button and cancel once
4. confirm that the existing token / database values remain visible after cancel
5. press the reset button again and confirm
6. verify in-progress feedback appears
7. verify the app returns to the welcome screen
8. press the welcome CTA and confirm onboarding opens with empty token / database inputs
9. verify cached local content is not explicitly cleared by the reset path

## Risks

- If reset reuses `isWorking` without clear copy, the user may not understand whether the app is saving or resetting.
- If `RootViewModel` changes the screen before the reset finishes, the UI may navigate away even when persistence clearing fails.
- If `OnboardingViewModel` does not clear its in-memory fields after success, reopening onboarding may show stale values despite the persisted configuration being removed.

## Rollback

Safe rollback point:

- revert the settings reset UI and `RootViewModel` reset coordinator
- leave `NotionRepository.resetConfiguration()` unchanged because it already exists and is part of current behavior

This limits rollback to the new screen flow and view-model state reset logic.
