# Floating Window Grid Snap Design

## Goal

Add a desktop-level drag interaction for the floating widget window that:

- shows a local set of large placement slots near the window while dragging
- allows the window to land only in those slots
- automatically snaps the window into the nearest valid slot when the user releases close to it
- provides clear, low-latency visual feedback during the whole drag interaction
- works on macOS 12 without relying on newer window-management APIs

## Scope

This design applies only to dragging the entire floating `NSPanel`.

Out of scope:

- rearranging cards inside the window
- system-wide tiling or Stage Manager integration
- saving multi-slot layouts across displays

## Existing Context

The current implementation in `WidgetToDo/FloatingWindowManager.swift` already:

- owns the floating `NSPanel`
- tracks drag start through `windowWillMove`
- snaps the panel origin to a fixed 20pt grid on mouse-up

The current behavior is too mechanical for the requested design because it:

- exposes no visible placement targets
- uses dense micro-grid snapping instead of large placement regions
- does not preview the likely drop position

## Recommended Approach

Implement a local, dynamic `3 x 3` placement overlay around the current window position.

During drag:

- create a transparent helper window on the same screen
- render up to 9 rounded placement slots centered around the window's current position
- continuously determine the nearest valid slot
- visually highlight the active slot and optionally show a preview outline at the snapped destination

On drop:

- animate the panel to the active slot if within the snap threshold
- otherwise animate to the nearest valid slot unless the distance exceeds a hard escape threshold
- hide the helper overlay immediately after settling

This keeps the interaction close to the provided mockup while staying feasible on macOS 12.

## Architecture

### 1. `FloatingWindowManager` responsibilities

Extend the existing manager to coordinate drag lifecycle:

- detect drag start
- create and destroy the overlay controller
- update slot selection while the window moves
- resolve the final snapped origin on drag end

It remains the source of truth for the real panel frame.

### 2. `WindowSnapOverlayController`

Add a dedicated AppKit controller for the visual helper overlay.

Responsibilities:

- own a transparent borderless helper window above the desktop-level panel
- render candidate placement slots and optional preview
- receive updated slot models from `FloatingWindowManager`
- stay non-interactive so it never blocks mouse input

This avoids mixing drag math with drawing code.

### 3. `SnapSlot` model

Introduce a small value type describing a candidate slot:

- slot id
- target panel origin
- panel frame at that origin
- slot frame used for visual rendering
- validity flag
- distance score from current panel position

This allows the selection logic and overlay rendering to share the same data.

### 4. `SnapLayoutEngine`

Add a pure helper that computes valid slots for the current screen and panel size.

Inputs:

- current panel frame
- current `visibleFrame`
- panel size
- slot spacing constants

Outputs:

- 2x2 or 3x3 local slot set clipped to screen bounds
- current nearest slot
- whether the current panel position is inside the soft snap radius

Keeping this logic pure makes it testable without AppKit windows.

## Interaction Flow

### Drag Start

When drag starts:

1. mark drag session active
2. capture the current screen and panel frame
3. build the initial slot set around the current panel origin
4. show the overlay window
5. highlight the nearest slot immediately

### Drag Update

As the window moves:

1. read the live panel frame
2. recompute the local slot set if the panel center has drifted far enough from the previous anchor
3. choose the nearest valid slot by comparing panel-center distance to slot-center distance
4. update the overlay highlight and preview frame

The slot set should not be regenerated every pixel. Re-anchor only after crossing a configurable threshold so the UI feels stable.

### Drag End

On mouse release:

1. finalize the nearest slot
2. clamp again to the current screen `visibleFrame`
3. animate the panel to the target origin with a short ease-out animation
4. hide the overlay window
5. clear drag session state

## Slot Generation Rules

### Local grid shape

Default to `3 x 3` slots centered on the current window.

The center slot is the current or nearest aligned placement. The other slots are offsets from that anchor using large step sizes derived from:

- panel width + horizontal gap
- panel height + vertical gap

This produces clearly separated large placement boxes instead of dense cell grids.

### Dynamic edge handling

If a slot would extend outside the current screen's `visibleFrame`, mark it invalid and omit it from interaction.

When near the edge of the screen:

- the visible slot set may shrink below 9 items
- the nearest valid slot must never place the window under the menu bar or Dock

### Candidate anchor

Use the panel's current origin rounded to the nearest layout stride as the slot anchor.

The stride is not a tiny grid size. It is the panel dimension plus a configured inter-slot gap:

- `horizontalStride = panelWidth + 32`
- `verticalStride = panelHeight + 32`

Exact values can be tuned during implementation.

## Snap Behavior

### Distance metric

Use panel-center distance to slot-center distance. This is more stable than comparing top-left origins and feels natural with large target areas.

### Thresholds

Use two thresholds:

- `softSnapRadius`: inside this distance, the slot is considered actively selected and previewed
- `hardSnapRadius`: on release, if no slot is within soft radius, still snap to the nearest slot if inside hard radius

Suggested starting values:

- `softSnapRadius = 90`
- `hardSnapRadius = 160`

These should be constants that can be tuned after live testing.

### Preview behavior

When inside soft radius:

- strongly highlight the slot
- show a faint preview outline of the panel at the final snapped frame

When outside soft radius but still near a valid slot:

- keep a weaker highlight on the nearest slot
- do not aggressively move the real window during drag

This avoids jumpy motion while still communicating intent.

## Visual Design

The overlay should visually echo the reference image:

- rounded rectangles matching the panel size
- subtle white or light-blue stroke
- low-opacity fill for inactive slots
- brighter stroke and slightly stronger fill for the active slot
- optional glow or shadow on the active slot

The overlay window itself should:

- have a clear background
- ignore mouse events
- not become key
- track the same screen as the dragged panel

## macOS 12 Compatibility

The implementation must avoid APIs introduced after macOS 12.

Use only:

- `NSPanel`
- `NSWindow`
- `NSWindowDelegate`
- `NSView` or `NSHostingView`
- `NSEvent` monitors
- `NSScreen.visibleFrame`
- `NSAnimationContext`

Do not depend on:

- SwiftUI window scene APIs added later
- Stage Manager hooks
- newer layout or material APIs that require Ventura or newer

For drag-end detection, prefer local/global mouse-up event monitors that are already compatible with macOS 12.

## Error Handling and Edge Cases

### Multi-display

- use the screen containing the largest portion of the panel frame
- if the panel crosses screens during drag, switch active screen only after a clear majority transition

### Rapid drag cancel

- if drag state ends without a valid slot or screen, fall back to the current panel frame clamped to `visibleFrame`

### Overlay desync

- if the overlay window fails to create or update, continue drag with snapping only
- visual assistance can fail open; core dragging must still work

### Existing custom panel level

- preserve the current desktop-adjacent window level behavior
- ensure the overlay level is above the panel but still non-intrusive

## Testing Strategy

### Unit tests

Add pure tests for the layout engine:

- center slot generation on a normal screen
- invalid slot filtering near edges
- nearest-slot selection
- clamping results to `visibleFrame`

### Manual verification

Verify on macOS 12:

- dragging starts without delay
- overlay appears immediately near the panel
- active slot highlight updates smoothly
- release near a slot snaps into place
- release far away either snaps to nearest allowed slot or stays safely clamped based on threshold rules
- no slot places the panel under menu bar or Dock
- behavior remains correct on a secondary display

## Implementation Plan Preview

Expected code changes:

- update `WidgetToDo/FloatingWindowManager.swift`
- add `WidgetToDo/WindowSnapOverlayController.swift`
- add `WidgetToDo/SnapLayoutEngine.swift`
- add tests for layout and nearest-slot math under `Tests/NotionFloatCoreTests`

## Open Decisions Resolved

These decisions are now fixed for implementation:

- drag target is the whole floating panel
- visual guide is local, not full-screen
- guide uses a small set of large placement slots, not a fine micro-grid
- default pattern is dynamic `3 x 3`
- compatibility target includes macOS 12
