# 2026-11-10: Watch Status Badge Border and Token Alignment

## Requirement Source
- `docs/human/requirements/20261110-UI-Watch Status Badge Border And Token Alignment.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`

## Summary of Changes
1. **Watch Status Badge Persistent Border Color Tokens (`WorkbenchRedesignColors`)**:
   - Added `watchStatusUnwatchedBorder` (Light `#D0D5DD`, Dark `#3F3F46`), `watchStatusWatchingBorder` (Light `#93C5FD`, Dark `#2563EB`), and `watchStatusFinishedBorder` (Light `#6EE7B7`, Dark `#059669`) in both `WorkbenchRedesignColors.NS` and `WorkbenchRedesignColors`.
2. **Watch Status Badge and `WorkbenchBadge` Token Alignment (`WorkbenchBadge`, `LibraryWatchStatus`, `WatchStatusBadge`, `RemoteFolderDialogSharedViews`)**:
   - Updated `WorkbenchBadge` to draw a persistent `1px` (`WorkbenchControlMetrics.redesignControlBorderWidth`) border, use `WorkbenchControlMetrics.redesignChipRadius` (`6px`), `WorkbenchControlMetrics.redesignChipHorizontalPadding` (`10px`), `WorkbenchControlMetrics.redesignChipVerticalPadding` (`4px`), `WorkbenchControlMetrics.redesignFontSizeCaption` (`12px`), and `WorkbenchControlMetrics.redesignFontWeightControl` (`.medium`), and resolve disabled state colors to `textDisabled`, `bgDisabled`, and `borderDisabled`.
   - Mapped `LibraryWatchStatus` (`unwatched`, `watching`, `finished`) and the remote folder browser `Added` badge (`Finished` style) to their respective border color tokens.
3. **Unit Tests (`FileCardMenuTests`)**:
   - Added `watchStatusBadgeBorderTokensAndMetricsAlignment` verifying Light/Dark hex values for all three watch status border tokens, `LibraryWatchStatus.borderColor` mappings, and chip/badge metric tokens.

## Verification
- Ran `swift test --package-path apps/macos-native --filter FileCardMenuTests`.
