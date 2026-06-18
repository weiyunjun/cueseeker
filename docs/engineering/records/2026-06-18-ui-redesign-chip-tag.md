# Engineering Record: UI Redesign - Chip / Tag (Section 2.22)

## 1. Covering Human-Owned Requirement

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## 2. Scope

This record covers the implementation of Section 2.22 Chip / Tag for the
Search 2 redesign table.

The work is intentionally limited to Speaker and Language tags rendered inside
table rows:

- Apply the redesign chip colors for Speaker and Language tags.
- Apply the redesign chip radius and padding tokens.
- Support the disabled visual state.
- Preserve the tags as display-only elements with default cursor behavior.
- Preserve the existing virtualized AppKit table rendering path.

## 3. Implementation Summary

- Added a `SubtitleTableTagStyle` helper that resolves the table tag metrics
  for redesign and legacy paths.
- The redesign path now uses 10 px horizontal padding, 4 px vertical padding,
  6 px corner radius, and fit-content chip height based on the rendered text.
- The legacy path keeps its existing fixed 22 px chip height and 8 px
  horizontal padding.
- Disabled redesign tags now use `--color-bg-disabled` and
  `--color-text-disabled`.
- Speaker and Language tags continue to use `WorkbenchTagColorID` semantic
  mapping: Speaker is `.purple`, Language is `.blue`.

## 4. Virtualization Constraints Preserved

- No per-row SwiftUI tag views or `NSHostingView`s were introduced.
- Tag drawing remains inside the existing AppKit row draw pass for visible
  rows only.
- No row data scanning, row measurement pass, or materialization of unloaded
  rows was added.
- `rowHeightCache`, `visibleRowRange(in:)`, and row hydration boundaries were
  not changed.

## 5. Verification

Commands run from `apps/macos-native/`:

```text
swift test --quiet
```

Result:

- 299 tests passed after the Chip / Tag implementation.
- The command also printed an existing playback history disk I/O warning, but
  the test run completed successfully.

Focused coverage added:

- Redesign chip style uses 10 px horizontal padding, 4 px vertical padding,
  6 px radius, and fit-content height.
- Disabled redesign chips use disabled background and text tokens.
- Speaker and Language tags map to the expected redesign semantic chip colors.

## 6. Outcome

Section 2.22 now renders Speaker and Language chips using the redesign token
set while keeping the virtualized AppKit table path intact.
