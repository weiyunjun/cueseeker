# Split View Minimum Window Width

## Human-Owned Source

- `docs/human/requirements/20260705-Bug-Split View Minimum Window Width.md`
- `docs/human/design/UI.md`

## Scope

Lower the macOS app minimum window width so CueSeeker can participate in
standard macOS Split View tiling, and collapse the app sidebar once when the
window becomes too narrow for the sidebar plus the minimum Cues table column.

## Classification

- Product semantics: unchanged; Search, Shiori, Library, and playback command
  meanings are unchanged.
- Platform UI/UX: main-window minimum width and compact sidebar behavior are
  updated.
- Platform integration: AppKit window resizing now permits a 480pt minimum
  width.
- Playback execution: unchanged.

## Changes

- Reduced the main app shell minimum width from 1000pt to 480pt.
- Kept the default window creation width at 1000pt so the reduced minimum width
  does not make the initial window artificially narrow.
- Added a 760pt sidebar auto-collapse threshold based on the documented 240pt
  sidebar width plus the documented 520pt Cues minimum column width.
- Collapsed the sidebar once when the root workbench width is greater than zero
  and less than or equal to the threshold.
- Preserved the collapsed sidebar state so widening the window does not
  automatically reopen it.
- Added Workbench layout tests for one-time compact sidebar collapse and for
  ignoring nonpositive transient layout widths.
- Confirmed the existing table column constants already match the human-owned
  table requirements: Selection 50pt, Display Title 240pt, Cues minimum 520pt,
  Time 190pt, and Date Added 160pt.

## Verification

- `git diff --check`
- `swift test` from `apps/macos-native`

## Outcome

Passed. The main app can now be constrained to a 480pt minimum width, and the
sidebar collapses once when the workbench width is at or below 760pt without
auto-expanding when the window widens again.
