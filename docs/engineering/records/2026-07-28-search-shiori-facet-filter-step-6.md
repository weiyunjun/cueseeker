# Search And Shiori Facet Filter Step 6

## Human-Owned Source

- `docs/human/requirements/20260728-Feature-Search Shiori Secondary Views And Table UI Refinement.md`

## Scope

Give each Shiori secondary page the same facet definitions and filtering
algorithm as Search, limit its distribution to the current Shiori List, and
persist selections independently for Search and every Shiori List. This step
does not change the Shiori interface.

## Classification

- Product facet semantics and Shiori snapshot data: `CueSeekerCore`.
- Per-page local preference persistence: `SettingsStore`.
- Snapshot lifecycle coordination: `ShioriStore` and `AppCoordinator`.
- Platform UI/UX and playback execution: unchanged.

## Implementation

- Renamed the Search-specific facet snapshot type to the shared
  `CueFacetSnapshot` and kept Search on the same implementation.
- Added the current List's exact facet snapshot to `ShioriResidentSnapshot`.
  Duration, Character, Language, and Watch Status use the same classifications
  and matching algorithm as Search.
- Included unavailable Shiori rows in the List distribution by using their
  stored Cue data, Unknown language, and Unwatched fallback when current
  indexed metadata is unavailable.
- Stored the resident Shiori facet snapshot in `ShioriStore` and exposed its
  ordered ShioriID projection for the later UI integration step.
- Updated the resident snapshot immediately when a Shiori is removed or moved
  out of the current List.
- Rebuilt a loaded Shiori resident snapshot after Watch Status changes through
  the existing Library history publication path.
- Persisted Shiori facet exclusions under each Shiori List ID. Search retains
  its independent key; unknown future values are ignored and therefore new
  available enum values remain selected by default.

## Verification

- `swift test --filter CueFacetFilterTests` passed all 9 shared facet tests.
- `swift test --filter ShioriDatabaseTests` passed all 15 tests, including
  current-List distribution isolation and Watch Status classification.
- `swift test --filter SettingsStoreSearchTests` passed all 11 tests, including
  Search/Shiori isolation, per-List restoration, default-all behavior, and
  forward compatibility.
- The combined Search, Settings, and Shiori Store regression run passed every
  Search and Settings test. Its added Shiori removal assertion initially
  exposed that the fixture had no active List; after correcting the fixture,
  `swift test --filter shioriStoreExcludesUnavailableRowsOnlyFromPlaybackScope`
  passed and verified immediate snapshot removal.
- The complete `swift test` run executed 906 tests and reported 19 issues in
  shared-persistence migration, Library removal timing, UI probe timing, row
  menu timing, Subtitle Focus timing, and native playback timing. All 11
  affected tests passed when rerun individually, confirming the known
  concurrent full-suite instability rather than a Step 6 regression.
- `docs/human/design/UI.md` was not modified or staged by the AI.

## Outcome

Shiori now owns one exact facet distribution for its active List and can
project ordered Shiori IDs through the same filter semantics as Search. Search
and every Shiori List restore independent exclusion-based selections, while
List mutations and Watch Status changes keep the corresponding resident
snapshot current. The Shiori UI remains unchanged for Step 7.
