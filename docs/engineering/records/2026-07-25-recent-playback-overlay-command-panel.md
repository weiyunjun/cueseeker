# Recent, Playback Overlay, And Command Panel

## Human-Owned Source

- `docs/human/requirements/20260725-Feature-Recent Playback Overlay And Command Panel.md`
- `docs/human/design/UI.md`

## Scope

Implement the accepted Recent navigation, Recent Shiori recovery, simplified
Playback Overlay, and Playback Command Panel in small, independently verified
steps. Reuse existing feature stores, database boundaries, playlist sources,
and presentation components without adding parallel state sources or
speculative abstractions.

## Architecture Alignment

- Removed the obsolete single-default-list limitation from the Shiori data
  ownership rules.
- Kept Shiori relation ownership on the existing multi-list persistence and
  presentation paths.

## Architecture Verification

- Confirmed the replacement matches the committed multi-list implementation
  and the current human-owned requirement.
- `git diff --check` passed.

## Step 1: Recent Shiori Recovery

- Extended the existing `shiori_lists` rows with the last played Cue anchor,
  fixed current list order, and playback timestamp; no new table or cache was
  introduced.
- Recorded Recent Shiori state only after the existing Shiori playback entry
  successfully opens or seeks the player.
- Rebuilt Recent Shiori entries from the current contents of their original
  list, resumed a valid saved anchor, fell back to the first playable item, and
  cleared only the Recent entry when no playable item remained.
- Reused `ShioriList`, `ShioriListSummary`, and `ShioriDatabase`; no parallel
  store, repository, protocol, or state source was added.

## Step 1 Verification

- Schema 33 and schema 37 migration coverage passed.
- Fresh schema and unsupported-newer-schema coverage passed.
- Recent Shiori anchor, fallback, and empty-list removal coverage passed.
- All 72 tests selected by the `Shiori` filter passed.
- The native application and test targets compiled successfully as part of the
  focused test run.
- The result matched the accepted recovery behavior and the estimated file
  scope.

## Step 2: Workbench Sidebar And Recent

- Added Recent and Shiori child navigation inside the existing Workbench route
  and Sidebar views; disclosure state remains local to the Sidebar and no
  second navigation store was introduced.
- Reused the existing five-item Recent Videos source for the overview and the
  existing complete Recent Videos source for the detail page.
- Loaded Recent Shiori summaries through the existing Shiori overview task and
  retained them in the existing `ShioriStore`; no additional task lifecycle or
  store was added.
- Added the Recent overview, complete Recent Videos, and complete Recent
  Shioris layouts while reusing the existing video grid, list cover, and
  playback entry points.
- Opened Recent Shiori playback with the original list's current valid item
  order through the existing explicit Shiori playlist scope.

## Step 2 Verification

- The native application and test targets compiled successfully.
- Workbench Recent section routing coverage passed.
- Shiori overview loading coverage passed with Recent Shiori installation.
- All 104 tests selected by the `Workbench|Shiori` filter passed.
- The two focused route and combined-loading tests passed again after limiting
  Recent refresh to entry and playback return instead of every Cue change.
- The result matched the accepted navigation, Recent layout, data reuse, and
  original-list recovery scope.
