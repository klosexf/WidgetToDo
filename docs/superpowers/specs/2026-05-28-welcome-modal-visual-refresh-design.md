# Welcome Modal Visual Refresh Design

## Goal

Replace the current SwiftUI welcome screen visuals with a high-fidelity recreation of the welcome modal defined in `WidgetToDo-Welcome-Modal.html`, while preserving all existing welcome-screen behavior.

The target is not a generic redesign. It is a structure-preserving visual port from the HTML reference into the existing `340 x 560` SwiftUI container.

## Scope

This design applies only to the welcome screen shown from `RootViewModel.Screen.welcome`.

In scope:

- visual hierarchy
- spacing and sizing
- color palette
- typography treatment
- rounded corners and shadows inside the welcome content
- illustration cropping behavior
- primary button hover/press animation
- welcome-screen entry animation

Out of scope:

- changing the outer `ContentView` frame (`340 x 560`)
- changing onboarding navigation
- changing copy text
- adding new business logic
- adding a real close action that does not exist today

## Existing Context

Current implementation:

- `ContentView` renders `WelcomeView` when `rootViewModel.screen == .welcome`
- `WelcomeView` exposes one behavior surface: `onStartConfig`
- clicking the primary button transitions to onboarding by changing `rootViewModel.screen`

Current visual implementation is intentionally minimal:

- SF Symbols replace the HTML illustration
- spacing is hand-tuned and not derived from the reference modal
- button style uses the default prominent bordered style
- there is no dedicated animation or shadow system matching the HTML reference

Because the behavior surface is small and isolated, this is a good candidate for a pure visual rewrite with unchanged logic.

## Constraints

### 1. Fixed container size

The outer view must remain `340 x 560`.

The HTML reference modal is designed at `480px` width, so the SwiftUI implementation must use a deterministic scaled mapping rather than direct 1:1 values.

### 2. Logic preservation

The following must remain unchanged:

- `onStartConfig` as the only primary action entry point
- welcome screen conditional rendering
- existing text content
- progress indicator count and meaning (`5` dots, first active)

### 3. No fake affordances

The HTML reference shows a close button in the modal header. The current app does not have welcome-close behavior. The SwiftUI port must preserve the visual balance of that header area without introducing a misleading clickable close control.

## Recommended Approach

Rebuild `WelcomeView` as a reference-driven component tree using scaled visual constants derived from the HTML modal.

The implementation should:

- keep the existing SwiftUI entry point and callback
- replace the current free-form `VStack` spacers with a tokenized layout
- introduce a small internal constants namespace for reference-derived values
- use the existing image asset that matches the HTML welcome illustration source
- reproduce HTML interaction polish with SwiftUI animation primitives

This gives the best match to the HTML reference without contaminating behavior logic or requiring WebView-based rendering.

## Visual Mapping

### Base scaling rule

Use the HTML modal width as the source coordinate system:

- source width: `480`
- target content width: current welcome content width inside the `340` container after horizontal padding

All major spatial values should be scaled from the source values, then rounded to stable pixel-friendly SwiftUI constants.

Do not scale blindly for every detail. Use scaled values for:

- padding
- vertical rhythm
- illustration viewport
- button dimensions
- corner radii
- shadow blur and offsets

Text sizes may need slight optical correction after scaling to keep macOS rendering visually aligned with the reference.

### Layout structure

The SwiftUI hierarchy should visually mirror the HTML modal:

1. top header strip aligned to the trailing edge
2. large cropped illustration area
3. title
4. subtitle line with inline `Notion` badge
5. features line
6. primary CTA
7. 5-dot progress indicator

The screen should feel vertically centered like the reference instead of relying on large free spacers above and below each block.

### Header treatment

Recreate the HTML welcome-modal header rhythm:

- preserve a dedicated top zone
- align a non-interactive visual placeholder at the trailing side
- remove the current empty full-screen spacer feeling

This preserves the modal composition from the reference without creating a dead button.

### Illustration treatment

Port the HTML illustration behavior, not just the image:

- use a dedicated fixed-height illustration viewport
- clip overflow
- use cover-style scaling
- preserve the reference crop bias (`object-position` equivalent) so the subject sits slightly lower than center
- keep the illustration visually dominant over text

The existing SwiftUI SF Symbol row should be removed entirely.

### Typography treatment

Title:

- bold, compact tracking
- visually closer to the HTML `26px / 700` heading than the current system semibold title

Subtitle and features:

- medium-light secondary color hierarchy
- tighter control over line spacing
- `Notion` rendered as an inline badge with light background and small corner radius

### CTA treatment

The CTA must stop using `.borderedProminent`.

It should become a custom-styled SwiftUI button with:

- dark fill matching the HTML accent color
- white label
- icon + text + arrow layout
- larger internal horizontal padding
- medium corner radius
- shadow matching the reference hierarchy
- hover and press feedback

Hover behavior should approximate the HTML:

- slight upward movement
- stronger shadow
- arrow nudges right

Press behavior should remain subtle and native-feeling on macOS.

### Progress dots

Keep the existing five-step meaning, but restyle to match the HTML density:

- smaller spacing
- softer inactive dots
- one active accent dot

## Animation

Two animations are needed.

### 1. Screen entry

On first appearance of the welcome screen, animate the content as a single unit with a short fade + upward settle animation inspired by the HTML `modalAppear`.

The animation should be decorative only and must not delay interaction.

### 2. CTA state transition

Button hover and press states should animate with short ease timing.

The arrow movement should be tied to hover state only.

## Architecture

Implementation should stay inside `WelcomeView.swift` unless a tiny helper type is clearly justified.

Preferred internal breakdown:

- `WelcomeMetrics`: scaled constants
- `WelcomePrimaryButtonStyle`: local button style for hover/press visuals
- small private subviews only if they reduce duplication without scattering context

Do not move welcome-specific styling into shared global theme files for this task.

## Asset Strategy

Use the same illustration asset referenced by the HTML welcome modal if it already exists in the app target or can be referenced through existing asset loading patterns.

If the exact asset is not available to the app target, use the closest existing local asset already present in the welcome HTML workflow and scale/crop it consistently.

No new remote assets. No SF Symbols fallback in the final design.

## Testing And Verification

### Logic verification

Confirm the following remain unchanged:

- welcome screen still renders when bootstrap is incomplete
- CTA still triggers onboarding transition through the existing callback

### UI verification

Manual validation should check:

- illustration crop and visual balance
- subtitle badge styling
- CTA normal / hover / pressed states
- progress dots alignment
- overall vertical composition inside `340 x 560`

### Automated verification

Run:

- `swift test`

If local environment still blocks tests for unrelated reasons, record the exact failure instead of claiming success.

## Risks

### 1. Asset availability mismatch

The HTML reference may rely on an image file that is not compiled into the app target. If that happens, the implementation must first confirm what the app can actually load before finalizing the illustration port.

### 2. Optical mismatch after strict scaling

Simple proportional scaling from `480` to `340` may make text or button feel too small. Optical correction is allowed, but only in small, explicit adjustments.

### 3. Hover fidelity differences

SwiftUI hover animation will approximate the HTML reference but cannot match browser rendering exactly. The goal is perceptual parity, not identical engine behavior.

## Non-Goals Recap

This task does not:

- redesign onboarding
- resize the app window
- add a dismiss flow for welcome
- refactor global theming
- change repository, ViewModel, or data flow code
