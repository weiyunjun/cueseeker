# Implementation Record: Horizontal Spacing Refinement

- Date: 2026-10-21
- Requirement: `docs/human/requirements/20261021-UI-Horizontal Spacing Refinement.md`
- Branch: `main`

## Scope Delivered

1. **Unified `--spacing-4` (`16px`) Horizontal Spacing for `36px` Button Groups and Page Action Bars**
   - Updated all dialog footer action button rows from `--spacing-2` (`8px`) to `--spacing-4` (`16px`) across `LibraryEditCoverDialog.swift`, `ExcerptListEditor.swift`, `LibraryRenameDialog.swift`, `WebDAVFolderDialog.swift`, `SMBFolderDialog.swift`, `FTPFolderDialog.swift`, `NFSFolderDialog.swift`, `AnkiExportDialog.swift`, `CueFacetFilterPanel.swift`, and `WorkbenchConfirmationDialog.swift`.
   - Updated `CoverSummaryCard.swift` action row horizontal spacing (`Play / Resume`, `View in File`, `More (...)`) from `--spacing-2` (`8px`) to `--spacing-4` (`16px`).
   - Updated top action and toolbar rows from `--spacing-3` (`12px`) to `--spacing-4` (`16px`) across `WorkbenchFileView.swift` (`actionRow` and `statusAndActionRow`), `SchemaWorkbenchSearchShell.swift` (`SchemaWorkbenchSearchToolbar`), `PlaybackCommandPanel.swift` (`PlaybackCommandPanelSearchResults` header controls), `LibraryOverviewComponents.swift` (`LibraryOverviewLayout`), and `WorkbenchTestLibraryView.swift` (`sortBar`).

2. **Unified `C-03.3 Shortcut Action Button` Horizontal Spacing (`PlaybackCueFooter.swift`)**
   - Updated `PlaybackCueFooter` action button row `horizontalSpacing` from `--spacing-1` (`4px`) to `--spacing-2` (`8px`).
   - Updated `PlaybackCueFooterActionButton` inline padding from `--spacing-2` (`8px`) to `--spacing-3` (`12px`) and label-to-keycap spacing from `--spacing-1` (`4px`) to `--spacing-2` (`8px`) while keeping multi-keycap internal spacing at `--spacing-1` (`4px`), matching `SchemaWorkbenchSelectionActionOverlay.swift`.

3. **Unified `Task` Icon Button Badge Gap with `Filter` Button (`WorkbenchControls.swift`)**
   - Updated `WorkbenchControlMetrics.redesignTaskCountBadgeGap` to `--spacing-2` (`8px`), replacing the custom glyph-ink deduction formula so `Task` and `Filter` buttons share the same `8px` icon-to-badge spacing.

4. **Dialog Two-Column and File Header Horizontal Spacing (`AnkiExportDialog.swift`, `WorkbenchFileDetailDialog.swift`)**
   - Updated `Export to Anki` dialog `Front` and `Back` column gap from `--spacing-3` (`12px`) to `--spacing-5` (`20px`).
   - Updated `File Detail` dialog file header icon-to-title spacing from `--inset-dialog` (`24px`) to `--spacing-4` (`16px`).

## Verification

- Added unit test `taskCountBadgeGapMatchesFilterButtonSpacingToken` in `WorkbenchControlMetricsTests.swift` and verified tests pass via `swift test`.
