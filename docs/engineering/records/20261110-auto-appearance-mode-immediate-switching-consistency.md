# 2026-11-10: Auto Appearance Mode Immediate Switching Consistency

## Requirement Source
- `docs/human/requirements/20261110-Bug-Auto Appearance Mode Immediate Switching Consistency.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

## Summary of Changes
1. **Unified App-Wide Appearance Control via `NSApp.appearance` (`ContentView.swift`, `SettingsView.swift`, `AppTypes.swift`)**:
   - Removed the redundant `.preferredColorScheme(settingsStore.appAppearanceMode.colorScheme)` view modifiers on `ContentView` and `SettingsView` as well as the unused `AppAppearanceMode.colorScheme` computed property.
   - `SettingsStore.applyAppAppearanceMode(_:)` continues to set `NSApp?.appearance = mode.nsAppearance` (`.aqua`, `.darkAqua`, or `nil` for `.auto`), allowing `NSWindow`, `CueSeekerHostingView` (`NSHostingView`), AppKit subviews (`TitlebarBackgroundView`), and SwiftUI `@Environment(\.colorScheme)` to inherit the effective appearance from `NSApp` in lockstep without `NSHostingView` retaining a stale `.dark` / `.light` override when switching back to `Auto` (`nil`).
2. **Unit Tests (`AppLocalizationTests.swift`)**:
   - Added `switchingAppAppearanceModeToAutoImmediatelySynchronizesWindowAndHostedViewsWithSystemAppearance` verifying that cycling `appAppearanceMode` through `.light -> .dark -> .auto` and `.dark -> .light -> .auto` immediately updates `NSWindow.effectiveAppearance`, `CueSeekerHostingView.effectiveAppearance`, `DraggableNSView.effectiveAppearance`, and SwiftUI `@Environment(\.colorScheme)` to match the target mode and system appearance.

## Verification
- Ran `swift test --package-path apps/macos-native --filter switchingAppAppearanceModeToAutoImmediatelySynchronizesWindowAndHostedViewsWithSystemAppearance` (passed).
