# Complete Localization Remediation Design

## Goal

Complete the existing language-setting feature so every app-owned user-facing interface string changes immediately between `简体中文`, `English`, and `Français`.

The existing `Language` row and its three option labels remain fixed exactly as `Language`, `简体中文`, `English`, and `Français`.

## Root Cause

The first implementation added an `AppText` catalog for seven values and partial `.strings` resources. Most views and view models still render hard-coded Chinese strings. SwiftUI can only localize a literal when the active locale contains an exact resource key; missing keys fall back to the source literal. View-model status fields are pre-rendered strings, so they cannot refresh after a language selection.

## Scope

Include all app-owned text shown to a user:

- loading, welcome, onboarding, configured settings, help sheets, reset configuration, menu-bar menu, app Settings scene, and accessibility labels
- todo, journal, mini capsules, task actions, empty states, date/status labels, confirmation dialogs, toast messages, and new/edit task forms
- form validation, connection validation, repository/client errors, and app-generated status messages

Exclude user-owned or remote data:

- Notion property names, task titles, task priorities returned from Notion, journal content, page titles already stored in Notion, and raw server-provided detail strings
- Notion request behavior, Keychain data, SQLite data, package configuration, entitlements, and Xcode project settings

## Design

### Single catalog

Expand `AppText.Key` into the sole catalog of semantic UI message keys. Each of the three `AppLanguage` tables must provide the same nonempty key set. Parameterized keys receive stable named semantics (for example, HTTP status or field name) and resolve with the current language locale.

Static views resolve their text through the environment-owned `LanguageStore`, rather than relying on partially populated bundle resource lookups. This makes every visual state use the same source of truth and retains immediate refresh behavior.

### Deferred dynamic messages

Introduce a small value type representing an app message as a catalog key plus formatting arguments. View models and UI state hold this value instead of a rendered Chinese string. Views convert it to `String` through `LanguageStore` at render time. Existing view-model error/status properties that are currently stored `String?` are migrated where their value is app-owned.

Core validation and repository/client errors carry stable semantic error cases and context. The app/UI layer maps those cases to `AppMessage`. Any useful raw Notion response detail stays unchanged and is inserted only as a parameter; it is not translated or treated as application copy.

### Runtime refresh

`LanguageStore` remains owned by `RootViewModel` and supplied to SwiftUI and `StatusBarController`. Its published language value causes visible views, current dialogs, current form feedback, and the status-bar menu to resolve their current strings again. A language change must never trigger Notion validation, network fetch, token update, or cache mutation.

## Testing

1. Write a failing catalog-completeness test that requires equal key sets and nonempty values in all three languages.
2. Write failing tests for representative deferred messages: a validation failure and a formatted operation failure must render in each language after selecting that language.
3. Extend smoke checks to assert the screenshot surfaces use catalog keys rather than the old hard-coded literals.
4. Run `swift test --disable-sandbox`, the smoke executable, and an Xcode Debug build.
5. In the real app, switch each language and inspect the five supplied surfaces plus welcome, todo, journal, task forms, confirmation dialogs, toast, and menu bar. Relaunch once to verify preference restoration.

## Risks and Rollback

The main risk is missing a literal or preserving a pre-rendered message. The catalog test and source smoke checks reduce this; desktop verification is still required for text wrapping, especially French.

Rollback consists of reverting this remediation commit(s). It touches presentation and semantic error mapping only; it does not delete or transform user/Notion data.
