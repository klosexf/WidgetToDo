# Settings Visual Alignment Design

## Goal

Align the settings screen's shared form presentation with the existing onboarding "连接 Notion" configuration modal so that typography, spacing, control sizing, and layout rhythm match visually.

This is a style-only adjustment. It must not change interaction behavior, data binding, async flow, or business logic.

## Scope

In scope:

- settings modal header padding and title rhythm
- shared form section spacing
- label, helper text, and status text font sizes
- input shell sizing, padding, and icon spacing
- primary button sizing and surrounding spacing
- shared status banner sizing and spacing

Out of scope:

- changing any onboarding visuals
- changing settings-only copy content
- changing reset flow behavior or confirmation flow
- changing `Button` actions, `Binding`s, `Task` execution, `sheet`, `confirmationDialog`, or repository/view model wiring

## Existing Context

`OnboardingModalView` already renders both onboarding and settings through the same component tree in `ContentView.swift`, but many visual values still branch on `mode == .settings`.

Today this causes the settings screen to diverge from the onboarding modal in several places:

- header uses larger padding in settings mode
- section labels and helper copy use slightly larger font sizes
- input shells use larger icon size, text size, and vertical padding
- status banner and primary button spacing are also slightly looser

Because the two screens already share the same structural view hierarchy, the safest change is to collapse the visual divergence for the shared form regions without touching event or data flow code.

## Constraints

1. Only visual properties may change.
   Allowed change types include `font`, `padding`, `frame`, `spacing`, and other presentation-only constants.

2. Logic must remain byte-for-byte equivalent in intent.
   No changes to:
   - button handlers
   - `@Binding` usage
   - `onChange`
   - async task launching
   - sheet / dialog presentation
   - view model calls

3. Settings-only content blocks may keep their content differences.
   The intro copy still says "设置"; the reset section remains present only in settings mode. Only their spacing and typography may be tuned when needed for consistency.

## Recommended Approach

Use the existing onboarding metrics as the visual source of truth for all shared form regions, and remove settings-specific presentation drift where it is not required by content differences.

This means:

- header padding in settings mode should match onboarding rhythm
- shared section vertical spacing should match onboarding section spacing
- section titles, helper copy, and token hint text should use onboarding font sizing
- input shell icon size, icon spacing, text size, and inner padding should use onboarding values
- status banner spacing and typography should use onboarding values
- primary action block should use onboarding-sized presentation values

Settings-only content differences remain conditional, but those conditions should no longer introduce a separate size system for the shared form UI.

## File Impact

Expected implementation impact:

- `WidgetToDo/WidgetToDo/ContentView.swift`
- `progress.md`

No other production files should need changes for this task.

## Verification Plan

1. Source inspection:
   Confirm changed lines are limited to presentation modifiers and style constants.

2. Automated verification:
   Run `swift test`.

3. UI verification:
   If app runtime is available, open the settings screen and compare it against the onboarding configuration modal for:
   - header spacing
   - label sizing
   - input field height
   - section spacing
   - primary button size and placement

   If local UI runtime is blocked, record that explicitly instead of claiming visual verification.

## Risks

- Because both modes share one file, over-collapsing conditional branches could accidentally affect settings-only content blocks. The implementation should limit edits to presentation modifiers and constants already gated in shared regions.
- Some settings content is shorter than onboarding copy, so perfect visual equality is not expected at the content level; the goal is consistent sizing and rhythm, not identical text flow.
