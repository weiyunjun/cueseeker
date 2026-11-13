# 2026-11-13: Table Cue Font Weight, Row Spacing, and Cell Line Height Refinement

## Requirement Source
- `docs/human/requirements/20261113-UI-Table Cue Font Weight Row Spacing And Cell Line Height Refinement.md`
- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Text Selection Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

## Summary of Changes
1. **Design Tokens (`WorkbenchControlMetrics.swift`, `SubtitleTableCueGeometry.swift`)**:
   - Added `--min-height-table-row: 48px` (`redesignTableRowMinHeight = 48`), `--padding-table-row-y: 12px` (`redesignTableRowPaddingY = 12`), `--gap-table-cue-group: 4px` (`redesignTableCueGroupGap = 4`), `--line-height-table-cell: 20px` (`redesignLineHeightTableCell = 20`), `--line-height-table-cue-primary: 24px` (`redesignLineHeightTableCuePrimary = 24`), and `--line-height-table-cue-secondary: 20px` (`redesignLineHeightTableCueSecondary = 20`) in `WorkbenchControlMetrics.swift`.
   - Kept `--padding-table-cell-hover-y: 8px` (`redesignTableCellHoverPaddingY = 8`) separate and unchanged from `--padding-table-row-y` (`12px`).
   - Wired `SubtitleTableCueGeometry` constants (`minimumRowHeight`, `rowPaddingY`, `cueGroupGap`, `primaryLineHeight`, `extraLineHeight`) directly to `WorkbenchControlMetrics` and bumped `styleRevision` (`2` -> `3`) for row measurement cache invalidation.
2. **Primary Cue Typography, Color & `Show Cue Group` Item Gap (`SubtitleTableCueGeometry.swift`, `SubtitleTableTextLayout.swift`, `SubtitleTableCoordinator+Drawing.swift`)**:
   - Updated `SubtitleTableCueStyle.primary.fontWeight` and `SubtitleTableText.bodyFont(role: .primaryContent)` from `.medium` (`500`) to `.regular` (`400`), preserving `--font-size-table` (`14px`) and `--line-height-table-cue-primary` (`24px`).
   - Adjusted normal-row `Cues` primary cue text color from `--color-text-primary` to `--color-text-secondary` (via `SubtitleTableText.bodyColor(role: .primaryContent)` and `SubtitleTableView.Coordinator.cueTextColors(for:)`), while preserving `--color-text-muted` on `Unavailable` primary cues and matching hover underline color (`cueHoverUnderlineColor(for:model:)`) to the fragment's row text color (`--color-text-secondary`).
   - Unified `cueTextFragments(...)`, `drawCues(...)`, `cuesContentHoverRect(...)`, and `isCuesCellHovered(row:isUnavailable:)` to share the single row-state-aware `cueTextColors(for:)` policy without stale `--color-text-primary` defaults.
   - Updated `SubtitleTableCueGeometry.cueBlockHeight` and `SubtitleTableRowMeasurement.extraCueOffsets` to space cue items with `cueGroupGap` (`4px`) instead of `rowPaddingY`, while source newlines and soft wraps inside one cue item continue stacking at fixed single-line boxes (`24px` / `20px`) with `0` extra item gap and glyphs visually centered per line box.
3. **Plain Text Column Line Boxes, Glyph Centering & Engineering Docs (`SubtitleTableTextLayout.swift`, `docs/engineering/`)**:
   - Extracted shared TextKit line-box helpers (`fixedLineParagraphStyle(lineHeight:)`, `naturalLineHeight(for:)`, `centeredBaselineOffset(for:lineHeight:)`) on `SubtitleTableText` and reused them across both `SubtitleTableCueStyle`/`SubtitleTableCueTextMeasurer` and `SubtitleTableText.body(...)` without logic duplication.
   - Switched plain-text table data columns (`Display Title`, `Time Range`, `Date Added`) from legacy `lineSpacing = 4` to fixed `20px` line boxes (`--line-height-table-cell`), `lineSpacing = 0`, `paragraphSpacing = 0`, `.baselineOffset` vertical glyph centering, and `layoutManager.usesFontLeading = false` in `SubtitleTextLayout` so click hit-testing, double/triple-click, drag selection rects, hover rects, and clipboard copy align with visual line frames (`visualLineCount * 20px`) and all columns, `#` index/checkbox, and trailing `dots-three` buttons remain centered in `max(48, maxContentHeight + 24)` (`?` unavailable icon centered on primary cue's first visual line).
   - Updated stale Cue table row-height formulas (`40 points`, `16 + 24P + 20S` -> `max(48, H_max + 24)`) across `docs/engineering/04_architecture_rules.md`, `docs/engineering/06_testing_rules.md`, and `docs/engineering/08_end_to_end_testing.md`.
4. **Tests (`SubtitleTableCueGeometryTests.swift`, `SubtitleTextLayoutTests.swift`, `WorkbenchControlMetricsTests.swift`, `SubtitleTableVirtualRowTests.swift`, `SubtitleTableCoordinator+Testing.swift`)**:
   - Updated token, typography weight, `.primaryContent` color (`textSecondary`), row-height formula, and visible-range notification assertions to match the refined specification.
   - Added `cueTextVisualStylesForTesting(row:)` and coordinator integration tests covering normal primary cue `--color-text-secondary`, hover underline matching `--color-text-secondary` in Light and Dark appearances, and unavailable `--color-text-muted` preservation with hover suppression.
   - Kept prior unit and coordinator coverage verifying fixed centered `20px` plain-text line boxes, all closed/open `Cue Group` and multi-line acceptance row heights (`48` / `64` / `72` / `96`), shared horizontal center axis across columns, preserved `8px` vertical hover padding (`40px` hover capsule), symmetric `12px` vertical cell padding under wrapped/multi-line `Display Title`, unavailable `?` / checkbox / `dots-three` alignment, and hit-testing/selection/clipboard copy alignment across `Display Title`, `Time Range`, and `Date Added`.

## Verification
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "SubtitleTable|SubtitleTextLayout|WorkbenchControlMetrics|TableSandbox|ExcerptPresentationTests|SearchStoreTests"`: all `297` tests passed (`2.771s`).
- Ran `swift test --package-path apps/macos-native --no-parallel --filter "WorkbenchAccessibility|SearchInvalidItems|ExcerptLifecycle|SelectionActionOverlayInvalidItemsTests|WorkbenchInvalidationTests|TableScrollbarPrimitiveTests"`: all `68` tests passed (`9.162s`).
- End-to-end visual verification is ready for user acceptance prior to post-acceptance updates under `docs/human/design/ui/`.
