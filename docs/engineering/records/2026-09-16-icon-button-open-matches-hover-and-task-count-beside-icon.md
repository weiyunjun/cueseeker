# Icon Button Open matches Hover, and the task count sits beside the icon

Human-owned documents:

- `docs/human/requirements/20260916-UI-Icon Button Open Matches Hover And Task Count Beside Icon.md`
- `docs/human/design/UI Design System.md` (Icon Button, Information Badge / Task Count Badge; to be updated by the owner after acceptance)

## Why

The solid grey Open block with a white glyph read heavier than anything else on the top bar, and the task count sat on the button's corner in the accent colour. The owner chose the shortcut button's language instead: Open looks like Hover, and the count is a keycap-like circle that deepens when the button is lit.

Classified as platform UI. No product semantics change: the count is still running plus queued.

## What changed

- Icon Button: Open paints the surface's hover step, the same as Hover, and the glyph keeps its own colour. The Open branches to `--color-text-muted` and `--color-icon-on-dark` are gone. This applies to every Icon Button with Open: Task, Settings, Filter, Select, Collage.
- The count is drawn inside the Icon Button, beside the glyph, only when it is above zero; otherwise the box stays the 32pt square. The Hover and Open fill covers glyph and count, and a click on the count is a click on the button.
  - Gap: `--spacing-1` from the glyph's ink. `list-checks` ends at 216 of its 256-unit grid plus half the 1.35pt line, so the gap is `4 - (21 - (21 × 216 / 256 + 0.675))` ≈ 1.39pt, computed from the size and line-width table rather than written out.
  - Horizontal padding is the box's own slack, `(32 - 21) / 2`, so the count ends as far from the edge as the glyph sits from the top.
  - Badge: height and minimum width `--size-control-icon` (21pt), inline padding `--spacing-1`, capsule, 13pt, semibold, monospaced digits, text in the button's icon colour.
- Circle colours per surface, Default and Hover/Open:
  - Workbench top bar: the popover surface keycap pair (the defaults).
  - Playback Overlay top bar: the overlay surface keycap pair.
  - Player top bar: new `--color-player-task-count-badge-bg` white 16% and `-hover` white 28%, in `PlaybackTheme`.
- Removed `--color-task-count-badge-bg`, `--color-task-count-badge-text` and `--size-task-count-badge` from code; `--font-size-task-count-badge` is 13px; added `--font-weight-task-count-badge` 600.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskEntryButton.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/TopbarAppEntries.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackTheme.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/TopBar/LiquidGlassVideoTopBar.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift`

## Verification

- `swift build`: passes.
- Full `swift test`: 1231 tests, 32 issues in 18 tests: native playback (6), Debug E2E scene and width (2), Library folder removal (3), Excerpt scroll anchor (2), `progressiveSearchProjectionRefreshesOnlyMountedTable`, `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, `playbackExcerptCopiesSettledPrimaryCueAsMarkdownLink` (expects English feedback text), `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues` and `subtitleTableViewUsesExplicitColumnOrderForTextColumns`. The last two pass alone; the rest are the environment-sensitive set of the 2026-09-15 records. None reads an Icon Button.
- App, Debug E2E controller, live library, 1445 × 821, no tasks queued:
  - Light: Task panel open, the Task button is a light block with the dark glyph; Settings window open, the gear is the `#F3F4F6` block with the dark glyph.
  - Dark: Settings open and Task panel open show the `#27272A` block with the light glyph; Filter dialog open on Search shows the same block on the filter button.
  - Appearance was switched through Settings and set back to Light; the Filter dialog was cancelled.

## Known limits

- The count's states (1 digit, 2 digits, each in Default, Hover and Open, on three surfaces) were not seen in the App. The queue fills only from real Anki exports or renames, which write files and task history in the live library, and the E2E controller has no way to hold a count. They need a manual check, or a new E2E capability.
- Hover is not automatable (`docs/engineering/08_end_to_end_testing.md` §1.1). Open now draws the same fill, so the Open captures show the hover look.
- The player and Playback Overlay top bars size their centred title or Tabs from a trailing region of square buttons. With a count, the Task button is about 22 to 30pt wider, so in a narrow window the centred content could reach the count. Not changed here; it needs the bars to read the task count.
- `UI Design System.md` still describes the old Open state and badge; per the owner's instruction it is updated after acceptance.
