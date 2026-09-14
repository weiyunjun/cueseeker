# Bug: Filter dialog opening, lag and the 100-row filtered result

Human-owned documents:

- `docs/human/requirements/20260915-Bug-Filter Dialog Opening Lag And Filtered Result Limited To 100 Rows.md`
- `docs/human/design/UI Design System.md` (Filter Dialog Layout, Search / Excerpt Table Layout; no change)

## Starting point (`ebd69b49`)

Observed in the App through the Debug E2E controller, live library, no filter selected:

- `の` pasted and the filter button clicked once while the search ran: 0.4 s later no dialog was drawn and the button showed only its hover state; the dialog appeared about 2 s later, when the search completed, without a second click. A capture sent right after the click took 2.2 s to return, and the main thread stalled for 296 ms and 832 ms during the search.
- The exact scan published its rows to the table every candidate batch (about every 5,000 hits, 14 times for `の`), and every publish changed the Search store, which the Filter dialog observed as a whole, so the open dialog was rebuilt on each one although nothing it shows had changed.
- After every count was complete, a changed selection installed only the first 100 rows. The table's row count is the number of loaded rows and the Search page has no later-page loading (Step 7's record said later pages load as before; corrected there).

## What changed

- Requirement 4.1: the exact scan still reports its rows batch by batch, but on its own thread into a holder that is read only when the scan returns; the completed result installs those rows and its page's tail in one change. A search therefore hands the table two updates, the first page and the rest. The progress path that published each batch (`applyCountProgress`, `commitSearchCountProgress`, `writeE2ECountProgress`, the `search_count_progress` log event) is removed, and merging loaded rows no longer takes cue IDs.
- Requirement 4.2 and 4.3: after every count is complete, a changed selection sets the selection and a new result list generation at once, reads by cue ID only the rows whose contents are not in memory (5,000 per read), then installs every row, the total and the counts in one change. The table keeps the previous list until then. While counts are incomplete, Show still searches again.
- Requirement 3: the Filter dialog over Search no longer observes the Search store. It holds what it shows (counts, total, calculating state, the complete snapshot once every count is known, available languages) and replaces it only when a store change alters that value, so the search's rows do not redraw it. Checking an option still redraws it at once. The dialog body counts `UI.FilterDialog.body` for the UI probe.
- Requirement 2 needed no separate change: once the main thread is no longer taken by per-batch publishing, the first click draws the dialog at once.

The Core scan and its progress API are unchanged; the App was their only user of per-batch rows.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore+Execution.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/SearchPerformanceLogger.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/SearchStoreTests.swift`
- `docs/engineering/records/2026-09-14-search-filter-first-execution-step-7-projection-after-complete-counts.md`
- `docs/changelog.md`

## Verification

- Unit tests: the projection tests now check that nothing is installed while a row's contents are missing and that the whole result (rows, ranks, total, counts) arrives in one change; the real-database test expects all 150 rows after clearing a one-card selection and after a two-card search; the completion test checks that reported rows and the page tail are installed with one revision. The two tests of per-batch publishing are removed.
- `swift test --filter 'SearchStoreTests|SettingsStoreSearchTests|PlaybackPlaylistSourceTests|PlaybackSearchOverlayTests|CueGroupRefreshScope'`: 70 tests, 2 issues, both in the environment-sensitive Excerpt scroll anchor pair (`showCueGroupInvalidationIsScopedToMountedExcerpt`, `excerptTableStartsAtTopAfterPanelRemount`) listed by the earlier records.
- Full `swift test`: 1230 tests, 28 issues in 14 tests: native playback (6), Debug E2E scene and width (2), Excerpt scroll anchor (2), Library folder removal (3) and `progressiveSearchProjectionRefreshesOnlyMountedTable`. The Library folder removal suite, the progressive projection test and `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks` pass when run alone (8 tests); the rest are the environment-sensitive set of the earlier records.
- App, Debug E2E controller, live library, 1445 × 821, UI probe and stall probes on:
  - No filter, `の` pasted and the filter button clicked 0.5 s later: the click returned in 0.3 s and the capture right after it showed the dialog with grey counts, the Spinner, `Calculating` and `Show results`. `UI.FilterDialog.body` counted 1 at the click and 1 more at completion; `table.search.snapshot_rebuild` counted 2 (first page, then 77,145 rows). No stall during the search.
  - Warm repeat of `の`, dialog closed: first page 164 ms, complete 2,796 ms (database 2,145 ms, installing the rows 273 ms), against 3,404 ms (database 2,185 ms, 81 ms) before; one main-thread stall of 476 ms at completion instead of the earlier stalls during the search. The first `の` after launch is cold on both builds (5.6 s now, 5.9 s before).
  - Narrowing after complete counts: `31+` and Show gave 2,766 results in 45 ms with no stall; the table scrolled to row 2,766.
  - Widening: relaunched with `31+` saved, `の` gave 2,766 rows in two table updates; after the counts completed, Reset and Show read 74,379 rows by cue ID and installed 77,145 rows in 1,624 ms (reads 1,557 ms) with one 251 ms run-loop gap, in one table update; the table scrolled past row 10,066.
- Animation smoothness has no automated measure; the stall probes above stand in for it, and the look is left to manual acceptance.

## Outcome

Implemented and verified as above. The saved Search selection was left empty.
