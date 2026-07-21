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
- Full 799-test regression run completed. All requirement-focused, database,
  Search, Shiori, Playback integration, table interaction, Cue Group reflow,
  and presentation-cache tests passed. Three unrelated native-media or
  temporary-database timing tests that timed out under the full run each passed
  immediately when rerun in isolation.

## Outcome

Implemented. End-to-end product and memory acceptance remains with the user.

## Follow-ups

- Multi-list UI, list management, and list switching remain a separate future
  requirement.
