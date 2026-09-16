# Dark mode: layers lighten toward the top

Human-owned documents:

- `docs/human/requirements/20260917-UI-Dark Mode Layers Lighten Toward The Top.md`
- `docs/human/design/UI Design System.md` (Core Tokens / 颜色 and the components the requirement lists; to be updated by the owner after acceptance)

## Why

In Dark the sidebar was lighter than the page, the table, page, dialogs and Command Panel shared one near-black, menus were barely lighter than the page, and the Command Panel was darker than the Playback Overlay under it. The owner chose one rule, lighter toward the top, after comparing macOS System Settings, Material and Atlassian elevation, with translucent white fills for anything that sits on several surfaces.

Classified as platform UI.

## What changed

- Dark surface values: Sidebar `#111113`, page and topbar `#1C1C1F`, Settings cards `#26262A`, menus `#36363B`, dialog scrim black 50%.
- New tokens, Light equal to the colour each place used before:
  - `tableBg` (`#26262A`): the Workbench Search and Excerpt table header and body. The table container stays the page, because on the Excerpt detail page it also holds the page chrome; the header view and the row drawing paint the table surface themselves.
  - `bgDialog` (`#2F2F34`): the dialog container, every dialog's own content background, Task cards and the Command Panel.
  - `bgControl` (white 8%): Search Field, Text Field chrome (Text Field, Text Area, Shortcut Field), Number Field, Segmented Control, Filter Chip default, Button and Destructive Button default.
  - `commandPanelScrim` (black 32% in both): replaces the fixed value in the Command Panel.
- Dark state and border values: hover white 12%, disabled white 4%, unchecked checkbox background white 8%, divider white 10%, control and muted borders `#4A4A52`, checkbox border `#5A5A62`, row hover `#2E2E33`, row selected `#36363C`, keycaps white 10% / 16%, shortcut button hover white 6%.
- Dark text: primary `#E4E4E4`, muted `#979797`; the selected Subtitle Focus cue is white 88%. The playback tab selection keeps its own 94%, now a separate constant.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogLayer.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchConfirmationDialog.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchFormControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchSegmentedControl.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Library/LibraryRenameDialog.swift`
- `apps/macos-native/Sources/CueSeekerApp/Library/LibraryEditCoverDialog.swift`
- `apps/macos-native/Sources/CueSeekerApp/Excerpt/ExcerptListEditor.swift`
- `apps/macos-native/Sources/CueSeekerApp/Export/AnkiExportDialog.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCommandPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackTheme.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackCueResultLayoutTests.swift` (selected cue alpha 0.88, dark checkbox border `#5A5A62`)

Open point: the checkbox is drawn as a monochrome Phosphor glyph with no background, so the unchecked background token, changed as required, is still not rendered anywhere. Reported to the owner.

## Verification

- `swift build`: passes.
- `swift test --filter 'PlaybackCueResultLayoutTests|SubtitleTextLayoutTests'`: 19 tests pass.
- Full `swift test`: 1238 tests, 32 issues in 17 tests. 15 are the environment-sensitive set of the 2026-09-17 count badge record: native playback (6), Debug E2E scene and width (2), Excerpt scroll anchor (2), Library folder removal (1), `progressiveSearchProjectionRefreshesOnlyMountedTable`, `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`, `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks` and `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`. The other two are Library folder removal tests; all three Library folder removal tests pass when run alone. None reads a colour.
- Visual acceptance is the owner's, in the App.
