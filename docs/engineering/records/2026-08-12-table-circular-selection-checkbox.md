# Table Circular Selection Checkbox Implementation Record

Status: Implementation Complete; Visual Acceptance Pending

## Authority

- `docs/human/requirements/20260812-Feature-Table Circular Selection Checkbox.md`
- `docs/human/design/UI Design System.md`, section `2.2 Selection Controls`
- Project-owner direction to validate the Swift implementation before
  stabilizing the human-owned UI design document.

## Classification

Platform UI/UX. Product semantics, platform integration, and playback
execution are unchanged.

## Baseline

- Starting commit: `9f1882c`
- Branch: `main`

## Implementation

- Added one shared Checkbox definition for state-to-symbol and state-to-color
  mapping.
- Standardized Unchecked, Checked, and Indeterminate on `circle`,
  `checkmark.circle.fill`, and `minus.circle.fill` respectively.
- Kept Filter on its existing SwiftUI SF Symbol rendering and Playback on its
  existing AppKit monochrome SF Symbol rendering.
- Replaced Table's separate background, border, checkmark, and minus drawing
  with the same shared SF Symbols. Table keyboard focus retains its circular
  outer ring.
- Assigned the shared checked Checkbox token the existing Filter and Playback
  gray values, so those variants retain their previous appearance and Table
  uses the same control color.
- Kept Filter and Table at 16 points and Playback at 24 points. Hit areas,
  calculating behavior, focus behavior, keyboard handling, selection behavior,
  and disabled conditions remain unchanged.
- Corrected the Table row/header visual-size mismatch without changing the
  Checkbox style: AppKit now requests the same explicit 16-point symbol as the
  SwiftUI header and centers the symbol's intrinsic canvas instead of scaling
  that canvas into a 16-point rectangle. Playback applies the same sizing rule
  at its existing 24-point size.

## Verification

- Focused shared-symbol, color, size, and monochrome tests: 4 passed.
- Focused Checkbox and selection regression tests: 28 passed.
- Complete Swift test run: 982 Swift Testing tests and 8 XCTest tests passed
  with zero failures. The established shared-persistence migration test was
  skipped by its standard command.
- Source inspection confirms the previous Table-only checkmark and
  indeterminate drawing paths were removed.

## Outcome

All three Checkbox variants now share the same system-symbol geometry and state
colors. The Table header and rows also render the same visible 16-point symbol;
Playback remains 24 points. Only the documented size and existing interaction
differences remain. Human visual acceptance is still required before the stable
UI design document is updated.

## Follow-ups

- After visual acceptance, the human owner should update
  `docs/human/design/UI Design System.md` with the verified checked color,
  system-symbol rendering, and indeterminate mapping.
