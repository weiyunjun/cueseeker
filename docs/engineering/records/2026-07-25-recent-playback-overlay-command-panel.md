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

## Step 3: Playback Overlay And Command Panel

- Reduced the production Playback Overlay to the existing Current and
  Playlist session views, replaced the module Sidebar with centered tabs, and
  kept the old feature modules available only to their explicit compatibility
  tests.
- Reused the existing Subtitle Focus Reel for Current and the existing
  Playlist Reel for subtitle playlists.
- Added the fixed Current video context from the existing Library
  presentation: the context occupies 20 percent of the content width, keeps
  one cover without playback progress, and does not change with Cue
  navigation.
- Added Command Panel presentation state to the existing `PlaybackStore`
  instead of creating another observable store.
- Reused the existing `SearchStore`, search task, Recent Videos projection,
  Recent Shiori summaries, cover loader, video-card visual elements, Shiori
  row, clipboard behavior, and playback entry points.
- Limited only the Command Panel Search Result projection to the first 50
  resident results. Opening a result promotes the existing complete Search
  playlist source rather than copying the 50-item projection.
- Implemented root Search/Recent navigation, Search Result, Recent Videos,
  Recent Shioris, full-row selection, Footer counts, and S/X/C/Enter search
  actions without a table, virtualized result store, cache, or second search
  lifecycle.
- Routed playback-active URL Scheme searches to the same Command Panel Search
  Result path while retaining the existing direct-play and Workbench fallback
  rules.
- Preserved an underlying Playback Overlay while Command Panel is open and
  resumed playback only after the last playback modal closes.

## Step 3 Verification

- `swift build` passed.
- All four focused Command Panel keyboard and modal-layer tests passed.
- All 15 focused legacy Library, Recent, Shiori, and URL fallback compatibility
  tests passed.
- The Playback/URLScheme selection ran 310 tests; all 309 functional and
  feature tests passed. The one parallel native-audio timing failure passed
  immediately when rerun alone.
- `git diff --check` passed.

## Step 4: Source-Specific Playlist Reuse

- Reused the existing Recent Videos and Library Overlay session stores as the
  Playlist content for Library playback; no second media list, repository, or
  selection state was introduced.
- Reused the existing complete Search and Shiori playlist window for subtitle
  playback. The 50-result Command Panel projection remains presentation-only
  and does not limit the opened Playlist.
- Reused the existing Library presentation lookup for the selected Playlist
  item's cover and metadata. The lookup runs only after the selected item
  changes, and the cover view releases its decoded image when it disappears.
- Kept Current bound to its immutable open snapshot, so Cue movement does not
  resolve or rerender its video presentation.
- Added a defaulted title-visibility option to the existing Library detail
  header and disabled only its title in the Playback Playlist.
- Reused the existing session invalidation path to release Recent, Library, and
  subtitle Playlist windows when playback source changes or the Overlay closes.
- Kept S, X, C, and Enter on Command Panel Search Result through the existing
  playback action paths.

## Step 4 Verification

- The focused Command Panel S action test passed.
- The focused media Playlist opening and keyboard-routing tests passed.
- The focused Playlist, Command Panel, Recent, and Library selection ran 19
  tests successfully.
- The Playback/URLScheme selection ran 314 tests. Its three parallel timing or
  temporary-database failures each passed when rerun alone; all feature tests
  introduced or changed by this step passed in the combined run.
