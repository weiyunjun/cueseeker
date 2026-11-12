# 2026-11-12: Continuous Static Text Flow Selection, Blank Drag Entry, and Clipboard Format

## Requirement Source
- `docs/human/requirements/20261112-UI-Continuous Static Text Flow Selection Blank Drag Entry And Clipboard Format.md`
- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

## Summary of Changes
1. **Scoped Continuous Static Text Flow Engine (`WorkbenchSelectableText.swift`, `WorkbenchDialogLayer.swift`)**:
   - Evolved `WorkbenchStaticTextSelectionCoordinator` from single-node tracking into a reading-order continuous text flow scoped strictly to the topmost active surface (`Description Detail Popover` > topmost uncovered modal dialog > active Main/Settings page).
   - Propagated `isWorkbenchDialogCovered` from `WorkbenchDialogChrome` so covered lower stacked dialogs are excluded from interaction and flow scope.
   - Ordered selectable nodes top-to-bottom by visual row (preserving pinned header ordering ahead of scrolled `NSScrollView` rows) and left-to-right within the same horizontal row, skipping non-selectable controls (icons, progress bars, buttons).
   - Projected the selection anchor strictly from the initial `leftMouseDown` window coordinate without segment intersection or binary search, and enforced strict vertical boundary clamping (`y < firstVisibleRow.minY` clamps to first node offset `0` with zero top horizontal tolerance band; `y > lastVisibleRow.maxY` clamps to last node end offset).
2. **Blank-Area & Click-Control Drag Entry, Native-Drag Exemptions & Mutual Exclusion (`CueSeekerMainWindow.swift`, `SubtitleTableExternalTextSelection.swift`, `SchemaWorkbenchSearchShell.swift`, `LibraryCoverCropEditor.swift`, `AnkiExportDialog.swift`, `PlaybackProgressScrubber.swift`, `PlaybackVolumeControl.swift`)**:
   - Coordinated window-level `leftMouseDown` / `leftMouseDragged` / `leftMouseUp` in `CueSeekerMainWindow.sendEvent` via `WindowMouseEventDisposition` (`.passthrough` / `.consume` / `.redirect`), activating static text selection once a drag from blank space, non-selectable text, or click-only controls crosses selectable text with a non-empty selection (`anchor != focus`), keeping `.iBeam` active throughout the drag, cancelling originating control pressed/hover-pending state (`.cueSeekerCancelControlPress` + offscreen cancel routing), and suppressing click on release while preserving stationary single-click on `Grab` clickable text.
   - Added `CueSeekerNativeDragRegionView` / `.cueSeekerNativeDragRegion(isActive:)` and attached it to `LibraryCoverCropEditor`, `AnkiCardBadgeRow`, `PlaybackProgressScrubber`, and `PlaybackVolumeSlider` alongside `DraggableNSView`, traffic-light buttons, editable text inputs, scrollbars, and sliders in `SubtitleTableTextSelectionHitTesting.ownsDragOrTextInputGesture`.
   - Updated `SubtitleTableExternalTextSelectionSession.drag` to check `isDraggingSelection` and cleared static text selection on entering `Select Mode`, ensuring smooth mutual exclusion between static text flows (such as `Excerpt` `Cover Summary`) and `SubtitleTable` / `PlaybackSubtitleFocusReel`.
3. **Viewport Edge Auto-Scrolling, Clipboard Format & `...` Full Text Extraction (`WorkbenchSelectableText.swift`, `CoverSummaryCard.swift`, `WorkbenchExcerptTableView.swift`, `CueSeekerMainWindow.swift`)**:
   - Added 30Hz smooth edge auto-scrolling across `NSScrollView` (`WorkbenchScrollView` / `Description Detail Popover`) and `SubtitleTablePageChromeViewportView` (`Excerpt` detail page), reusing `SubtitleTableTextDragAutoScrollGeometry.nextOrigin` while keeping the initial anchor character pinned even after scrolling offscreen.
   - Serialized multi-node selections with `\t` between horizontal peers on the same visual row (only when both are selected) and `\n` across vertical rows/nodes; restored the full untruncated underlying string whenever selection reaches the visible end of `...`-truncated text (both TextKit single-line/multi-line tail truncation and pre-normalized/pre-truncated `fullCopyText` in `Cover Summary` expandable descriptions and `Excerpt` cue progress previews).
   - Wired `Cmd + C` and `Edit -> Copy` (`validateMenuItem` / `copy(_:)` on both `CueSeekerMainWindow` and `WorkbenchSelectableTextNSView`) without adding a right-click copy context menu.
4. **Unit & Integration Tests (`WorkbenchSelectableTextTests.swift`)**:
   - Updated and added tests covering top-left diagonal drag entry with strict top/bottom vertical clamping, `Grab` link click vs drag disambiguation, click-control drag entry with press cancellation and native-drag exemptions, `\t` / `\n` clipboard serialization and `Edit -> Copy` menu validation, single-line/multi-line TextKit `...` and `fullCopyText` full text extraction, `NSScrollView` viewport edge auto-scrolling + pinned header ordering, dialog scope isolation, and `SubtitleTableExternalTextSelectionSession` mutual exclusion.

## Verification
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "WorkbenchSelectableText|SubtitleTableExternalTextSelection|CoverSummaryCard|WorkbenchInputControls|PointerShape"` (`53` tests passed).
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "SubtitleTableTextSelection|SubtitleTableClipboard|SubtitleTableVirtualRow"` (`134` tests passed).
- Result matched all requirement constraints and acceptance criteria; end-to-end visual verification is ready for user acceptance.
