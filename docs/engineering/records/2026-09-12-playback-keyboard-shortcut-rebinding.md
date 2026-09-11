# Playback keyboard shortcut rebinding

Human-owned documents:

- `docs/human/requirements/20260912-Feature-Playback Keyboard Shortcut Rebinding.md`
- `docs/human/design/UI Design System.md`, `docs/human/design/UI Application Rules.md` and `docs/human/design/Icon Registry.md` (to be updated by the owner after acceptance)

## Why

Every playback key was written into the key handling as a fixed key code. The owner wants the video page's, the Playback Overlay's and the Command Panel's shortcuts rebindable from Settings, in place on the page, with rules for keys that cannot be used and for two shortcuts that share a key.

Classified as platform UI and UX with local configuration: key codes, key recording and the keycaps are macOS input and presentation, and the bindings are stored with the other settings. Nothing in the database, Search, Library, Shiori or playback intent changes, so nothing moves into `CueSeekerCore`.

## What changed

- One keymap holds the 19 shortcuts of the requirement, each with its default key and its group: Open Command Panel on its own, the Playback group, and the Playback Overlay & Command Panel group. A key is one key code plus whether ⇧ is held; Return and the keypad's Enter are one key. The user's changes — a new key, or a cleared shortcut — are kept as overrides in the shared preferences under `playbackShortcutOverrides`; setting a shortcut back to its default removes its override, and removing the last one removes the key.
- Two shortcuts conflict when they have the same key and can answer in the same place: the same group, or either of them Open Command Panel. A key in conflict runs neither side. Restoring a default goes through the same rule.
- The key handling of the video page, the Playback Overlay, Editing Collage and the Command Panel reads the rebindable keys from the keymap and keeps its fixed keys — Esc, Tab, and Return and the arrows where they confirm and move — as they were. A shortcut is matched with its ⇧ exactly and never when ⌘, ⌃ or ⌥ is held. The open Save to Shiori menu closes on the Save to Shiori key. A game controller still presses the default keys: it passes the default keymap, whatever the keyboard has been rebound to.
- Settings gains Shortcuts below Play, with a new `keyboard` icon. The page lists Open Command Panel, then the two groups under Section Titles, in one grid whose name column is as wide as the longest name, with the key field `--spacing-6` from it and the Restore Default button (Icon Button, new `arrow-counter-clockwise` icon) beside the field; it is unavailable while the shortcut has its default key. Names keep the other settings pages' name style. Below each field is Text Field's Validation Message line, kept even when empty; it doubles as the row spacing.
- The key field wears Text Field's container: recording is its Focused state, a conflict or refused key its Error state. It draws ⇧ and the key on separate Keycaps with the Popover Surface keycap colour, Return as the footer's Return icon. While recording it shows `Press a key` and an Inline Clear laid over its right end, so a press on the clear button clears rather than restarting the recording.
- While a shortcut records, every key pressed in the Settings window is its own, the App menu's shortcuts included: key equivalents are taken from the window before the menu sees them, and the other keys come through the existing window key-down monitor. Esc and a press anywhere but the field end the recording without a change, as does the Settings window losing key status. An allowed key is written; a key with ⌘, ⌃ or ⌥, Tab, a key that types nothing (function keys, Home, End, Page Up, Page Down), or Return and the arrows for the Overlay group or Open Command Panel is refused with the requirement's message, and the recording goes on.
- The Playback Overlay and Command Panel footers draw Save to Shiori, Copy Cue Text and Copy Deep Link with the current key; a cleared or conflicting shortcut shows its title only and still runs on click. Each footer button observes the keymap, so a change in Settings shows at once.
- Text Field's Validation Message and container border are shared from the form controls instead of being private to them; the form fields look the same.
- Copy for the page, the 19 names, the placeholder and the four messages in English, Simplified and Traditional Chinese. Names reuse the App's existing translations where one exists: Save to Shiori, Copy Cue Text, Copy Deep Link, Repeat, Copy Screenshot, Playback Overlay, Command Panel, Collage.

New and provisional until the design document takes them: `--width-shortcut-field` 144. The two new icons follow the Icon Registry's drawing rules; `arrow-counter-clockwise` is the mirror of `arrow-clockwise`, `keyboard` is drawn for this page.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Settings/PlaybackShortcuts.swift` (new)
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsShortcutsCategory.swift` (new)
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsView.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Playback.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+ControllerInput.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppDelegate.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCueFooter.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchFormControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/AppIcon.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/Icons/keyboard.svg` (new)
- `apps/macos-native/Sources/CueSeekerApp/Resources/Icons/arrow-counter-clockwise.svg` (new)
- `apps/macos-native/Sources/CueSeekerApp/Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackShortcutKeymapTests.swift` (new)
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackNormalShortcutTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackSubtitleFocusKeyboardActionTests.swift`
- `docs/changelog.md`

## Verification

Unit tests, new in `PlaybackShortcutKeymapTests`: the defaults have no conflict although Copy Screenshot and Edit Collage share P; a key shared in one group disables every side and a reset brings it back; groups may share a key but Open Command Panel shares with none; setting the default key is the same as restoring it, and a cleared shortcut has no key and no conflict; recording accepts Backspace, Delete and ⇧ with a key and refuses ⌘, ⌃, ⌥, Tab, F5, Home, End, Page Up and Page Down with the right reason; Return, the keypad's Enter and the arrows are reserved for the Overlay group and Open Command Panel only; the keycaps draw ⇧, Space, the arrows, ⌫ and the Return icon; every name has copy; changes and clears survive a new store on the same defaults, and restoring the last one removes the key. In the playback suites: a rebound ⇧V toggles subtitles while Q and plain V do not and the controller's thumbstick still presses Q; a key in conflict runs neither shortcut; in the Overlay a rebound Edit Collage and Open Command Panel follow their new keys, and Edit Collage and Save to Shiori on one key run neither. The existing playback, controller, icon, localization and settings suites pass with them, 93 tests.

`swift test`: 1197 tests, compared against a pristine `9d201b0a` copy expanded with `git archive` into a scratch directory with `CUESEEKER_MEDIA_RUNTIME_ROOT` pointed at the repository's runtime, which runs 1185. Both fail 14, 13 of them shared: native playback timeline, audio and presentation, the auto-pause boundary, the refresh-scope counts, the Shiori table's scroll and anchor waits, and the two Debug E2E scene-geometry cases. Only this tree fails `failedLibraryFolderRemovalPreservesFolderAndPresentationState`, which passes 3 of 3 alone; only the baseline fails `libraryFolderRemovalAndIndexingRejectEachOther`. None of them reads a shortcut. An earlier run crashed the test process: a new test's expectation failed and Swift Testing crashed while describing the App it had failed on; the test lacked the expanded playback surface the controller requires and now sets it.

In the App: Debug E2E controller, main window 1445×821 at 2×, Settings window 760×520 at (342, 76), with the existing `click`, `scroll`, `keyPress`, `inspect` and `capture` commands; no E2E facility was added. Coordinates were read off this session's captures and are not documented procedure coordinates.

- Shortcuts sits below Play with the keyboard icon. Open Command Panel is first, then Playback and Playback Overlay & Command Panel; every field shows its default key, the Speed rows ⇧ and the key on two keycaps, Open Playback Overlay the Return icon, and every Restore Default button is unavailable. The name column is as wide as Open Playback Overlay and every field starts one `--spacing-6` after it; rows are 59 apart: the 40 field, the 4 gap and the message line.
- Recording Play / Pause: the field takes the accent border, `Press a key` and the clear button. ⌘Q and ⌘M were refused with `Can’t include ⌘, ⌃ or ⌥` under a red field; the App did not quit and the window did not minimise. Tab showed `Reserved key`. Esc put Space back. On the build before key equivalents were taken from the window, ⌃Q and ⌘J were refused the same way but ⌘Q quit the App: a menu shortcut reaches the menu before any key-down monitor sees it.
- Repeat set to F: Repeat and Toggle Fullscreen both turned red with `Conflicts with “Toggle Fullscreen”` and `Conflicts with “Repeat”`, Repeat's Restore Default available. Save to Shiori refused Return and ↑ as `Reserved key`; its clear button left an empty field of full size with Restore Default available. Copy Screenshot and Edit Collage both on P show no conflict.
- After quitting and relaunching, the conflict and the cleared Save to Shiori were still there. On the video page F did nothing and the window stayed the same size; Return opened the Playback Overlay, whose footer read Save to Shiori without a keycap beside C, X and Return, and S opened no menu. Restoring both defaults in Settings brought S back to the footer and left no `playbackShortcutOverrides` in the preferences.
- Dark and Simplified Chinese through the `-appAppearanceMode` and `-appLanguage` launch arguments, so the owner's preferences were not written: the page, the keycaps, the red border and message read in both; `保留按键` for Tab, `与“开关全屏”冲突` and `与“开关字幕”冲突` for a shared F, restored afterwards. Cmd+Q without a recording quit the App as usual.

## Known limits

- A shortcut is matched with its ⇧ exactly. Keys the video page and the Overlay used to take with or without ⇧ — Space, the arrows, A, D, Q, F, Return, S, C, X — now do nothing with ⇧ unless a shortcut is set to that combination.
- The open Save to Shiori menu closes on the Save to Shiori key's key code whether or not ⇧ is held: the menu is handed key codes only.
- The Debug E2E controller cannot press `,`, `.`, Backspace, Delete or function keys, so recording those, the Speed shortcuts' effect, and the refusal of function keys and Home, End, Page Up and Page Down were covered by unit tests only. System-intercepted keys (⌘Tab, ⌘Space and the like), and another App or window taking focus in the middle of a recording, stay manual acceptance steps.
- The design documents do not yet describe the Shortcuts page, the key field, the settings page's name and title styles, which keycap colour the Settings page uses, the recording's hold on the App menu's shortcuts, or the two icons.
