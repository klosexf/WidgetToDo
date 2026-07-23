# Language Setting Design

## Goal

Add a `Language` item at the top of the configured Settings screen. It lets the user choose `简体中文`, `English`, or `Français`; the default is `简体中文`.

The choice must update all app-owned user-facing copy immediately and survive app relaunches. The `Language` item title and the three option names are intentionally fixed in those exact forms regardless of the active language.

## Scope

In scope:

- persistent app-language preference with a Simplified Chinese default
- immediate runtime language switching without Notion validation or a window restart
- localized copy in the welcome, onboarding, settings, floating widget, mini capsules, task forms, journal, toast, confirmation dialogs, help sheets, menu-bar menu, app Settings scene, accessibility labels, validation feedback, and readable app errors
- persistence and backward-compatibility tests
- manual UI verification across all three languages

Out of scope:

- translating user-owned Notion database property names, task titles, journal content, Notion page content, or raw Notion error details
- changing Notion API requests, token storage, SQLite cache ownership, package definitions, Xcode project settings, or entitlements
- adding locale auto-detection, more languages, right-to-left support, or language-specific typography changes

## Existing Context

- `RootViewModel` owns the visible screen and constructs the existing feature view models.
- `OnboardingView` is reused for onboarding and the configured settings screen. Its settings content is scrollable and currently begins with explanatory copy followed by Notion connection fields.
- `SettingsStore` persists `AppSettings` for the configured Notion workspace. `resetConfiguration()` currently clears that file and the Keychain token.
- User-facing strings are currently embedded across SwiftUI views, AppKit menu code, view models, core validation services, and error types.
- The SwiftPM core target is testable with `swift test`; the SwiftUI/AppKit target needs Xcode build and hands-on UI verification.

## UX Design

### Placement and fixed labels

Show a dedicated row immediately below the settings intro and before `Notion Token` (approved layout A).

The row contains:

- a globe icon
- the fixed title `Language`
- the currently selected fixed native option name and a disclosure indicator

The menu has exactly three choices, always written as:

1. `简体中文`
2. `English`
3. `Français`

`Language` and these option names must not be translated. Every other app-owned user-facing string changes with the selected language.

### Selection behavior

On menu selection:

1. update the in-memory language store on the main actor
2. redraw the current screen, including any currently visible status or form feedback, in the new language
3. persist the preference through the repository and `SettingsStore` without validating Notion fields, writing the Keychain token, or fetching network data

If persistence fails, restore the prior in-memory language and show a readable save-failure banner in that restored language. No Notion data, token, database binding, or cache data may be altered by this failure.

### Defaults and reset behavior

- Fresh launch, missing language preference, corrupt/unknown saved language value, and payloads produced by older releases all use `简体中文`.
- `初始化配置` must keep the language choice. It clears Notion connection configuration only; it must not reset an app preference that is unrelated to the connection.

## Architecture

### Language domain model and persistence

Add a Codable, Sendable `AppLanguage` value with three supported cases and a `simplifiedChinese` default.

Keep this preference separate from `AppSettings`, because `AppSettings` requires valid database IDs and is deliberately cleared by reset. Extend `SettingsStore` with a small, atomically written app-preferences payload that can load/save `AppLanguage` independently. Missing or invalid language data returns `.simplifiedChinese`.

Expose the preference only through `NotionRepository` methods such as `loadAppLanguage()` and `saveAppLanguage(_:)`. Views and window controllers must not access `SettingsStore` directly.

### Runtime state and rendering

Create a main-actor observable language store owned by `RootViewModel` or its app-level coordinator. The store holds the active `AppLanguage`, provides localized string lookup, and is supplied to all app UI through the existing ownership path / SwiftUI environment.

At bootstrap, load the saved value before presenting the first screen. On selection, update the store first, then ask the repository to persist it. All rendering must read from the store so a selection changes the currently visible UI rather than applying only after navigation or relaunch.

### Translation catalog and error messages

Introduce a typed translation-key catalog shared by the core and app targets. It provides a complete string table for each supported `AppLanguage`, including parameterized messages. Tests must assert that the three language tables have the identical key set.

Replace app-owned literals with keys. For dynamic errors, retain structured error context (for example HTTP status, field type, or server detail) and convert it to a localized message at the display boundary. The raw Notion detail may be appended unchanged when it is useful, but the app-generated explanation must be localized.

Domain-level validation issues and repository/client errors must carry a stable semantic key plus parameters instead of pre-rendered Chinese strings. This prevents a language switch from leaving stale Chinese errors inside an English or French screen.

## Change Surface

Expected production changes:

- `WidgetToDo/WidgetToDo/Core/Models/` — add the language value and any semantic message-key/argument types.
- `WidgetToDo/WidgetToDo/Core/Infrastructure/SettingsStore.swift` — persist an independent app-preferences payload atomically.
- `WidgetToDo/WidgetToDo/Core/Infrastructure/NotionRepository.swift` — expose language load/save without bypassing the repository layer.
- `WidgetToDo/WidgetToDo/Core/Services/` — add the language catalog/localizer and convert validation messages to semantic keys.
- `WidgetToDo/WidgetToDo/ContentView.swift`, view models, views, `StatusBarController.swift`, and `WidgetToDoApp.swift` — consume the active localizer; add the approved top-of-settings language row.
- `WidgetToDo/Tests/NotionFloatCoreTests/` — cover language model, preference persistence, compatibility default, catalog completeness, and localized representative errors.
- `WidgetToDo/Tests/NotionFloatCoreSmokeTests/main.swift` — keep a source-level smoke guard for the visible setting and fixed option labels if that is the repository’s current convention for UI contracts.
- `progress.md` — record implementation status and verification after code changes.

Do not modify `Package.swift`, the Xcode project, entitlements, Keychain behavior, or SQLite cache behavior.

## Testing Strategy

### Test-driven development

Write each new core behavior as a failing test before production code:

1. `AppLanguage` has exactly the three supported choices and defaults to Simplified Chinese.
2. `SettingsStore` reads an absent/legacy preference as Simplified Chinese and round-trips each selected language.
3. Reset of Notion configuration does not delete the separately saved language preference.
4. Every language table has the same keys and produces nonempty values for parameterized messages.
5. Representative validation, repository, and HTTP errors render in Simplified Chinese, English, and French while preserving non-translatable parameters.

Run the focused test after each red/green cycle, then run `swift test`. If the normal sandboxed command remains blocked by the known environment restriction, record that exact blocker and use the repository’s established verified alternative without claiming the normal command passed.

### Manual UI verification

Use Xcode / the real app runtime after automated checks:

1. Open Settings and verify the `Language` row is before `Notion Token`.
2. Verify the title and three option names remain exactly `Language`, `简体中文`, `English`, and `Français` in every active language.
3. Switch among all three choices and verify immediate updates in Settings, the floating widget, a mini capsule, a new/edit task form, journal status, a confirmation dialog, a help sheet, the menu-bar menu, and the app Settings scene.
4. Relaunch and verify the last selection restores before the first user-visible screen.
5. Run `初始化配置`, return to onboarding, then relaunch or configure again and verify the language remains unchanged.
6. Exercise one invalid configuration field and one runtime failure path to verify readable localized feedback.

## Risks and Rollback

- The primary risk is an incomplete catalog that leaves a stale literal in one surface. Catalog-completeness tests plus the manual cross-screen checklist mitigate this.
- Dynamic language changes can accidentally leave stored error strings in the previous language. Semantic keys and parameters must be retained until render time.
- Separate preference persistence must not be coupled to Keychain, `AppSettings`, or SQLite reset behavior.

Rollback is limited to the new language model/catalog/store, preference persistence file, and view substitutions. Removing the independent preference file safely returns the app to its Simplified Chinese default without touching Notion credentials, cached content, or existing `settings.json`.
