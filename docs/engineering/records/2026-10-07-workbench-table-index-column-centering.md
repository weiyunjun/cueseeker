# Workbench Table Index Column Centering and Five Digit Capacity

Human-owned documents:

- `docs/human/requirements/20261007-UI-Workbench Table Index Column Centering.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Problem**:
   - In Workbench tables (Search, Excerpt List), the index column (`#`) displayed visual horizontal misalignment: the row numbers were left-aligned at `cellLeading = 12pt`, while the Checkbox (shown on hover or during batch selection) was centered at `25.0pt`. Hovering a row caused the visual center to jump ~10pt to the right.
   - The `#` header text in redesign mode had a 12pt horizontal padding and was left-aligned, creating a similar visual offset relative to the centered header Checkbox.
   - Available width for row indices in redesign was constrained to 32pt, causing 5-digit numbers to wrap or get clipped.

2. **Root Cause**:
   - `drawIndex` passed `rect.width - cellLeading (12) - indexTrailingInset (6)` to `textLayout.update` and drew text at `rect.minX + cellLeading (12)`.
   - `SubtitleTableHeaderCellView` used a leading-aligned `HStack` with 12pt horizontal padding for all column headers, without alignment customization for the `#` column.
   - `SubtitleTableText.index` used proportional digits without centering paragraph style attributes.

## What changed

1. **Header `#` Centering (`SubtitleTableView.swift`)**:
   - Added an `alignment: Alignment = .leading` parameter to `SubtitleTableHeaderCellView` and `updateHeaderHost`.
   - Configured `refreshIndexHeaderHost` to pass `alignment: .center` for `#`, centering the text in the 50pt column with identical horizontal center (`X = 25.0pt`) as the Checkbox.

2. **Row Index Centering and 5-Digit Capacity (`SubtitleTableView.swift`)**:
   - Updated `SubtitleTableText.index` in redesign mode to use `NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)` with paragraph style alignment `.center` and `.byClipping` line break mode.
   - Updated `drawIndex` in redesign mode to layout text across `rect.width` (50pt) and draw at `rect.minX` with vertical centering, keeping mathematical horizontal alignment at `25.0pt` across all numbers (1 to 5+ digits) with ~6pt safety padding on each side.

3. **Tests (`SubtitleTextLayoutTests.swift`)**:
   - Added unit test `subtitleTableIndexTextCentersAndAccommodatesFiveDigitsInRedesign` verifying that 1-digit and 5-digit numbers remain strictly single-line, center at `25.0pt`, and maintain > 5pt margins within the 50pt column.

## Verification

- `swift build --product CueSeeker --package-path apps/macos-native`: passed.
- `swift test --package-path apps/macos-native --filter SubtitleTextLayoutTests`: passed (5/5 tests passed).
- `swift test --package-path apps/macos-native --filter SubtitleTable`: passed (188/188 tests passed).
