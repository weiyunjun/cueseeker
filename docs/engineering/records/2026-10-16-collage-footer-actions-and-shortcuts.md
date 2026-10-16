# Implementation Record: Collage Footer Actions And Shortcuts

- **Requirement**: `docs/human/requirements/20261016-UI-Collage Footer Actions And Shortcuts.md`
- **Date**: 2026-10-16

## Summary of Changes

1. **Unified Selection Count Copy & Collage Footer Actions (`PlaybackCueFooter.swift`, `PlaybackCollagePreview.swift`, `Localizable.strings`)**:
   - Simplified `table.selected_count` in `zh-Hans.lproj/Localizable.strings` (`已选 %d / %d 行`) and `zh-Hant.lproj/Localizable.strings` (`已選 %d / %d 行`) and added `playback.collage.selected_cue_count` (`Selected %d / %d cues` / `已选 %d / %d 句台词` / `已選 %d / %d 句台詞`).
   - Added `PlaybackCueFooterStatus.collageCues(selectedCount:totalCount:)` and `PlaybackCueFooterAction.collageActions(onCopy:onExport:onSelect:)` (`Copy Collage` $\rightarrow$ `Export Collage` $\rightarrow$ `Select`).
   - Removed the right-column bottom action bar (`playback-collage-preview-actions`) from `PlaybackCollagePreviewPane` so the right preview pane occupies the full height above the shared footer.

2. **Full-Width Collage Footer & Left Column Width (`PlaybackSubtitleFocusOverlay.swift`, `PlaybackSubtitleFocusReel.swift`)**:
   - Updated `PlaybackCollageEditor` so the top `HStack` holds the 50/50 cue list and preview pane, and a single full-width `PlaybackCueFooter` (`accessibilityIdentifier: "playback-subtitle-focus-footer"`) sits below both columns with horizontal padding `PlaybackSubtitleFocusMetrics.contentInset` (`32px`) and no `960px` max-width cap.
   - Added `usesFullWidth: Bool` to `PlaybackVirtualReelLayout` and passed `usesFullWidth: documentView.isEditingCollage` in `PlaybackSubtitleFocusReelContainerView` so the left Collage column uses its full available width without the `960px` cap.

3. **Collage Shortcuts & Settings Category (`PlaybackShortcuts.swift`, `SettingsShortcutsCategory.swift`, `AppCoordinator+Playback.swift`)**:
   - Added `PlaybackShortcutGroup.collage` and `PlaybackShortcutAction.copyCollage` (default `C`) / `.exportCollage` (default `E`), with `sharesPlace(with:)` scoping conflicts to `.collage`, `.editCollage`, and `.global` (`openCommandPanel`) while allowing `C` to be shared with `Copy Cue Text` in `.overlay`.
   - Added the `Collage` (`台词长截图` / `台詞長截圖`) group in `Settings -> Shortcuts` (`SettingsShortcutsCategory.swift`) directly below `Playback Overlay & Command Panel`.
   - Routed `.collage` shortcuts in `AppCoordinator+Playback.swift` when `subtitleFocusSession.isEditingCollage` is active.

4. **Complete Collage Toast Feedback State Machine (`PlaybackCollagePreviewStore.swift`, `PlaybackSubtitleFocusSessionStore.swift`, `PlaybackStore.swift`, `PlaybackViewModel.swift`)**:
   - Added `PlaybackCollageFeedbackEvent` (`.noCueSelected`, `.notReady`, `.copySucceeded`, `.copyFailed`, `.exportSucceeded`, `.exportFailed`) and `PlaybackCollageActionReadiness` (`actionReadiness()`).
   - Updated `copyCurrentCollage()` and `exportCurrentCollage()` in `PlaybackSubtitleFocusSessionStore` and `showCollageFeedback(_:)` in `PlaybackViewModel` to route all 4 branches (empty selection $\rightarrow$ `Select at least one cue`, rendering $\rightarrow$ `Collage isn't ready yet`, render/pasteboard/file failure $\rightarrow$ `Couldn't copy to clipboard` / `Couldn't export image`, and pasteboard/file success $\rightarrow$ `Collage copied` / `Collage exported`), while keeping `NSSavePanel` user cancellation silent.

## Verification

- Automated unit & integration tests (`swift test --filter "PlaybackShortcutKeymapTests|PlaybackSubtitleFocusLayoutTests|PlaybackCollagePreviewTests|PlaybackSubtitleFocusKeyboardActionTests|PlaybackSubtitleFocusSessionStoreTests"`):
  - Verified Collage shortcut defaults, conflict rules, and dynamic rebinding.
  - Verified `PlaybackCueFooterStatus.collageCues`, `PlaybackCueFooterAction.collageActions`, and full-width Collage reel layout (`usesFullWidth: true`).
  - Verified all 4 Collage action readiness/completion branches and `NSSavePanel` cancellation silence.
