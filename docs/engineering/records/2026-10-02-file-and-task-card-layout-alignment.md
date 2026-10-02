# File and Task Card Layout Alignment

Human-owned documents:

- `docs/human/requirements/20261002-UI-File And Task Card Layout Alignment.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Visual Symmetry and Icon Alignment**:
   - Previously, bare outline icons had varying bounding boxes and ink outlines across different asset types (e.g. folder, video, subtitles, task status glyphs), leading to perceived misalignment.
   - Enclosing the icon in a uniform 40×40px rounded container (`--radius-control` 8px, background `--color-bg-hover`) provides a concrete, consistent visual boundary for the user's eye and aligns directly with mainstream frontend design conventions.
2. **Four-Side Equal Internal Spacing Baseline**:
   - When cards contain standard 2-line text (Title 1 line + Subtitle/Path/Date 1 line), the card achieves a 4-side equal internal padding of $P$ (`--spacing-4`, 16px).
   - Left margin (card left inner edge to icon container left edge) = $P$.
   - Icon-to-text gap (icon container right edge to text column left edge) = $P$.
   - Right margin for File card (rightmost button right edge to card right inner edge) = $P$.
   - Task card trailing padding is standardized to $P$ (visually presenting 3-side equal spacing: left, top, bottom).
   - Top and bottom padding in standard 2-line state = $P$.
3. **Multi-Line Top-Pinned Alignment**:
   - In earlier implementations, cards used vertical center alignment (`alignment: .center`), which caused the icon and trailing buttons to drop down towards the vertical middle when paths or titles wrapped into multiple lines or when a task card rendered a 3rd-line progress bar or error message.
   - The new design establishes top alignment (`alignment: .top`) with top offset pinned at $P$, allowing the text and supplementary elements to expand downwards without shifting the icon container or action buttons.
4. **Cap-Height Optical Alignment**:
   - Default font line rendering carries internal half-leading above the cap height. By applying an optical top offset (`redesignTextCapOpticalOffset` = 2.5pt), the capital letter / Chinese character cap top line aligns with the physical top edge of the 40px icon container, ensuring the measured space between the glyph tops and the card border strictly equals $P$.

## What changed

- **WorkbenchControlMetrics & Redesign Tokens**:
  - In `WorkbenchControls.swift`:
    - Added `redesignCardIconContainerSize`: 40px (matches `redesignHeight`).
    - Added `redesignCardIconGlyphSize`: 24px (centered inside the 40px container).
    - Added `redesignTextCapOpticalOffset`: 2.5pt (optical adjustment aligning cap-height top to container top edge).
- **WorkbenchCardIcon Component**:
  - In `WorkbenchControls.swift`:
    - Created reusable `WorkbenchCardIcon` view with 40×40 continuous rounded rectangle, `--color-bg-hover` background fill, and centered `AppIconImage` using `--color-text-secondary`.
- **WorkbenchFileView**:
  - In `WorkbenchFileCard`:
    - Switched `HStack` alignment from `.center` to `.top`.
    - Replaced bare `AppIconImage` with `WorkbenchCardIcon(icon: icon)`.
    - Added `.alignmentGuide(.top) { d in d[.top] + WorkbenchControlMetrics.redesignTextCapOpticalOffset }` to the text `VStack`.
- **TaskPanel**:
  - In `TaskCardContainer`:
    - Switched `HStack` alignment from `.center` to `.top`.
  - In `TaskCurrentCard`:
    - Replaced bare `AppIconImage` with `WorkbenchCardIcon(icon: entry.record.icon)`.
    - Added `.alignmentGuide(.top)` cap optical offset to the text `VStack`.
  - In `TaskHistoryCard`:
    - Replaced bare `AppIconImage` with `WorkbenchCardIcon(icon: record.icon)`.
    - Added `.alignmentGuide(.top)` cap optical offset to the text `VStack`.
- **Tests**:
  - In `WorkbenchControlMetricsTests.swift`:
    - Added `cardIconContainerMetricsMatchDesignSpecification` test verifying `redesignCardIconContainerSize == 40`, `redesignCardIconGlyphSize == 24`, and `redesignTextCapOpticalOffset == 2.5`.

## Verification

- Built and ran tests:
  - `swift test --filter WorkbenchControlMetricsTests` passed with 6 tests.
  - Verified no regression on existing UI control metrics.
- Visual inspection via interactive prototype in private artifact directory confirmed equal $P$ margin on all sides and pinned top alignment for multi-line cards.
