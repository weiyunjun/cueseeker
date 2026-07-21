# ADR 0014: Unified Cue Content And Shiori Relation Architecture

## Status

Accepted

## Context

Search and Shiori currently materialize overlapping content and presentation
models even though every current Shiori resolves to a valid CueID. Shiori also
stores subtitle, timing, path, and media snapshot fields that duplicate indexed
Cue data. This makes the two surfaces diverge and allows memory use to grow with
full row presentation objects instead of only the compact logical collection.

The accepted human requirement is
`docs/human/requirements/20260721-Feature-Search Shiori Unified Cue Architecture And Memory Optimization.md`.

## Decision

- CueID is the only content identity used by Search, Shiori, Context, and
  Playback Cue actions.
- One canonical in-memory Cue snapshot owns subtitle content, Cue Group
  presentation data, title, language, speaker, timing, subtitle path, and media
  resolution data for each loaded CueID.
- Search results are ordered CueID collections plus Search-owned query state.
- Shiori results are ordered relation collections. A Shiori relation owns only
  ShioriID, CueID, Shiori list identity, creation time, and relation-scoped Tags.
- The initial implementation creates and uses one default Shiori list. The data
  model permits the same CueID in different lists, but list-management UI,
  list switching, and multi-list interactions remain out of scope.
- A Cue may occur at most once in one Shiori list. The database enforces
  uniqueness on `(list_id, cue_id)` rather than globally on `cue_id`.
- Workbench and Playback observe the same authoritative Search and Shiori
  collections. Playback may retain temporary presentation state but not another
  complete Cue collection.
- Complete logical Cue and Shiori relation collections may remain resident.
  Row drawing, text layout, tag layout, hover state, native views, and any cache
  that retains complete row payloads remain limited to the viewport and the
  existing bounded preprocessing range. Compact scalar row-height data may
  remain outside that range to preserve stable scrollbar geometry.

## Rationale

Separating content identity from relation identity preserves future multi-list
semantics without duplicating Cue content. Keeping the logical collection
resident preserves immediate arbitrary scrollbar jumps, while bounding only
presentation resources addresses memory growth without reintroducing database
waits or sparse data windows.

## Tradeoffs

- Shiori row construction becomes a projection of a relation and canonical Cue
  instead of a self-contained stored row.
- The schema migration removes the historical Shiori content snapshot contract;
  current data must have a valid CueID before migration.
- Table code must distinguish lightweight persistent geometry from heavyweight
  presentation payloads.
- Multi-list persistence is established before multi-list product controls are
  implemented.

## Alternatives Considered

- Keep full Shiori snapshot rows and only tune allocations. Rejected because it
  preserves two content authorities and cannot guarantee Search/Shiori
  consistency.
- Load only visible Shiori data. Rejected because arbitrary scrollbar jumps
  must be immediate and must not wait for database hydration.
- Use CueID as both content and Shiori relation identity. Rejected because the
  same Cue may belong to multiple future lists with different relation metadata.

