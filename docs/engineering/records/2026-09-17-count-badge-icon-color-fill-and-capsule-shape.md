# Count badge: solid fill and capsule shape

Human-owned documents:

- `docs/human/requirements/20260917-UI-Count Badge Icon Color Fill And Capsule Shape.md`
- `docs/human/design/UI Design System.md` (Information Badge / Task Count Badge; to be updated by the owner after acceptance)

## Why

The keycap-style circle read as a washed-out grey next to the icon, deepened on hover, and its continuous-curvature capsule with tabular digits looked lopsided. The owner chose a solid fill that never reacts to hover, the shadcn way of colouring it and Ant Design's padding rule.

Classified as platform UI.

## What changed

- Fill and number, in the Task entry (three top bars), the Filter trigger and the Filter dialog's group headers:
  - Fill `--color-text-muted`, number `--color-bg-surface`.
  - Player top bar: fill `--color-player-text-primary`, number `--color-player-icon-selected`.
  - A disabled button draws the fill in `--color-text-disabled`, with its glyph.
  - Hover and Open leave the badge unchanged. The per-surface keycap fills and `--color-player-task-count-badge-bg` / `-hover` are gone from code.
- Shape: height `--size-control-icon`; one digit is a circle as wide as it is tall, two or more digits pad `--spacing-2` on each side; `Capsule()` with circular ends; proportional digits.

Owner tuning during the session, not written back to the requirement at the owner's instruction: the requirement's fill "the icon colour" (`#494949` / `#B9B9B9`) read too heavy in Light and too bright in Dark, so the fill is `--color-text-muted` (`#717171` / `#878787`).

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskEntryButton.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/TopbarAppEntries.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackTheme.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/TopBar/LiquidGlassVideoTopBar.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift`

## Verification

- `swift build`: passes.
- Full `swift test`: 1238 tests, 29 issues in 15 tests, all in the environment-sensitive set of the 2026-09-15 and 2026-09-16 records: native playback (6), Debug E2E scene and width (2), Excerpt scroll anchor (2), Library folder removal (1), `progressiveSearchProjectionRefreshesOnlyMountedTable`, `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`, `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks` and `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`. None reads the badge.
- Visual acceptance is the owner's, in the App.
