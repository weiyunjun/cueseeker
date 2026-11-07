# Settings Topbar Navigation, Sidebar Dead Zone, And Description Removal

## Summary

- Requirement: `docs/human/requirements/20261107-UI-Settings Topbar Navigation Sidebar Dead Zone And Description Removal.md`
- Added App-session Back / Forward category navigation and a right fixed topbar (`48px`, `--height-settings-titlebar`) to the Settings window (`WorkbenchControlMetrics.swift`, `SettingsView.swift`, `SettingsLayout.swift`, `WorkbenchAccessibility.swift`, `AppCoordinator+WorkbenchAccessibility.swift`):
  - Maintained `settingsCategoryHistory` and `settingsCategoryHistoryIndex` on `WorkbenchAccessibilityCoordinator` (defaulting to `[.general]` at index `0`), preserving history across Settings window close/reopen during the App's runtime session, truncating forward entries when navigating to a new category, and ignoring duplicate clicks on the currently selected category.
  - Updated `WorkbenchControlMetrics.redesignSettingsTitlebarHeight` (`--height-settings-titlebar`) from `36px` to `48px` and added the `48px` right fixed topbar (`--color-bg-surface`, leading padding `24px`, trailing padding `40px`) containing compact `24×24px` (`16px` icon) `Back` and `Forward` buttons (`4px` gap) and the `18px` Semibold (`C-08.7 Section Title`) category title (`8px` gap from `Forward`), while removing the duplicated `Page Title` inside the scrollable `SettingsPage` and setting `SettingsPage` top padding to `4px` (`--spacing-1`).
  - Added `.topbarBackButton` and `.topbarForwardButton` to `SettingsAccessibilityTarget` at the start of the Settings window focus cycle (`Topbar → Left Sidebar → Right Category Content`), keeping the accessibility focus ring on `Back` / `Forward` even when an activation reaches the start/end of history and transitions the button to `Disabled`.
- Eliminated the `4px` vertical dead zone between sidebar items in both the Workbench left sidebar (`ContentView.swift`) and the Settings left sidebar (`SettingsView.swift`) by setting the sidebar item `VStack` spacing to `0`.
- Removed static group descriptions (`SettingsGroup.description`) and row notes (`SettingsRow.note` / `SettingsRowLabel.note`) across `SettingsLayout.swift`, `SettingsAppearanceCategory.swift`, `SettingsSearchCategory.swift`, `SettingsLanguageCategory.swift`, `SettingsURLSchemeCategory.swift`, `SettingsDecodeCategory.swift`, `SettingsMaintenanceCategory.swift`, and `SettingsDeveloperCategory.swift`.

## Verification

- `swift test --package-path apps/macos-native --filter WorkbenchAccessibilityStep3Tests`
