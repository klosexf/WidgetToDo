# Onboarding And Settings Modal HTML Parity Design

## Goal

Replace the SwiftUI visuals for the Notion onboarding modal and settings modal with a high-fidelity recreation of the corresponding HTML reference modals in `WidgetToDo-Welcome-Modal.html`, while preserving all existing functional behavior.

The target is not a stylistic approximation. It is a structure-preserving SwiftUI port of:

- `#connectModal` for `OnboardingView.Mode.onboarding`
- `#settingsModal` for `OnboardingView.Mode.settings`

## Scope

In scope:

- modal header layout
- modal body composition
- typography, colors, spacing, border radii, borders, shadows
- input chrome and inline icons
- status banner styling
- primary button styling and hover / press transitions
- onboarding and settings copy replacement to match the HTML

Out of scope:

- changing the outer app window size (`340 x 560`)
- changing data flow, validation rules, save behavior, or navigation behavior
- adding new modal close behavior
- changing help-sheet logic beyond matching the trigger copy
- modifying repository, client, token storage, or settings persistence behavior

## Existing Context

Current implementation:

- `ContentView.swift` contains `OnboardingView`
- `OnboardingView` renders one shared form layout for both onboarding and settings modes
- the form is bound directly to `OnboardingViewModel`
- the following functional behavior already exists and must remain unchanged:
  - `SecureField` bound to `viewModel.token`
  - `TextField` bound to `viewModel.tasksDatabaseInput`
  - `TextField` bound to `viewModel.journalDatabaseInput`
  - `normalizeTasksDatabaseInput()` on tasks field change
  - `normalizeJournalDatabaseInput()` on journal field change
  - `validateAndSave()` on primary action
  - token help `sheet`
  - settings-mode back action through `onBack`
  - conditional status rendering through `statusMessage` and `isErrorState`

Because the behavior surface is already isolated in `OnboardingView`, this is a visual rewrite rather than a logic rewrite.

## Constraints

### 1. Fixed host frame

The outer container stays `340 x 560`.

The HTML reference is wider and taller than the app window, so the SwiftUI implementation must preserve the same composition with scaled constants and optical corrections.

### 2. Full copy parity with HTML

Both modes must adopt the HTML copy rather than the current SwiftUI copy.

Required mapping:

- onboarding title bar: `内容 / 初始配置`
- onboarding hero title: `连接 Notion`
- settings title bar and heading: `设置`
- field labels: `Tasks Database`, `Journal Database`
- helper copy, security note, status copy, and primary button copy must align with HTML wording

### 3. Logic parity with existing SwiftUI

The following must not change:

- bindings to `OnboardingViewModel`
- field normalization behavior
- validation and save flow
- help sheet presentation behavior
- settings back navigation behavior
- disabled / loading behavior while `viewModel.isWorking` is true

### 4. No misleading affordances

The HTML reference shows close buttons in the title bars.

The current app does not expose close behavior in onboarding mode. The SwiftUI implementation must preserve the visual balance of the header without introducing a fake action that suggests closability when no such behavior exists.

For settings mode, the real back action must remain available and visually coherent with the HTML settings structure.

### 5. Onboarding back navigation

The onboarding-mode modal now needs a real back action at the top-left that returns to the welcome screen.

Constraints:

- this back action applies only to `OnboardingView.Mode.onboarding`
- `OnboardingView.Mode.settings` keeps its existing settings-specific back behavior
- returning to welcome must preserve in-memory form input (`token`, `tasksDatabaseInput`, `journalDatabaseInput`)
- the back action must only change screen state; it must not clear `OnboardingViewModel`

## Recommended Approach

Rebuild `OnboardingView` as a mode-switched modal renderer that ports the two HTML modal structures into SwiftUI while keeping the current bindings and event handlers.

Recommended internal structure:

- keep `OnboardingView` as the public entry point
- branch into two private mode-specific content builders
- use a local constants namespace for scaled metrics and colors
- introduce small private helper views only where they reduce duplication without flattening the differences between onboarding and settings layouts

Do not extract a shared app-wide theme layer for this task. The HTML parity target is modal-specific.

## Visual Mapping

## Base Scaling Strategy

Use the HTML modal as the source coordinate system and map it into the existing `340 x 560` host frame.

Scale the following from the HTML reference, then apply minor optical corrections where native macOS text rendering needs it:

- top and side padding
- title-bar height
- hero block spacing
- section spacing
- input height
- corner radii
- border widths
- shadow blur and offset
- button height and horizontal padding

Text sizes should follow the HTML hierarchy first and only deviate when native rendering looks materially too small or too large.

## Onboarding Mode Mapping

`mode == .onboarding` should visually mirror `#connectModal`.

Required structure:

1. title bar with top-left back button and `内容 / 初始配置`
2. visual close-button area at the trailing side
3. hero row with left illustration and right text
4. token section with label, help link, input, and security note
5. tasks database section
6. journal database section
7. status banner
8. primary action button

### Hero block

Recreate the HTML hero rhythm:

- left illustration sized and positioned like the reference
- title `连接 Notion`
- two-line descriptive text matching the HTML
- same top-to-form spacing as the reference after scaling

Use the existing local icon asset already used by the HTML reference when available to the app target. No SF Symbol fallback in the final view.

### Token section

The token section must preserve:

- inline header with label and `如何获取？`
- left lock icon inside the input chrome
- secure entry behavior through `SecureField`
- security note under the input

The help link must keep the current `sheet` behavior.

### Database sections

The tasks and journal sections must preserve:

- HTML labels `Tasks Database` and `Journal Database`
- passive helper text `粘贴整个URL自动提取`
- left document icon inside the input chrome
- existing text-field bindings and normalization behavior

### Onboarding title bar back action

Add a real back button on the leading side of the onboarding title bar.

Behavior:

- clicking it returns from `.onboarding` to `.welcome`
- current form values remain intact when the user re-enters onboarding

This is a product behavior change requested by the user and intentionally diverges from the static HTML reference.

## Settings Mode Mapping

`mode == .settings` should visually mirror `#settingsModal`.

Required structure:

1. title bar with `设置`
2. trailing close-button visual area
3. real back button row using the existing `onBack`
4. heading area with `设置` and descriptive paragraph
5. token section
6. tasks database section
7. journal database section
8. status banner
9. primary action button

The settings modal must feel like the HTML settings screen, not like the onboarding hero screen with a back button added on top.

## Inputs And Chrome

All fields should be ported to the HTML input treatment:

- soft background
- subtle border
- medium corner radius
- internal horizontal padding
- icon slot on the leading side
- placeholder and text colors aligned with the reference

Implementation must still use native SwiftUI input controls for editing and binding.

The styling layer must not interfere with:

- cursor placement
- secure text entry
- focus behavior
- disabled state during save

## Status Message Mapping

The current single `statusMessage` source should be rendered through two visual styles:

- success / neutral style when `isErrorState == false`
- warning / error style when `isErrorState == true`

When there is no message, the status block should collapse entirely, preserving the surrounding spacing behavior cleanly.

The content text comes from the existing view model except where HTML-specific default copy is intentionally shown by current state.

## Primary Button

Replace the default bordered prominent style with a custom button matching the HTML.

Required treatment:

- dark fill
- white content
- leading Notion mark or equivalent local icon treatment if feasible
- centered text
- trailing arrow
- shadow hierarchy matching the reference
- subtle hover lift
- subtle pressed compression
- disabled / working state compatible with the current save flow

When `viewModel.isWorking` is true, keep the existing loading semantics but render them inside the custom button shell.

## Animation

Two animations are required.

### 1. Modal content entry

On initial presentation of each mode, apply a short fade + upward settle transition inspired by the HTML modal animation.

This must be decorative only and must not delay interaction.

### 2. Primary button hover and press

Approximate the HTML interaction with SwiftUI:

- hover: slight upward offset, stronger shadow, arrow drift to the right
- press: subtle scale-down and shadow reduction

The target is perceptual parity with the reference, not engine-identical CSS behavior.

## Architecture

Preferred implementation location:

- keep all changes inside `WidgetToDo/ContentView.swift` unless a very small modal-style helper file materially improves clarity

Suggested internal breakdown:

- `OnboardingModalMetrics`
- `OnboardingModalColors`
- private helper builders for title bar, section header, input chrome, status banner, and primary button

Do not move onboarding-specific visuals into unrelated shared theme files.

## Testing And Verification

## Behavior verification

Confirm these behaviors remain intact:

- onboarding mode still shows token help sheet
- settings mode back button still calls `onBack`
- primary action still triggers `validateAndSave()`
- tasks and journal inputs still normalize on change
- secure token entry remains a `SecureField`
- loading state still disables the primary action and shows progress

## UI verification

Manual validation must cover both modes:

- title-bar layout
- onboarding hero composition
- settings heading layout
- input chrome and icon alignment
- helper copy and labels
- status banner visuals
- primary button normal / hover / pressed states
- overall composition inside `340 x 560`

## Automated verification

Run at minimum:

- `swift test --filter NotionFloatCoreSmokeTests`
- `swift test`

If the local environment still fails for unrelated `XCTest` availability reasons, record the exact command and failure instead of claiming success.

## Risks

### 1. Reference asset availability

The HTML reference uses local image assets that may not all be available to the app target. The implementation must confirm what the SwiftUI target can load before finalizing the hero area.

### 2. Optical mismatch after scaling

Direct proportional scaling may make the modal feel too compressed. Small explicit optical adjustments are allowed, but they must preserve the reference hierarchy and spacing relationships.

### 3. Native control rendering differences

SwiftUI input controls and hover handling will not match browser CSS pixel-for-pixel at the engine level. The goal is visual parity at the product level while retaining native editing behavior.

### 4. Header affordance confusion

The HTML title bars visually imply closability. The SwiftUI port must avoid shipping a clickable close control that has no real behavior in onboarding mode.
