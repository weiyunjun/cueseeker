# UI Refresh Scope Contract

## Human-Owned Source

- `docs/human/requirements/20260708-Bug-UI Refresh Scope Contract.md`
- `docs/human/design/UI.md`

## Scope

Apply the accepted refresh-scope contract to the most visible playback and
table invalidation paths so covered workbench surfaces do not redraw or hydrate
rows during playback, and table parent refreshes do not automatically become
full document redraws.

## Changes

- Changed the subtitle table AppKit bridge to diff row, column, header,
  selection, scroll, and callback-only updates separately.
- Limited callback-only `SubtitleTableView` updates so they refresh stored
  closures without marking the header or document view for redraw.
- Limited appended table rows to appended-row invalidation while preserving
  full document redraw for explicit row reloads.
- Suppressed visible-row hydration notifications while an external workbench
  popup layer, including playback, covers the table.
- Changed external-layer hover clearing to invalidate only the affected table
  rows instead of the full document.
- Added Search and Shiori table response gates so covered tables defer row
  snapshot refresh and continuous hydration until playback is no longer
  visible.
- Split playback Quick Search into a visible-only host so `PlaybackPageView`
  does not subscribe to `SearchStore` while the Quick Search overlay is hidden.
- Added regression coverage for callback-only table updates and covered-table
  visible-row notification suppression.

## Verification

- `git diff --check`
- `swift test --filter subtitleTableViewDoesNotRedrawForCallbackOnlyUpdates`
- `swift test --filter subtitleTableViewSuppressesVisibleRowNotificationsWhenExternalLayerIsOpen`
- `swift test --filter SubtitleTableVirtualRow`
- `swift test --filter PlaybackQuickSearch`
- `swift test --filter PlaybackNavigation`
- `swift test` (XCTest 7 tests, Swift Testing 404 tests)

## Outcome

The workbench table now treats rendering ownership as an explicit update
boundary: parent SwiftUI refreshes can update callbacks without forcing the
table document to redraw, row appends invalidate appended rows only, and covered
tables do not drive row hydration while playback is visible. Playback also no
longer depends on `SearchStore` updates unless the Quick Search overlay is
actually mounted.
