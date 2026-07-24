# Onboarding Language Selector Design

## Goal

Expose the existing application language selector during first-run initialization, using the same control, options, runtime-switch behavior, and persistence path as the configured Settings screen.

## Scope

In scope:

- show the existing `languageSection` in `OnboardingView` when `mode == .onboarding`
- wire the onboarding construction site to `RootViewModel.selectLanguage`
- place the language row before the Notion connection hero and inputs
- add a source-level smoke assertion that the onboarding construction site retains the language callback

Out of scope:

- changing the three language choices, labels, localization catalog, preference format, or reset behavior
- changing Notion configuration validation, token handling, repository interfaces, cache behavior, `Package.swift`, Xcode project files, or entitlements

## Existing Context

`OnboardingView` already owns a reusable `languageSection`, and `RootViewModel.selectLanguage(_:)` updates `LanguageStore` immediately before saving the selection through `NotionRepository`. The Settings construction site passes this callback and renders the row. The onboarding construction site omits it, while its layout renders only `onboardingHero`; consequently, the selector is unavailable on a first-run setup screen.

## Design

The onboarding construction site will pass `onLanguageChange: rootViewModel.selectLanguage`, matching the Settings construction site. The onboarding body will render `languageSection` before `onboardingHero`. This reuses the fixed `Language` label, native language names (`简体中文`, `English`, `Français`), disabled-state handling, immediate locale refresh, rollback-on-save-failure behavior, and independent preference persistence already used in Settings.

The settings layout remains unchanged: its intro continues to be followed by the same shared row. No new state, view, repository call, or persistence key is introduced.

## Verification

1. Add a failing smoke assertion that the `.onboarding` call to `OnboardingView` supplies `onLanguageChange: rootViewModel.selectLanguage` and that onboarding renders `languageSection` before its hero.
2. Run the smoke executable to observe the expected failure.
3. Make the minimal `ContentView.swift` change and rerun the smoke executable.
4. Run the complete SwiftPM suite and an Xcode Debug build.
5. In the desktop app, enter first-run setup, switch among all three options, confirm visible copy updates immediately, then relaunch and confirm the selected language restores before the welcome/onboarding screen.

## Risks and Rollback

This is a view wiring and layout-only change. The primary risk is a visual vertical-space regression on the fixed-size onboarding panel; desktop verification will confirm the scrollable layout still exposes all fields. Reverting the two `ContentView.swift` insertions restores the prior behavior without affecting saved language preferences or Notion data.
