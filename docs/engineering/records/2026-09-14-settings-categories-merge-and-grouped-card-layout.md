# Settings categories merge and grouped card layout

Human-owned documents:

- `docs/human/requirements/20260914-UI-Settings Categories Merge And Grouped Card Layout.md`
- `docs/human/design/UI Design System.md` (Settings Window Layout, Settings Sidebar Layout, Settings Category Layout, Settings Shortcuts Layout, Settings Subtitle Layout, Shortcut Field) and `docs/human/design/Icon Registry.md`, to be updated by the owner after acceptance

## Why

Settings had ten categories whose pages each laid themselves out: most put the name on the left and pushed the control to the far edge with system text styles and literal spacings, while Shortcuts and Subtitle used a name column with the controls beside it. The requirement merges the categories into six and gives every page one structure — page title, titled groups, rows on cards with the name leading and the control trailing — with every size and color a token, and makes the window's default width its minimum.

Classified as platform UI and UX only; no settings value, storage or behavior changes.

## What changed

- `SettingsLayout.swift` (new) holds the four pieces every page uses: `SettingsPage` (title, groups `--spacing-6` apart, vertical scrolling, `--spacing-6` leading, bottom and trailing padding plus the always-kept Scrollbar channel), `SettingsGroup` (title, optional description, card with `--color-settings-group-bg`, `--color-border-divider` border and `--radius-settings-group`), `SettingsRow` (name side leading, control trailing, `--spacing-4` inline and `--padding-settings-row-y` block padding, `--min-height-settings-row`) with its usual name-and-note label, and `SettingsRowDivider`.
- `SettingsView` lists General, Play, Shortcuts, Subtitle, Maintenance and Developer, opens on General, and wraps the selected category's groups in one `SettingsPage` keyed by the category, so each opens scrolled to its top. The sidebar and the page both start `--height-settings-titlebar` below the window top.
- The former category views keep their files and names and now draw their own group: Appearance, Search, Language (popup `--width-settings-popup`) and Deep Link on General; Play (field `--width-settings-number-field`) and Decode on Play. Each former page description is its group's description.
- Shortcuts draws three groups — Shortcuts (Open Command Panel), Playback, Playback Overlay & Command Panel. The validation message is only laid out while there is one, so a row grows for it; it starts under the field and, when longer than the field and its button, extends back toward the name. The row stays centered on the field.
- Subtitle draws Text, Border, Shadow and Position as groups; Restore Defaults sits right-aligned below the last card.
- Maintenance draws one group: the five storage rows with their values in `--color-text-secondary` monospaced digits, one row with the maintenance status above the storage state and the Refresh and Compact Database buttons, and the database path in caption muted text truncated in the middle. Compaction recommended uses the new `--color-warning-text`; completed and failed use the success and danger text colors. The two buttons are now Button / Neutral, as the requirement's reference mockup shows, instead of system buttons.
- Developer draws its two switches as one group and FTS Vocabulary Data as a second: the status on the leading side, Refresh (Button / Neutral) trailing, and while loaded the vocabulary data below a divider on the same card, its inner layout unchanged and its own background removed.
- Tokens: `WorkbenchControlMetrics` replaces the provisional default and minimum window sizes with `--width-settings-window` 880 (default and minimum width), `--height-settings-window` 640 and `--min-height-settings-window` 420, and adds `--height-settings-titlebar` 36, `--width-settings-popup` 180, `--radius-settings-group` 10, `--min-height-settings-row` 52 and `--padding-settings-row-y` 6. `WorkbenchRedesignColors` adds `--color-settings-group-bg` (Light `#F6F7F9`, Dark `#202024`) and `--color-warning-text` (Light `#B45309`, Dark `#FCD34D`). `AppDelegate` opens the window at the default size with that width as its minimum.
- Icons: `gear-fine` (Phosphor, Regular) added for General. `circle-half` lost its only use with the Appearance category, so its `AppIcon` case is removed; the owner then deleted the `circle-half.svg` asset.
- Copy: `settings.category.general` added as General, 通用 and 一般.
- `docs/changelog.md` records the change.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsLayout.swift` (new)
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsAppearanceCategory.swift`, `SettingsSearchCategory.swift`, `SettingsLanguageCategory.swift`, `SettingsURLSchemeCategory.swift`, `SettingsPlayCategory.swift`, `SettingsDecodeCategory.swift`, `SettingsShortcutsCategory.swift`, `SettingsSubtitleCategory.swift`, `SettingsMaintenanceCategory.swift`, `SettingsDeveloperCategory.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/AppIcon.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/Icons/gear-fine.svg` (new)
- `apps/macos-native/Sources/CueSeekerApp/App/AppDelegate.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`
- `docs/changelog.md`

## Verification

`swift build` succeeds. `swift test`: 1223 tests, 15 failing. Fourteen are the set earlier records list as failing on the baseline or under the full suite's load: the seven native playback timeline, audio, presentation and auto-pause cases, the two Debug E2E scene and window-width cases (the E2E App was open during the run), the four refresh-scope integration cases, and `libraryFolderRemovalAndIndexingRejectEachOther`. The fifteenth, `libraryFolderRemovalPublishesProgressWithoutBlockingMainActor`, failed under the full run and passed when run alone. The icon asset suite covers `gear-fine` at every documented size and its single master line width; the localization key parity test covers the new key.

In the App: Debug E2E controller, `.build/debug/CueSeeker --cueseeker-debug-e2e` under a PTY, the owner's real library, English, Light, 2×, with the existing `click`, `scroll`, `keyPress` and `capture` commands; no E2E facility was added. Coordinates were read off this session's captures.

1. The Settings entry opened the Settings window at 880 × 640 on General. The sidebar lists the six categories in order with `gear-fine` for General; the first item and the page title start just below the window controls.
2. General shows Appearance, Search, Language and Deep Link as titled groups with their descriptions and cards; names are regular weight on the left, notes muted below them, controls on the right. Play shows Play and Decode.
3. Shortcuts shows its three groups; scrolled to the end, the Playback Overlay & Command Panel card ends above the bottom padding and the Scrollbar sits in its channel beside the cards.
4. Recording D on Previous turned its field red and showed Conflicts with "Next" under the field, the row taller; Restore Default put A back and the row returned to its height.
5. Subtitle shows Text, Border, Shadow and Position; with Type at Outline, Background Color's well is dimmed; Restore Defaults, disabled, sits right-aligned under the last card.
6. Maintenance shows the five storage rows, the within-threshold state with Refresh and Compact Database, and the database path. Developer shows its switches and, with diagnostics on, the vocabulary data on the FTS Vocabulary Data card.
7. Appearance set to Dark: General, Subtitle and Maintenance draw their cards, dividers and text in the dark tokens. Appearance was set back to Light.

The settings were left as they were found: Light, every shortcut at its default.

Not verified in the App and left to the owner's acceptance: that the window cannot be made narrower than 880 and that a shorter window scrolls (the controller resizes only the main window); the Chinese and Traditional Chinese copy; Maintenance's loading, compacting, completed, failed and compaction-recommended states; Developer with diagnostics off; the Language menu itself.

## Outcome

Matched expectations for what could be checked. Beyond the requirement's wording: Maintenance's and Developer's buttons became Button / Neutral to match the mockup, and a long maintenance state wraps to two lines beside the buttons at the default width.
