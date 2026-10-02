# File and Task Card Layout Alignment

Human-owned documents:

- `docs/human/requirements/20261002-UI-File And Task Card Layout Alignment.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Visual Symmetry and Icon Alignment**:
   - Previously, bare outline icons had varying bounding boxes and ink outlines across different asset types (e.g. folder, video, subtitles, task status glyphs), leading to perceived misalignment.
   - Enclosing the icon in a uniform 36×36px rounded container (`--radius-control` 8px, background `--color-bg-hover`) with a centered 20px glyph provides a concrete, consistent visual boundary for the user's eye and matches the height of the standard 2-line text block.
2. **Four-Side Equal Internal Spacing Baseline**:
   - When cards contain standard 2-line text (Title 1 line + Subtitle/Path/Date 1 line = 36px text block), the card achieves a 4-side equal internal padding of $P$ (`--spacing-4`, 16px).
   - Baseline card height is 68px ($16\text{px top} + 36\text{px icon/text} + 16\text{px bottom}$).
   - Left margin (card left inner edge to icon container left edge) = $P$.
   - Icon-to-text gap (icon container right edge to text column left edge) = $P$.
   - Right margin for File card (rightmost button right edge to card right inner edge) = $P$.
   - Trailing action buttons (40px) are vertically centered within the 68px baseline card (14px top offset, 14px bottom offset).
   - Task card trailing padding is standardized to $P$ (visually presenting 3-side equal spacing: left, top, bottom).
   - Top and bottom padding in standard 2-line state = $P$.
3. **Multi-Line Top-Pinned Alignment**:
   - In earlier implementations, cards used vertical center alignment (`alignment: .center`), which caused the icon and trailing buttons to drop down towards the vertical middle when paths or titles wrapped into multiple lines or when a task card rendered a 3rd-line progress bar or error message.
   - The new design establishes top alignment (`alignment: .topLeading` on the card container) with top padding pinned at $P$, allowing the text and supplementary elements to expand downwards without shifting the icon container or action buttons.

## What changed

- **WorkbenchControlMetrics & Redesign Tokens**:
  - In `WorkbenchControls.swift`:
    - Updated `redesignCardIconContainerSize`: 36px (matches 36px 2-line text block).
    - Updated `redesignCardIconGlyphSize`: 20px (centered inside the 36px container).
    - Added `redesignCardBaselineHeight`: 68px ($16\text{px top} + 36\text{px icon/text} + 16\text{px bottom}$).
    - Added `redesignCardTrailingButtonTopAlignmentOffset`: 2px (adjusts 40px button top margin from 16px down to 14px to achieve vertical centering in baseline card).
    - Removed `redesignTextCapOpticalOffset` to maintain natural alignment with the 36px container.
- **WorkbenchCardIcon Component**:
  - In `WorkbenchControls.swift`:
    - Created reusable `WorkbenchCardIcon` view with 36×36 continuous rounded rectangle, `--color-bg-hover` background fill, and centered `AppIconImage` (20px) using `--color-text-secondary`.
- **WorkbenchFileView**:
  - In `WorkbenchFileCard`:
    - Switched `HStack` alignment from `.center` to `.top`.
    - Set `minHeight: WorkbenchControlMetrics.redesignCardBaselineHeight, alignment: .topLeading` on the card container.
    - Replaced bare `AppIconImage` with `WorkbenchCardIcon(icon: icon)`.
    - Added `.alignmentGuide(.top)` with `redesignCardTrailingButtonTopAlignmentOffset` to vertically center trailing action buttons.
- **TaskPanel**:
  - In `TaskCardContainer`:
    - Switched `HStack` alignment from `.center` to `.top`.
    - Set `minHeight: WorkbenchControlMetrics.redesignCardBaselineHeight, alignment: .topLeading` on the card container.
  - In `TaskCurrentCard`:
    - Replaced bare `AppIconImage` with `WorkbenchCardIcon(icon: entry.record.icon)`.
  - In `TaskHistoryCard`:
    - Replaced bare `AppIconImage` with `WorkbenchCardIcon(icon: record.icon)`.
- **Tests**:
  - In `WorkbenchControlMetricsTests.swift`:
    - Updated `cardIconContainerMetricsMatchDesignSpecification` test verifying `redesignCardIconContainerSize == 36`, `redesignCardIconGlyphSize == 20`, `redesignCardBaselineHeight == 68`, and `redesignCardTrailingButtonTopAlignmentOffset == 2`.
- **AppIconLineWidth Registration**:
  - In `AppIcon.swift`:
    - Registered `24: 1.40` in `AppIconLineWidth.bySize` (supported for 24px assets).
  - In `AppIconAssetTests.swift`:
    - Updated `lineWidthTableMirrorsTheIconRegistry` test to include 12px and 24px sizes.

## Verification

- Built and ran tests:
  - `swift test --filter WorkbenchControlMetricsTests` passed with 6 tests.
  - Verified no regression on existing UI control metrics.
- Visual inspection via interactive prototype confirmed equal $P$ margin on all sides and pinned top alignment for multi-line cards.
