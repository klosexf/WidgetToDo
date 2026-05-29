# Onboarding Modal Visual Alignment Design

## Goal

Systematically adjust the SwiftUI "连接 Notion" onboarding modal so its typography scale, spacing rhythm, control sizing, and element proportions align with the `#connectModal` reference in `WidgetToDo-Welcome-Modal.html`.

This is a visual alignment task only. It must not change interaction behavior, data binding, conditional rendering, validation flow, or any persistence / repository behavior.

## Scope

In scope:

- onboarding-mode modal only: `OnboardingView.Mode.onboarding`
- font sizes and text hierarchy
- vertical and horizontal spacing
- input field height, padding, corner radius, icon slot sizing
- hero illustration size and hero text spacing
- status banner sizing and spacing
- primary button height, inner spacing, icon sizing, and optical weight
- header padding and title-bar balance

Out of scope:

- `OnboardingView.Mode.settings`
- copy/content changes
- button actions, `Task` execution, `sheet`, `confirmationDialog`
- `OnboardingViewModel`, `RootViewModel`, repository, Notion client, stores
- app window size or overall navigation flow

## Existing Context

Current implementation already ports the onboarding modal into SwiftUI inside `WidgetToDo/ContentView.swift`:

- `OnboardingView` renders onboarding and settings modes through a shared structure with mode-specific sections
- onboarding uses `onboardingHero`, `tokenSection`, `databaseSection`, `statusBanner`, and `primaryButton`
- all behavior is already attached at the view layer:
  - token entry uses `SecureField`
  - database fields use `TextField`
  - tasks / journal inputs still normalize through `normalizeTasksDatabaseInput()` and `normalizeJournalDatabaseInput()`
  - primary action still calls `validateAndSave()`
  - token help still opens the same `sheet`
  - loading / disabled state still derives from `viewModel.isWorking`

Because the behavior contract is already correct, this task should stay inside visual constants and layout modifiers.

## Constraints

### 1. CSS-equivalent changes only

Only visual properties should change, equivalent to CSS adjustments such as:

- `font-size`
- `line-height`
- `margin`
- `padding`
- `gap`
- `width`
- `height`
- `border-radius`

Do not alter:

- event handlers
- binding targets
- control types
- conditional branches
- save / validation call paths

### 2. Onboarding only

The user explicitly limited this pass to the "连接 Notion" modal. Settings-mode layout must remain unchanged in this task.

### 3. HTML is the visual source of truth

Use `WidgetToDo-Welcome-Modal.html` `#connectModal` as the visual reference for:

- header/body padding rhythm
- hero illustration scale and gap
- title / body copy hierarchy
- form section density
- input field proportions
- status row thickness
- primary button proportions

The result should match the HTML modal's visual system, not merely feel "similar".

### 4. Preserve current SwiftUI structure where possible

This task should not introduce a broad refactor. The preferred approach is to keep the existing onboarding structure and retune its metrics so the visual output moves toward the reference without increasing behavioral risk.

## Reference Mapping

### HTML source characteristics

The reference `#connectModal` uses these core visual proportions:

- `.modal-body { padding: 20px 16px; }`
- `.hero { gap: 14px; margin-bottom: 20px; }`
- `#connectModal .illustration { width: 68px; height: 68px; }`
- form sections are tighter than the current SwiftUI port
- input fields visually read close to a `44px` control height
- the primary button reads close to a `44px` action height with lighter optical weight than the current SwiftUI version

### SwiftUI alignment strategy

Map those HTML proportions into the existing `340 x 560` host window by retuning onboarding-only metrics:

- reduce onboarding body horizontal padding from the current wider layout toward HTML's `16px`
- reduce onboarding top padding toward HTML's `20px`
- shrink hero illustration from the current oversized presentation toward `68 x 68`
- tighten hero text gap and section-to-section spacing
- reduce input vertical padding to achieve a denser control height
- reduce button height / icon size slightly so the call-to-action no longer outweighs the form

### Optical rather than literal parity

SwiftUI text rendering and native controls will not produce DOM-identical line boxes. Use HTML as the source system, but prefer optical parity over literal one-to-one translation where the platforms differ.

## Recommended Implementation

Keep all changes local to `WidgetToDo/ContentView.swift`.

Implementation approach:

1. Add onboarding-specific metrics inside `OnboardingModalMetrics` rather than changing shared settings metrics blindly.
2. Apply onboarding-only padding/spacing values at the `ScrollView` content container.
3. Retune `onboardingHero` to match the HTML hero proportion.
4. Retune `tokenSection` and `databaseSection` typography and section spacing.
5. Retune `inputShell` dimensions and icon sizing to better match the HTML controls.
6. Retune `statusBanner` and `primaryButton` sizing while preserving existing behavior.

Avoid:

- mode-wide refactors
- new behavioral abstractions
- moving logic out of `OnboardingView`

## Detailed Design

### Header

For onboarding mode:

- keep the same logical header structure
- retain the current title and back behavior
- reduce padding so the visual density better matches the HTML title bar
- keep the divider and balance placeholder behavior intact

No new controls should be introduced.

### Hero block

Update `onboardingHero` so the illustration/text block aligns with the HTML reference:

- illustration target size should move toward `68 x 68`
- hero row gap should move toward `14`
- title should scale down from the current oversized presentation
- description should preserve two-line rhythm but read closer to the HTML body scale

### Form sections

For `tokenSection` and `databaseSection`:

- labels and helper links should use a tighter, consistent hierarchy
- section internal spacing should be reduced
- section-to-section spacing should align with the HTML modal's denser rhythm

The token help button stays the same action-wise.

### Input chrome

For `inputShell`:

- reduce vertical padding to bring the control closer to HTML height
- keep horizontal padding balanced with the icon slot
- slightly reduce icon size and icon frame width if needed
- preserve current border/background styling family unless a small visual correction is needed for parity

The fields must remain native `SecureField` / `TextField`.

### Status banner

Keep conditional rendering unchanged, but reduce visual thickness so the banner sits in the same hierarchy as the HTML status row rather than reading like a separate card.

### Primary button

Keep the same action and loading semantics, but retune:

- height
- icon size
- arrow size
- internal spacing
- hover motion amplitude

The button should visually match the HTML reference better without changing behavior.

## File Impact

Expected file changes:

- modify `WidgetToDo/ContentView.swift`
- modify `progress.md` after implementation and verification

No other production file should be required for this task.

## Verification

Required verification after implementation:

- `swift test`
- if available, app-level manual UI check of the onboarding modal against the HTML reference

If UI runtime verification is blocked by the environment, record the blocker explicitly rather than claiming visual parity is verified.

## Risks

- onboarding and settings currently share some metrics/helpers; careless edits could unintentionally drift settings visuals
- changing shared `inputShell` values can affect both modes unless onboarding-only branching is applied deliberately
- overly literal HTML number mapping can look off in SwiftUI due to platform text metrics

## Decision

Proceed with a narrow single-file visual retuning of onboarding mode only, using HTML `#connectModal` as the source visual system and preserving all current behavior contracts.
