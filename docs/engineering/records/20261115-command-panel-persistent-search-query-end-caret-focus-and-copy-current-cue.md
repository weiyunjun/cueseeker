# 2026-11-15 Command Panel Persistent Search Query, End-Caret Search Focus, and Copy Current Cue

- **Covering Requirement**: `docs/human/requirements/20261115-Feature-Command Panel Persistent Search Query End Caret Focus And Copy Current Cue.md`
- **Branch / Baseline**: `main` (before change: `1960400`, requirement commit: `32e9615`)

## Summary of Changes

1. **Cross-surface shared search query persistence and snapshot reuse**
   - `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackCommandPanel.swift`:
     - Updated `presentPlaybackCommandPanel()` and `preparePlaybackCommandPanelPresentation()` to initialize the Command Panel root query directly from `SearchInputNormalizer.singleLine(search.searchQuery)` instead of resetting to `""` or reading a removed cue-prefill setting.
     - Updated `updatePlaybackCommandPanelLiveSearchIfNeeded(_:)` so when a non-empty query matches the current `search.searchQuery`, `search.searchFacetFilter`, and database state without mutation and an active `.searching` or `.completed` snapshot already exists (whether full Workbench search results or root count-only counts), the existing snapshot is reused in place without restarting count queries or clearing loaded Workbench results.

2. **End-caret autofocus for Search Fields (preserving Rename select-all)**
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchNativeTextFields.swift`
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchFormControls.swift`
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`:
     - Added `selectsAllOnAutofocus: Bool = true` across `WorkbenchSingleLineTextInput` and `WorkbenchNativeSingleLineTextField`.
     - Configured `WorkbenchSearchField` with `selectsAllOnAutofocus: false` so Workbench `Search` and Command Panel root (including returning from secondary pages and accessibility focus onto Search Fields) place the caret at the end of text (`NSRange(location: stringValue.utf16.count, length: 0)`) and scroll to the end when overflowing, while normal text inputs such as `LibraryRenameDialog` keep `selectsAllOnAutofocus: true` and preserve full selection on open.

3. **`Copy Current Cue` root option, cue snapshotting, footer action copy, and clipboard execution**
   - `apps/macos-native/Sources/CueSeekerCore/PlaybackSubtitleDatabase.swift`:
     - Added `subtitleFocusDefaultCueText(forSubtitleFileID:atMilliseconds:)` reusing the existing `resolveSubtitleFocusCueLine` helper across active, nearest-previous, and first-cue fallback queries.
   - `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusSessionStore.swift`:
     - Updated `focusedCueTextForCommandPanel` to return `collageSnapshot?.selectedCue?.text` when `.collage` is selected alongside existing `.current` and cue `.playlist` focus resolution.
   - `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackStore.swift`:
     - Added `PlaybackCommandPanelRootOption` (`.search`, `.copyCurrentCue`, `.recentVideos`, `.recentExcerpts`) and `currentCueText`, `hasSearchQuery`, `hasCurrentCue`, `rootOptions`, and `selectedRootOption` computed helpers on `PlaybackCommandPanelPresentation`.
   - `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackCommandPanel.swift`:
     - Snapshots `currentCueText` on Command Panel open via `resolveCurrentCueTextForCommandPanel()` and `resolveDefaultPlaybackCueTextForCommandPanel(source:timestampMilliseconds:)` (reading focused cue for `Current`, cue `Playlist`, and `Collage`, default cue for `Video Playlist`, and normal-playback default cue even when on-screen subtitles are hidden, while omitting the option when unavailable or removed from the database).
     - Added `copyPlaybackCommandPanelCurrentCue()`, which writes raw cue text to `NSPasteboard.general`, triggers `PlaybackToastRequest.cueTextCopied`, clears non-search accessibility focus, and keeps Command Panel open at `.root`.
     - Unified root selection activation (`openSelectedPlaybackCommandPanelItem()`) and item counting (`playbackCommandPanelItemCount(for:)`) via `presentation.rootOptions`.
   - `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCommandPanel.swift`:
     - Rendered root rows from `presentation.rootOptions` using `PlaybackCommandPanelRootRow` (`AppIcon.copy`, localized `playback.command_panel.copy_current_cue` title, and single-line cue preview via `SearchInputNormalizer.singleLine`).
     - Wired footer primary action button text dynamically to `playback.copy` when `.copyCurrentCue` is selected and `playback.open` otherwise (preserving `.commandPanelFooterAction("open")`), and connected `WorkbenchSearchField` `onSubmit` directly to `onOpenSelectedItem`.

4. **Trilingual localization and obsolete Settings cleanup**
   - `apps/macos-native/Sources/CueSeekerApp/Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`:
     - Added `"playback.command_panel.copy_current_cue"` (`Copy Current Cue` / `复制当前台词` / `拷貝目前台詞`) and `"playback.copy"` (`Copy` / `复制` / `拷貝`); removed obsolete `"settings.search.prefill"` and `"settings.search.prefill_note"`.
   - `apps/macos-native/Sources/CueSeekerApp/Settings/{SettingsStore.swift,SettingsSearchCategory.swift}`, `WorkbenchAccessibility.swift`, `AppCoordinator+WorkbenchAccessibility.swift`:
     - Removed `prefillCommandPanelWithFocusedCue`, the `Settings -> General -> Search` toggle row, and `.searchPrefillCommandPanel`.

5. **Unit test updates and additions**
   - `apps/macos-native/Tests/CueSeekerAppTests/{SettingsStoreSearchTests.swift,WorkbenchAccessibilityStep3Tests.swift,WorkbenchInputControlsTests.swift,PlaybackSubtitleFocusKeyboardActionTests.swift}`:
     - Removed obsolete `prefillCommandPanelWithFocusedCue` / `.searchPrefillCommandPanel` references and updated Search field autofocus expectations to end-caret placement while preserving Rename dialog select-all coverage.
     - Added pure-logic tests `playbackCommandPanelPersistsSearchQueryAndReusesValidSearchSnapshot`, `playbackCommandPanelResolvesCopyCurrentCueAcrossPlaybackAndOverlayStates`, and `playbackCommandPanelCopyCurrentCueFooterAndExecutionPreservePanelAndSearchFocus`.

## Compilation & Unit Test Verification

Executed after the final code and test edits:

1. **Build verification**:
   - `swift build --package-path apps/macos-native`: `Build complete! (0.37s)`, `0` errors.
   - `swift build --package-path apps/macos-native --build-tests`: `Build complete! (20.88s)` after final test edits (`0.33s`–`10.54s` incremental test builds).
2. **Targeted headless pure-logic tests (filtered, zero window popups)**:
   - `swift test --package-path apps/macos-native --filter "SettingsStoreSearchTests|WorkbenchAccessibilityStep3Tests|commandPanelAccessibilityCoordinatesRootRecentGridsAndSearchResults|PlaybackSubtitleFocusKeyboardActionTests|PlaybackSearchOverlayTests|everyBundledLanguageDefinesTheSameKeys|singularCountKeysDoNotContainUnresolvedFormatPlaceholders|eachLanguageResolvesItsOwnLocalizationBundle"`: `73` Swift Testing cases passed (`0` failed).
   - `swift test --package-path apps/macos-native --filter "CueSeekerCoreTests.*subtitleFocus|CueSeekerCoreTests.*PlaybackSubtitle"`: `18` Swift Testing cases passed (`0` failed).
3. **End-to-end acceptance**:
   - Live end-caret horizontal scrolling in overflowing Search Fields, `Command Panel` visual layout, `Rename` dialog selection behavior, clipboard/toast feedback, and `Settings -> General -> Search` visual cleanup remain with the user for interactive acceptance.
