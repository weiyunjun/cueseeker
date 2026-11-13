# 2026-11-13: Workbench List Cards & Playback Reel Selection Refinement

## Requirement Source
- `docs/human/requirements/20261112-UI-Workbench List Cards Playback Reel Selection Refinement And Rules Doc.md`
- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Accessibility Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

## Summary of Changes
1. **Remaining Workbench & Playback Group Headers and Footer Status Counts (`WorkbenchSelectableText.swift`, `WorkbenchRecentView.swift`, `PlaybackCommandPanel.swift`, `WorkbenchFileView.swift`, `PlaybackCueFooter.swift`)**:
   - Added optional `truncationMode: Text.TruncationMode?` support (`.middle` / `.head` / `.tail`) and right-click selection clearing in `WorkbenchSelectableText`.
   - Switched `RecentSectionTitleView` (`WorkbenchRecentView.swift`), `PlaybackCommandPanelSecondaryHeader` (`PlaybackCommandPanel.swift`), `File` Level 1 `rootFoldersHeaderRow` and Episode `object.displayTitle` (`WorkbenchFileView.swift`), and `PlaybackCueFooter` left `status` text (`PlaybackCueFooter.swift`) to `WorkbenchSelectableText`.
2. **Non-Full-Card-Click List Cards, Parent Hover Preservation, Right-Click Menu Coexistence & Global Non-Selectable Boundaries (`PointerHover.swift`, `WorkbenchPopoverControls.swift`, `WorkbenchFileView.swift`, `TaskPanel.swift`, `RemoteFolderDialogSharedViews.swift`)**:
   - Added `tracksHostedContent` handling in `PointerHover` (tracking area upgrade to `.assumeInside` on `mouseEntered` plus `PointerHoverSession.report(false)` in-bounds keep-alive) so hovering selectable text keeps parent card `Hover` background and trailing `dots-three` visibility intact.
   - Updated `WorkbenchCardRightClickMonitor` (`WorkbenchPopoverControls.swift`) to clear `WorkbenchStaticTextSelectionCoordinator.shared` before opening the card context menu on right-click.
   - Enabled selectable text on `File` Episode video/subtitle rows (`WorkbenchFileCard` when `onTap == nil` with `.onPointerHover(tracksHostedContent: onTap == nil)`), `TaskPanel` card lines (`TaskCardTitleView`, queued/running/history status/subtitle, and `Incomplete` error lines inside `TaskCardContainer` with `.onPointerHover(tracksHostedContent: true)`), and Remote Step 2 `WebDAVBrowserCard` non-clickable `Added` folder and pure video/subtitle file titles (`WorkbenchSelectableText(..., isSelectable: !isCardInteractive).allowsHitTesting(!isCardInteractive)` while keeping `Added` badges and `>` drill-down buttons non-selectable).
   - Preserved non-selectable boundaries on `Breadcrumb` (including the rightmost non-clickable current directory node), `Media Card`, standalone clickable `File` folder cards (`onTap != nil`), Remote unadded folder cards and `>` buttons, badges, chrome, and `Toast`/`Tooltip`, ensuring diagonal drags starting from `File` Level 2 `Breadcrumb` skip the breadcrumb and select Episode `displayTitle` cleanly from character index `0`.
3. **Decoupled `Playback Cue Reel` Internal Non-Text Drag Entry (`PlaybackCueResult.swift`, `PlaybackSubtitleFocusReelDocumentView.swift`, `PlaybackSubtitleFocusReel.swift`)**:
   - Left `WorkbenchStaticTextSelectionCoordinator.swift` untouched and decoupled from subtitle reel internals, maintaining mutual exclusion via `.cueSeekerClearTextSelection` notification (`appClearTextSelection(_:)` in `PlaybackSubtitleFocusReel.swift` ignoring `(notification.object as? NSView) === documentView`).
   - Added self-contained `ArmedNonTextSelectionDrag` (`dragSelectionThreshold = 3.0`), Liang-Barsky `segmentEntryPoint`, `firstEnteredSelectableText`, and `beginNonTextEnteredSelectionIfNeeded` in `PlaybackCueResult.swift` and `PlaybackSubtitleFocusReelDocumentView.swift` so dragging from row spacing, padding, non-selectable timestamps/metadata, or hover controls inside `Current`, `Subtitle Playlist`, and `Command Panel Search Results` computes the clamped anchor within the entered cue, locks `.iBeam` during drag, and suppresses click/button activation while keeping `Collage` (`isEditingCollage`) non-selectable.
4. **Tests (`WorkbenchSelectableTextTests.swift`, `TaskCardMenuTests.swift`, `PlaybackPlaylistReelAdapterTests.swift`, `PlaybackSubtitleFocusLayoutTests.swift`, `WorkbenchAccessibilityStep4Tests.swift`)**:
   - Added and updated tests covering middle truncation suffix hit testing and full copy restoration, remaining headers/footer counts and Remote Step 2 card boundaries, `File` Level 2 diagonal drag entry from `Breadcrumb` into Episode `displayTitle`, list card hover probe preservation and right-click selection clear before menu open, `TaskPanel` card selectable lines and hosted hover probes, `Playback Cue Reel` internal non-text drag entry with clamped anchors, `Collage` exclusion, mutual exclusion with static text, and accessibility alignment.

## Verification
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "TaskCardMenuTests|WebDAVFolderDialogTests|WorkbenchAccessibilityStep4Tests"`: `28` tests passed (`1.356s`).
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "FileCardMenuTests|FileRouteNavigationTests|PointerHoverGateTests"`: `32` tests passed (`0.866s`).
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "PlaybackCueResultLayoutTests|PlaybackPlaylistReelAdapterTests|cueReelNonTextDragEntrySelectsFromClampedAnchorAndCollageStaysNonSelectable"`: `22` tests passed (`2.778s`).
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "WorkbenchSelectableTextTests|PlaybackCueResultLayoutTests|PlaybackPlaylistReelAdapterTests|cueReelNonTextDragEntrySelectsFromClampedAnchorAndCollageStaysNonSelectable|PlaybackSubtitleFocusKeyboardActionTests|PlaybackSearchOverlayTests|SettingsAndDialogsStaticTextSelectionTests|WorkbenchControlMetricsTests|RecentPlaybackSessionRegressionTests"`: `116` tests passed (`8.969s`).
- Ready for user end-to-end acceptance before drafting post-acceptance `docs/human/design/ui/` documentation updates (`UI Text Selection Rules.md` and `UI Index.md`).

## Follow-up Fix: Command Panel `Cmd + C` Routing & Subtitle Reel Selection Copy

### Scope & Changes

1. **`Command Panel` modifier pass-through & `Cmd + C` copy priority over custom `⌘C` shortcuts**
   - Updated `handlePlaybackCommandPanelKeyDown` in `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackInputRouter.swift` so disallowed modifier / shift combinations return `false` instead of `true`, matching `handlePlaybackSubtitleFocusKeyDown` and `handlePlaybackCollageKeyDown` and allowing `Cmd + C`, `⌘,`, `⌘W`, `⌘Q` to reach window/menu handling while still blocking fallthrough to underlying `Player Stage` shortcuts.
   - Added `window: NSWindow? = nil` propagation from `AppDelegate.keyDownMonitor` into `AppCoordinator.handlePlaybackKeyDown`, plus `AppCoordinator.canCopyTextSelection(in:)` checking both static text selections and uncovered subtitle reel selections. When plain `Cmd + C` is pressed while an active copyable text selection exists or an editable text input is focused, `handlePlaybackKeyDown` returns `false` before `openCommandPanel` and custom `⌘C`-bound playback/overlay/collage shortcuts; once cleared, custom `⌘C` shortcuts execute as configured.

2. **Silent `Cmd + C` & `Edit -> Copy` for `Playback Current`, `Playback Subtitle Playlist`, and `Command Panel Search Results` reels**
   - Added read-only `selectedText` on `PlaybackSubtitleFocusReelDocumentView` (`PlaybackSubtitleFocusReelDocumentView.swift`) and silent copy/query helpers (`selectedTextForCopy`, `canCopySelectedText`, `copySelectedTextToPasteboard`, window-scoped `canCopySelection(in:)`, `copySelection(in:to:)`) on `PlaybackSubtitleFocusReelContainerView` (`PlaybackSubtitleFocusReel.swift`) that write via `CueClipboard.copy` without displaying a Toast or dismissing the selection / open `Copy Selected Text` menu.
   - Enforced layer-occlusion boundaries (`window`, hierarchy visibility & alpha, `!isCoveredByHigherLayer`, `interfaceLayers.isCovered(menuOwner)`, unrelated-menu freeze guard, and dialog bounds/coverage via `CueSeekerMainWindow`) and passed `isCoveredByHigherLayer: layerContext.isCovered` for `PlaybackCommandPanelSearchResults` (`PlaybackCommandPanel.swift`).
   - Wired `CueSeekerWindow` (`performKeyEquivalent(with:)`, `copy(_:)`, `validateMenuItem(_:)`) in `CueSeekerMainWindow.swift` and responder-chain fallback in `WorkbenchSelectableTextNSView` (`WorkbenchSelectableText.swift`) to `CueSeekerWindow.canCopyActiveSelection(in:)` / `CueSeekerWindow.copyActiveSelection(in:to:)`.

### Verification

- Added `apps/macos-native/Tests/CueSeekerAppTests/PlaybackReelCopyAndCommandPanelRoutingTests.swift` covering Command Panel secondary page `Cmd + C` pass-through & static text copy, custom `⌘C` shortcut yielding/resumption, silent `Cmd + C` / `Edit -> Copy` across all three subtitle reels (with open `Copy Selected Text` menu), and `Command Panel` / `Dialog` layer occlusion boundaries.
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "PlaybackReelCopyAndCommandPanelRoutingTests|PlaybackSubtitleFocusKeyboardActionTests|WorkbenchSelectableTextTests|PlaybackPlaylistReelAdapterTests|SettingsAndDialogsStaticTextSelectionTests|PlaybackNormalShortcutTests|PlaybackShortcutKeymapTests|WorkbenchAccessibilityStep4Tests|WorkbenchDialogLayerTests|PlaybackSearchOverlayTests"`: all `110` tests passed.
