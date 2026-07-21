# Search And Shiori Unified Cue Architecture

## Requirement

- `docs/human/requirements/20260721-Feature-Search Shiori Unified Cue Architecture And Memory Optimization.md`

## Scope

Unify Search and Shiori around one CueID-keyed content source, reduce Shiori to
relation-owned data, establish default-list persistence for a future multi-list
feature, preserve complete in-memory logical results, and bound heavyweight
table presentation resources.

## Steps

1. Accepted ADR-0014 and documented the unified content, relation, residency,
   and presentation-resource ownership rules.
2. Migrated schema version 32 to `shiori_lists` plus relation-only `shioris`
   rows. The default list is active, `(list_id, cue_id)` is unique, Tags remain
   keyed by ShioriID, and resolved playback values now join the current Cue.
3. Added a canonical `CueContent` domain value, ordered bulk CueID resolution,
   and one AppCoordinator-owned Cue content store.
4. Replaced Shiori's paged database hydration with one complete resident
   relation/Cue/Tag snapshot. Shiori search and filters now project ordered
   relations from memory, arbitrary row access no longer queries SQLite, and
   table rows are projected on demand without retaining a full materialized row
   collection.
5. Changed Search's durable result ownership to ordered CueIDs plus ranks. The
   Search store and Workbench table now resolve current values through the same
   AppCoordinator Cue content store used by Shiori, and table rows are projected
   lazily from CueIDs instead of retaining a second complete row collection.
6. Removed the legacy resident `[Shiori]` and file-group presentation dataset.
   Playback database order, explicit scopes, adjacent navigation, Context, and
   row actions now resolve Shiori relations through the canonical Cue store;
   the obsolete card-surface hydration path no longer runs after mutations.
7. Preserved Search and Shiori table controls, selection, and CueID/ShioriID
   viewport anchors independently in their surface stores. Switching surfaces
   now remounts against the resident logical snapshots, restores the same entry
   when it still exists, and falls back to the nearest preceding position when
   filtering removed it.
8. Bounded the dynamic-row measurement cache to the visible viewport plus the
   existing measurement overscan. Complete row payloads, Cue Group strings, and
   Tags now leave the cache when their rows leave that range; compact scalar
   row heights remain available for stable scrollbar geometry.
9. Corrected subtitle rebuild semantics so source-matched Cues remap existing
   Shiori relations inside the rebuild transaction. ShioriID, list membership,
   creation time, and tag assignments survive Cue content changes; only source
   Cue identities that disappear are allowed to cascade away.
10. Added one indexed-content mutation lifecycle for Shiori. Indexing and
    folder removal now cancel obsolete Shiori reads, invalidate resident
    relations and table rows, remove affected canonical Cue content, and reload
    the complete surviving Shiori snapshot after the database mutation ends
    when that snapshot was resident or loading before the mutation. An unloaded
    Shiori surface remains unloaded until first use and starts no redundant
    post-mutation database read.
11. Added canonical Cue content revision ownership to lazy Search and Shiori
    table snapshots. A content change now advances the table snapshot version
    and emits a reload even when CueIDs, ranks, relations, and Tags are stable,
    which invalidates native drawing and dynamic-row measurement caches.
12. Moved the Search table projection into a Search-store-owned persistent row
    store. Search remounts now reuse the resident CueID/rank containers and a
    scalar source revision instead of reading and reconstructing the complete
    `SubtitleSearchResult` collection; shared Cue-content revision changes still
    force a table reload independently of the Search source revision.
13. Closed the canonical Cue-content notification chain. The Cue content store
    now publishes committed changes with their affected CueIDs; the long-lived
    Search and Shiori stores subscribe directly and reload only resident table
    projections that reference those CueIDs. Result identity revisions remain
    independent from content revisions, and table refresh no longer depends on
    a SwiftUI metadata change or a manual row-store update.

## Verification

- Documentation cross-check against the committed human requirement: passed.
- Shiori database and playback-navigation focused tests: passed.
- Valid-Cue migration, default-list relation, cross-list identity, tag, filter,
  ordering, and indexed-folder removal coverage: passed.
- Canonical Cue bulk-resolution and single-value-per-CueID store tests: passed.
- Resident Shiori snapshot and 10,000-relation lazy row projection tests: passed.
- Canonical Search ownership and 10,000-Cue lazy row projection tests: passed.
- Independent viewport-anchor and Shiori remount-state tests: passed.
- Dynamic-row presentation-cache range and 50,000-row repeated-jump coverage:
  passed.
- Shiori rebuild remapping with changed Cue content and preserved Tags: passed.
- Folder removal resident-Shiori, table-row, and canonical-Cue invalidation:
  passed.
- Folder removal without a prior resident Shiori snapshot starts no redundant
  post-mutation Shiori read: passed.
- Same-CueID Search and Shiori content replacement invalidation: passed.
- Search remount with 10,000 resident Cue references preserves one row store,
  performs no row materialization, and keeps the table snapshot version stable:
  passed.
- Canonical content replacement automatically advances both Search and Shiori
  table snapshot versions through the store notification chain, without a
  manual row-store update: passed.
- Final full 804-test regression run completed. All requirement-focused,
  database, Search, Shiori, Playback integration, table interaction, Cue Group
  reflow, and presentation-cache tests passed. Ten native-media, MainActor, or
  temporary-database timing tests failed under the full parallel load with 17
  issues. Every failed test passed immediately in isolation: Library folder
  removal 6/6, native playback timeline 5/5, Subtitle Focus Shiori 2/2,
  playlist copy/Shiori 1/1, and Recent pointer dispatch 1/1.

## Outcome

Implemented. End-to-end product and memory acceptance remains with the user.

## Follow-ups

- Multi-list UI, list management, and list switching remain a separate future
  requirement.
