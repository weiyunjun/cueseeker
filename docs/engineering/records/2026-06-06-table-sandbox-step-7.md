# Table Sandbox Step 7 — Phase B4: Real Data, Search Box, Playback Wiring

Human requirement:

- `docs/human/requirements/20260605-Feature-UI Redesign.md` (items 5, 6, 7, 11, 15)

## Scope

Phase B4 connects the sandbox table to real data and the production open entries.
Platform UI/UX + integration only; no new product semantics.

- `WorkbenchTestSearchView`: an in-page search field at the top of the Test
  Search page. On submit it calls `appState.submitTopbarSearch` (the existing
  search pipeline; it sets the panel to search but does not clear the test page,
  so the table stays visible). The table observes `SearchStore.searchResults`
  and maps each to a row: `name` = the contract alias
  (`SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath:)`, the production
  group-title source), `cues` = `subtitleDisplayLines(content:cueLines:)` joined
  by newline (identical to the production card derivation). Play calls
  `appState.openSearchResult` — the same entry as clicking a production search card.
- `WorkbenchTestShioriView`: no search field; the table observes
  `ShioriStore.shioris`, maps the same way, and Play calls `appState.openShiori`.
- First-screen rendering: the views observe the stores' `@Published` arrays, so
  rows render as results arrive (no extra lazy-loading layer), matching the
  requirement.
- Library test page stays blank.

Row identity maps back to the model by id (`entryID` / Shiori `id`) so Play
resolves the underlying result/entry.

## Notes

- `SubtitleTableSampleData` (the 80 fake rows) is no longer referenced. It was
  left in place (not deleted) and can be removed by the owner if unwanted.

## Verification

- `swift build --target CueSeekerApp` succeeded.
- End-to-end (owner): on Test Search, typing a query + Enter fills the table
  with real results that render as they stream in; Play opens/seeks like the
  production card; Test Shiori lists favorites and Play opens them. Selection,
  cmd+A/cmd+C, hover Play/Copy, and scrolling continue to work.

## Fix — Name uses the contract alias, not the file name

E2E showed the Name column using `videoName` (the file name) instead of the
display title shown in the production group header (e.g., "AVE MUJICA – 01").
Changed both tables to use
`SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath:)` (the same source
as the production group title; required `import CueSeekerCore`).

## Review fixes (Codex)

- Stale selection after a data refresh could crash on cmd+C: `update(rows:)`
  now clears `anchor`/`focus`/`hoveredRow` when rows change, and `cellFullText`
  guards against out-of-range rows.
- Test Search reached only the first page: per the owner's clarification (load
  all rows, render only the visible ones, Excel-style), the Search view now
  eagerly drives `loadMoreSearchResultsIfNeeded()` until `hasMoreSearchResults`
  is false, so the whole result set is in the table.
- Test Shiori could be empty when opened directly: it now calls
  `appState.hydrateShiorisAsync()` via `.task`, like the production Shiori panel.
- (Not changed) The `f111d5dd` revert commit message lacks the `docs/human/`
  path; the owner chose to leave it.

## Outcome

Build green. Phase B4 complete: the sandbox tables run on real Search/Shiori
data with the production playback entries and an in-page Search box; Name shows
the contract alias; all results load (visible-only rendering); Shiori
self-hydrates; stale-selection crash fixed.
