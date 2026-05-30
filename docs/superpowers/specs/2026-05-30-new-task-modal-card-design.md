# New Task Modal Card Design

## Goal

Redesign the "新建任务" popup so it visually matches the existing widget task and journal surfaces, while preserving all current behavior, bindings, shortcuts, and submission flow.

The target is not a new interaction model. It is a visual alignment pass that makes the create-task form feel like a card that belongs inside the floating widget rather than a generic system modal.

## Scope

In scope:

- `NewTaskFormCard` visual hierarchy
- background, border, radius, shadow, and spacing
- title treatment
- text field chrome
- date row chrome
- action row emphasis
- validation-error visual styling as long as the same validation behavior is preserved

Out of scope:

- changing `NewTaskViewModel`
- changing create-task submission logic
- changing keyboard behavior (`Esc` cancel, `Enter` create)
- changing overlay dismissal behavior
- changing form fields, date-picker behavior, or focus behavior
- changing repository, client, cache, or Notion API behavior

## Existing Context

Current implementation:

- `FloatingWidgetView` presents a dimmed overlay when `newTaskViewModel.showForm` is true
- `NewTaskFormCard` is defined in `WidgetToDo/NewTaskFormCard.swift`
- the form currently uses a compact `VStack`, a plain text field with a default stroke, a compact date picker row, and a `.regularMaterial` rounded-rectangle background
- the rest of the widget already has a more specific visual language:
  - warm light-gray shell background
  - low-contrast borders
  - rounded panels with soft but readable shadows
  - tight spacing rhythm
  - restrained typography and iconography

The visual mismatch comes from the create-task form still reading as a generic macOS sheet while the parent widget has already moved to a custom card system.

## Design Direction

Recommended direction: **embedded floating card**

This is the user-selected option.

The create-task popup should feel like:

- a lightweight editing card lifted from the task panel
- visually related to the task list and journal editor
- clearly modal enough to focus attention
- not as heavy or ceremonial as onboarding/settings center modals

It should not feel like:

- a system material dialog
- a separate product surface with its own theme
- a full settings sheet

## Visual Model

### 1. Container

Replace the current `.regularMaterial` card with a custom surface derived from the widget panel language.

Required traits:

- warm off-white / light gray fill
- subtle border
- medium-large radius consistent with widget cards
- soft shadow that lifts the card above the dimmed overlay without making it feel heavy

Recommended outcome:

- the card reads as part of the same design family as the task panel background and action menus
- the card remains visually separable from the task list beneath it

### 2. Title Row

Keep the same semantic title: `新建任务`

Adjust the presentation:

- remove the emoji-led title treatment
- use a compact leading icon treatment that matches the widget tone better than inline emoji
- title size and weight should align with the task/journal hierarchy rather than default modal heading styles

The title row should feel calm and integrated, not promotional.

### 3. Input Field

Keep the single title field and the existing binding to `viewModel.title`.

Update the chrome to match the widget:

- slightly taller field
- softer background
- low-contrast border
- more internal horizontal breathing room
- validation-failed state still turns visually urgent, but only as a state change on the same field style

`ShakeEffect` remains unchanged.

### 4. Date Row

Keep the current compact date picker and the same binding to `viewModel.taskDate`.

Restyle the row so it feels like a structured metadata row inside the card:

- lighter icon treatment
- more deliberate alignment
- smaller gap between icon and picker
- date chrome should visually harmonize with the task metadata style

The row stays functionally identical.

### 5. Action Row

Keep both actions and their current meanings:

- `Esc 取消`
- `Enter 创建`

Adjust hierarchy only:

- left action stays visually quiet
- right action becomes the clear primary emphasis
- keep text actions rather than turning them into large filled buttons, so the card still feels lightweight and native to the widget

### 6. Layout Rhythm

The overall layout should use the same compact spacing discipline as the widget:

- tighter top-to-title spacing than onboarding/settings modals
- balanced spacing between title, field, metadata row, and actions
- enough bottom padding to avoid crowding the action row

The form should remain approximately the same footprint as today so its placement and overlay behavior do not shift dramatically.

## Behavioral Constraints

The following must remain unchanged:

- `TextField("标题(必填)", text: $viewModel.title)`
- `DatePicker("", selection: $viewModel.taskDate, displayedComponents: .date)`
- `viewModel.dismissForm()` on cancel
- `viewModel.submit()` on create
- title autofocus on appear
- validation text when `formState == .validationFailed`
- shake animation on validation failure
- outside-tap dismissal handled by the parent overlay

No new controls, no field reordering, and no new confirmation step.

## Implementation Boundary

Primary edit target:

- `WidgetToDo/NewTaskFormCard.swift`

Optional secondary target only if it materially improves consistency:

- extract a very small private visual constants helper from `ContentView.swift`, or duplicate a minimal subset of values if extraction would create unnecessary coupling

Do not modify:

- `NewTaskViewModel`
- repository / infrastructure files
- keyboard shortcut handling outside the existing form logic

## Testing And Verification

Required verification after implementation:

1. `swift test`
2. targeted manual runtime check in the macOS app:
   - open todo tab
   - click `+`
   - confirm popup styling matches the widget card language
   - confirm text field autofocus still works
   - confirm outside click dismisses
   - confirm `Esc` cancels
   - confirm `Enter` creates
   - confirm empty-title validation still shakes and shows error text

If `swift test` is still blocked by the existing local `XCTest` environment issue, record the exact blocker and do not claim automated verification passed.

## Risks

### 1. Over-styling the card

If the card becomes too decorative, it will start competing with the main panel and feel heavier than the rest of the widget.

Constraint:

- prefer restrained contrast and compact emphasis

### 2. Accidental behavior drift

Because this is a small component, it is easy to "just clean up" behavior while restyling.

Constraint:

- keep the exact interaction contract intact and limit edits to presentation

### 3. Theme duplication

Pulling too much widget palette code into the form may create awkward coupling.

Constraint:

- share only the minimum visual constants needed, or keep the values local if that is clearer

## Recommended Implementation Approach

1. Restyle `NewTaskFormCard` in place without changing its public API.
2. Reuse the widget's visual language for surface, border, radius, and typography.
3. Keep the existing form structure and event handlers unchanged.
4. Verify behavior after styling, not just compilation.
