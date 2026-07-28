# Empty Facet Selection Semantics

## Human-Owned Source

- `docs/human/requirements/20260728-Feature-Search Shiori Secondary Views And Table UI Refinement.md`

## Scope

Make an empty selection mean that a data card does not restrict results, while
keeping an explicitly selected subset and an explicitly selected complete set
as their own persisted checkbox states.

## Classification

- Empty, partial, and complete selection matching are shared product semantics
  in `CueSeekerCore`.
- Search and per-List Shiori restoration remain local preference persistence in
  `SettingsStore`.
- The shared SwiftUI card component continues to render the selected sets
  directly and does not normalize their appearance.

## Implementation

- Changed `CueFacetFilter` to start with four empty selected sets.
- Treated an empty set as unrestricted independently for every card; partial
  sets still use OR within a card and AND between cards, while complete sets
  remain unrestricted through normal membership matching.
- Removed the snapshot projection shortcut that previously returned zero rows
  when any card was empty.
- Returned the empty default only when Search or a Shiori List has no persisted
  record. Existing saved exclusion records still restore the exact selected
  sets they represent, including empty and complete sets as distinct states.
- Updated shared-core, Search, and Settings tests for the revised default and
  the transition from one checked option back to no checked options.

## Verification

- The focused facet, persistence, Search projection, Shiori projection, and UI
  refresh-scope run passed all 19 tests.
- The complete `swift test` run executed 910 tests and reported 17 issues in
  nine existing native playback, Subtitle Focus, Library removal, and UI probe
  timing tests. Every affected test passed when rerun individually, confirming
  full-suite concurrency instability rather than a facet-semantics regression.
- `git diff --check` passed.
- `docs/human/design/UI.md` was not modified or staged by the AI.

## Outcome

Search and every Shiori List now start with no checked facet options when no
saved state exists. An empty card and a completely checked card both leave that
card unrestricted, while their distinct checkbox states persist and restore
without normalization.
