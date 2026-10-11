# Relax Playback Keyboard Shortcuts

Human-owned documents:

- `docs/human/requirements/20261011-Feature-Relax Playback Keyboard Shortcuts.md`
- `docs/human/requirements/20260912-Feature-Playback Keyboard Shortcut Rebinding.md`
- `docs/human/design/UI Design System.md`

## Why

1. **Overly Restrictive Shortcut Rebinding Rules**:
   - Previous shortcut rules strictly prohibited modifiers (`⌘`, `⌥`, `⌃`), only allowing single keys or `⇧` + single key.
   - Because CueSeeker shortcuts are in-app shortcuts rather than global system daemons, restricting modifier keys heavily constrained practical user customization.
2. **Elimination of Intermediate Error Messages (Occam's Razor)**:
   - Intermediate rejection messages ("Can't include ⌘, ⌃ or ⌥", "Reserved key", "Not supported") created unnecessary cognitive burden during key recording.
   - Excluded/reserved keys should be silently ignored (not displayed, not written, and no red warning), while red warnings are reserved solely for intra-domain action conflicts.
3. **Function & Navigation Keys Support**:
   - F1–F12, Home, End, Page Up, and Page Down are standard playback shortcuts in media players and are now explicitly supported with dedicated keycap labels.

## What changed

1. **Playback Shortcut Key Model (`PlaybackShortcuts.swift`)**:
   - Extended `PlaybackShortcutKey` to store `command`, `option`, `control`, and `shift` flags while preserving custom JSON backward-compatibility for previously saved settings in `UserDefaults`.
   - Added keycap rendering for modifiers in standard Apple order (`⌃ ⌥ ⇧ ⌘`) and added labels for `F1`–`F12`, `Home`, `End`, `Page Up`, and `Page Down`.
   - Added identification of pure modifier keys (`isModifierKey`) and protected system/window keys (`⌘Q`, `⌘,`, `⌘W`, `⌘M`, `⌘H`).
   - Simplified `PlaybackShortcutAction.recordedKey` to return an optional `PlaybackShortcutKey?`, returning `nil` for excluded keys without raising intermediate errors.
   - Removed `PlaybackShortcutRejection` enum and unused rejection localization strings across English, Simplified Chinese, and Traditional Chinese.
2. **Settings Shortcut Recorder & View (`SettingsShortcutsCategory.swift`)**:
   - Removed `rejection` state from `PlaybackShortcutRecorder`. Excluded keys are silently ignored and consumed during recording.
   - Restricted error state and validation message display strictly to actual conflicting shortcuts.
3. **Playback Event Routing (`AppCoordinator+Playback.swift`)**:
   - Constructed `PlaybackShortcutKey` with all modifier flags.
   - Allowed shortcut actions with modifiers to execute while maintaining menu barrier rules for open menus.
   - Prioritized cue shortcuts over navigation modifier barriers in overlay and command panel.
4. **Unit Test Coverage (`PlaybackShortcutKeymapTests.swift`, `PlaybackNormalShortcutTests.swift`)**:
   - Verified recording of modifiers (`⌘C`, `⌥→`, `⌘⇧P`, `⌃K`) and function/navigation keys (`F5`, `Home`, `PageUp`).
   - Verified silent rejection of pure modifiers, protected system keys, `Tab`, and overlay navigation keys.
   - Verified keycap rendering and settings persistence across relaunch.

## Verification

- `swift test --package-path apps/macos-native --filter PlaybackShortcutKeymapTests`: passed (10/10 tests passed).
- `swift test --package-path apps/macos-native --filter PlaybackNormalShortcutTests`: passed (16/16 tests passed).
