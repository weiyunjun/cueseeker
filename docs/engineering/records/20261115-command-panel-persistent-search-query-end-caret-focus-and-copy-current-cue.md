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

5. **Main window layer-coverage gate fix for `.commandPanel` text input**
   - `apps/macos-native/Sources/CueSeekerApp/Shared/CueSeekerMainWindow.swift` & `apps/macos-native/Sources/CueSeekerApp/App/AppDelegate.swift`:
     - Added `isLayerCovered: (InterfaceLayer) -> Bool = { _ in false }` on `CueSeekerMainWindow`, wired in `AppDelegate` to `appState.interfaceLayers.isCovered(layer)` alongside `isWorkbenchCovered`.
     - Replaced the `.dialog`-only fast-path check in `CueSeekerMainWindow.isUncovered(_:)` with unified uncovered higher-layer checks (`field.interfaceLayer > .workbenchPage && !isLayerCovered(field.interfaceLayer) && !isBehindDialog(target)` for `WorkbenchNativeSingleLineTextField`, and matching `interfaceLayerContext.layer > .workbenchPage && !isLayerCovered(...) && !selectableText.isFrozenOrCovered && !isBehindDialog(target)` for `WorkbenchSelectableTextNSView`), keeping `.workbenchPage` fields on hit-test verification.
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchNativeTextFields.swift`:
     - Updated `WorkbenchSingleLineContainerOverlayView.findTextField(in:within:)` to inspect `view.subviews.reversed()` top-down and skip any `WorkbenchNativeSingleLineTextField` whose owning `CueSeekerMainWindow` reports `isLayerCovered(nativeField.interfaceLayer) == true` (pure set check without calling `isUncovered` to avoid recursion).

6. **Zero-count filter snapshot settlement & input selection reset cleanup**
   - `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore.swift` & `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackCommandPanel.swift`:
     - Removed `promoteZeroCountOnlySearchToCompletedEmptyResults()` and its conditional caller inside `presentPlaybackCommandPanelSearch(query:startsSearch:)`.
     - Unified zero-count settlement in `SearchStore.commitCountOnlySearch(totalCount:generation:)`: when `resolvedTotalCount == 0 && resultFacetFilter.isEmpty && searchFacetFilter.isEmpty` (unfiltered empty library hit), immediately settles `isCountOnlySearchSnapshot = false`, `setSearchFacetSnapshot(.empty, precomputedDistribution: .zero)`, and `pendingReappearanceRefreshMode = .none`; otherwise (any positive hit, or zero hits under an active `CueFacetFilter`), preserves `isCountOnlySearchSnapshot = true` and `pendingReappearanceRefreshMode = .rerunSearch` so submitting Search or exiting back to Workbench Search runs a full scan and populates real facet counts.
   - `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/{WorkbenchNativeTextFields.swift,WorkbenchFormControls.swift}`:
     - Marked `needsScrollSelectionVisibleOnLayout = true` on initial non-select-all focus in `applyInitialFocusSelectionInCurrentEditor()`, removed the redundant `layout()` branch that overwrote `editor.selectedRange()` before user interaction, simplified `setFrameSize(_:)` visibility scrolling to `if widthChanged, isCurrentlyFocused`, added `@objc(textViewDidChangeSelection:)` in `WorkbenchNativeSingleLineTextField` to mark `didUserInteractSinceAutofocus = true` on keyboard/selection divergence, and preserved valid selection lengths (`min(max(0, selection.length), length - clampedLocation)`) in `WorkbenchSingleLineTextInput.updateNSView`.

7. **Unit test updates and additions**
   - `apps/macos-native/Tests/CueSeekerAppTests/{SettingsStoreSearchTests.swift,WorkbenchAccessibilityStep3Tests.swift,WorkbenchInputControlsTests.swift,PlaybackSubtitleFocusKeyboardActionTests.swift}`:
     - Removed obsolete `prefillCommandPanelWithFocusedCue` / `.searchPrefillCommandPanel` references and updated Search field autofocus expectations to end-caret placement while preserving Rename dialog select-all coverage.
     - Added pure-logic tests `playbackCommandPanelPersistsSearchQueryAndReusesValidSearchSnapshot`, `playbackCommandPanelResolvesCopyCurrentCueAcrossPlaybackAndOverlayStates`, `playbackCommandPanelCopyCurrentCueFooterAndExecutionPreservePanelAndSearchFocus`, and `playbackCommandPanelFilteredZeroCountRecomputesFullFacetSnapshotOnSubmitAndReappearance`, and aligned zero-count assertions in `playbackCommandPanelRootLiveSearchUpdatesExactCountAndLoadsResultsOnDemand`.

## Compilation & Unit Test Verification

1. **After the zero-count filter snapshot & input selection fix**:
   - `swift build` (`apps/macos-native`): `Build complete! (9.64s)`, `0` errors.
   - `swift test --filter PlaybackSubtitleFocusKeyboardActionTests`: `37` Swift Testing cases passed (`0` failed).
   - `swift test --filter PlaybackReelCopyAndCommandPanelRoutingTests`: `4` Swift Testing cases passed (`0` failed).
   - `swift test --filter CueFacetFilterTests`: `14` Swift Testing cases passed (`0` failed).
2. **Earlier window-layer focus fix (`1375bb0`)**:
   - `swift build` (`apps/macos-native`): `Build complete! (6.20s)` (`0.31s` incremental), `0` errors; `swift test --filter InterfaceLayerFreezeTests` (`7` passed), `swift test --filter PlaybackReelCopyAndCommandPanelRoutingTests` (`4` passed).
3. **Earlier feature baseline (`b3c2486`)**:
   - Targeted headless `CueSeekerAppTests` filter (`73` passed) and `CueSeekerCoreTests` subtitle/focus filter (`18` passed).
4. **End-to-end acceptance**:
   - Live end-caret focus, arrow/selection preservation (`Cmd+A`, Left/Option+Left), horizontal scrolling in overflowing Search Fields, Filter modal behavior under empty/filtered zero counts, and `Copy Current Cue` visual presentation remain with the user for interactive acceptance.
