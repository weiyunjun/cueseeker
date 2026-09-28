# Toast and Feedback Expansion and Unification

Human-owned documents:

- `docs/human/requirements/20260928-UI-Toast And Feedback Expansion And Unification.md`
- `docs/human/design/Toast Usage Registry.md`

## Why

1. Workbench table rows and selection action bar had missing copy feedback toasts: users copying cue text, deep links, cue group text, time ranges, multi-row deep links, or table TSV received no visual confirmation.
2. Toast and Playback Feedback durations were unparameterized and inconsistent, ranging arbitrarily from 800ms to 2000ms.
3. Multiple toast and feedback strings contained trailing periods (e.g. `toast.excerpt.move_failed`, `playback.hud.no_subtitle.details`, `playback.hud.copy_failed.details`).
4. Warning and error feedback used inconsistent icons (`.info` vs `.warning`), leading to visual inconsistency across Workbench and Playback.
5. In Playback navigation, empty playlist state used `No Available Excerpts` when entering from Excerpts, whereas Search and other routes used `No Available Results`. Since both become an in-playback playlist, the feedback wording should be unified to `No Available Results`.
6. When a video/folder was removed from the library, clicking "Copy Deep Link" or "Save to Excerpt List" in the Workbench table or Playback did not consistently intercept or inform the user that the cue is no longer in the library.

## What changed

- **Duration Parameterization (`Toast.swift` & `PlaybackViewModel.swift`)**:
  - Defined explicit standard durations via `ToastDuration`:
    - `light` (`1.5s` / `1500ms`): Transient success feedback (table row copies, selection action bar copies, excerpt save/move/duplicate success, playback overlay copy/screenshot).
    - `alert` (`3.0s` / `3000ms`): Errors, failures, resource unavailability, and boundary alerts (`Cue Not in Library`, `No Subtitle`, `Copy Failed`, `Collage Not Ready`, transfer failures, destination unavailable, already exists).
    - `playerHud` (`1.0s` / `1000ms`): High-frequency playback controls (Play/Pause, seek after release, volume, speed, subtitles on/off, fullscreen, empty playlist navigation, `No Available Videos`).
- **Workbench Table Toasts (`SubtitleTableView.swift`, `WorkbenchTestSearchView.swift`, `WorkbenchExcerptTableView.swift`)**:
  - Bound `isCueInLibrary` and `onToast` closures to `SubtitleTableView`.
  - Added copy feedback to row action menu:
    - `Copy Cue Text` -> `TableToastRequest.copyCueText` (1.5s, `.copy`)
    - `Copy Deep Link` -> `TableToastRequest.copyDeepLink` (1.5s, `.copy`), intercepted by `TableToastRequest.cueNotInLibrary` (3.0s, `.warning`) if cue is not in library
    - `Copy Cue Group Text` -> `TableToastRequest.copyCueGroupText` (1.5s, `.copy`)
    - `Copy Time Range` -> `TableToastRequest.copyTimeRange` (1.5s, `.copy`)
  - Added copy feedback to selection action bar:
    - `Copy Deep Links` -> `TableToastRequest.copyDeepLinks` (1.5s, `.copy`)
    - `Copy Table` -> `TableToastRequest.copyTable` (1.5s, `.copy`)
- **Library Removal Interception**:
  - In `AppCoordinator+Excerpt.swift`, gated `saveExcerpt` with `isCueInLibrary(cueID)`. If false, emits `TableToastRequest.cueNotInLibrary` (3.0s, `.warning`) or `showNotInLibraryFeedback()` depending on whether playback is active.
- **Copy & HUD Feedback Consistency (`PlaybackViewModel.swift`)**:
  - Updated `showSubtitleCopyFeedback`, `showSubtitleMarkdownLinkCopyFeedback`, and `showSelectedTextCopyFeedback` to display for 1.5s on success and 3.0s on failure.
  - Updated `showCollageNotReadyFeedback` to 3.0s with `.warning` icon.
  - Updated `showScreenshotCopiedFeedback` to 1.5s.
  - Updated `showExcerptSaveFeedback` to default to 1.5s and `.bookmarkSimple` (fill) on success, or 3.0s and `.warning` on failure.
  - Updated `showExcerptFeedback`: `.removed` = 1.5s; `.unavailable` = 3.0s.
  - Updated `showNotInLibraryFeedback`: 3.0s.
  - Updated seek delta feedback (`+Ns` / `-Ns`) to 1.0s.
- **Wording & Punctuation Cleanup (`Localizable.strings`)**:
  - Removed all trailing periods from toast and feedback strings in `en.lproj`, `zh-Hans.lproj`, and `zh-Hant.lproj`.
  - Unified `playback.hud.not_in_library` and `toast.cue_not_in_library` to `"Cue Not in Library"` / `"台词不在媒体库中"` / `"台詞不在資料庫中"`.
  - Unified empty playlist navigation feedback across search and excerpts to `L("playback.hud.no_available_results")`.
- **Tests**:
  - Updated `ToastTests.swift`: verified 1.5s wall-clock duration, verified all `ExcerptToastRequest` and `TableToastRequest` specs against the registry.
  - Updated `SubtitleTableRowActionMenuTests.swift`: added `subtitleTableRowActionCopyTriggersExpectedToasts` testing that row action copies emit expected toast requests and respect the `isCueInLibrary` gate.

Files:

- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Excerpt.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackCommandPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackLibraryChange.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackViewModel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/en.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hans.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hant.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Shared/Toast.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchExcerptTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestSearchView.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/SubtitleTableRowActionMenuTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/ToastTests.swift`

## Verification

- `swift build --package-path apps/macos-native`: Succeeded with 0 warnings, 0 errors.
- `ToastTests`: All 6 tests passed.
- `SubtitleTableRowActionMenuTests`: All 20 tests passed.
- `ExcerptPresentationTests`: All 4 tests passed.
