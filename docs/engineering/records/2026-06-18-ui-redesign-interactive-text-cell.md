# Engineering Record: UI Redesign - Interactive Text Cell (Section 2.20)

## 1. Covering Human-Owned Requirement

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## 2. Scope

This record covers the implementation of Section 2.20 Interactive Text Cell for
the Search 2 redesign table.

The work is intentionally limited to the Cues column body text:

- Show an underline only while the pointer is over the actual Cues text.
- Use a stable underline thickness and offset.
- Change the pointer to a pointing hand while hovering interactive text.
- Play the matching row when the Cues text is clicked.
- Preserve row hover styling, row action buttons, row selection checkboxes, and
  virtualized table rendering.

## 3. Implementation Summary

- Extended the existing TextKit-backed `SubtitleTextLayout` helper with line
  fragment hit testing and underline rectangle calculation.
- Implemented underline drawing as a CSS-like text decoration layer instead of
  relying on system attributed-string underlines. The underline uses the
  requirement's fixed thickness and offset, and its Y coordinate is aligned to
  the backing scale so the rendered line does not appear to change thickness.
- Draw order is underline first, text second. This allows descenders and dense
  glyphs to visually cover parts of the underline, matching common browser
  behavior, while keeping the underline geometry itself consistent.
- Added a separate hovered Cues text row state. Row hover remains active across
  the full row, while underline and pointer state apply only when the pointer is
  over actual Cues text line fragments.
- Cues text clicks call the existing row playback path. Checkbox and row action
  interactions remain separate because they are handled before or outside the
  text hit region.

## 4. Virtualization Constraints Preserved

- No per-row SwiftUI text views or `NSHostingView`s were introduced.
- Text drawing and underline drawing remain inside the existing AppKit
  viewport-bound row draw pass.
- Text hit testing reuses the same TextKit layout helper and only runs for the
  hovered or clicked row.
- `rowHeightCache`, `visibleRowRange(in:)`, and row hydration boundaries were
  not changed.

## 5. Verification

Commands run from `apps/macos-native/`:

```text
swift test --quiet
```

Result:

- 293 tests passed after the Interactive Text Cell implementation.
- The command also printed an existing playback history disk I/O warning, but
  the test run completed successfully.

Focused coverage added:

- Underline rectangles use the fixed requested thickness.
- Underline Y positions are aligned to the backing scale.
- Text hit testing uses actual line fragments rather than the full Cues cell.
- Cues text hit testing rejects trailing whitespace in the table cell.

## 6. Outcome

Section 2.20 now supports Cues text hover and click interaction while preserving
the virtualized AppKit table path and keeping underline thickness visually
stable.
