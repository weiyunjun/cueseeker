# Database Freelist Strategy Discovery

Status: Active

Date: 2026-05-14

## Context

The user explicitly started a Socratic architecture alignment session for the
database area. The user began from limited knowledge of the current database
architecture and asked narrow follow-up questions to build an understanding of
where database size and optimization risks may come from.

This chronicle records why the database compaction and freelist strategy topic
emerged. It does not define the final implementation.

## Question Path

The session narrowed through these steps:

1. The user asked what a small ASS file stores during indexing when it does not
   produce ASS render segments.
2. The answer identified the ordinary indexed projection: subtitle file rows,
   video file rows, subtitle-video matches, cue groups, cue lines, FTS rows,
   and Library presentation rows.
3. The user requested a concrete example using
   `/Volumes/Seagate/影视/胜者即是正义/胜者即是正义01.ass`, which exposed how one
   bilingual ASS moment becomes one cue group with multiple cue lines.
4. The user then asked why the database is still large if it only stores these
   projections plus segments.
5. Database statistics showed that indexed subtitle files total about
   `129.32 MiB`, while the SQLite main file is about `842.58 MiB`.
6. The same statistics showed about `529.95 MiB` in SQLite freelist pages, with
   about `312.63 MiB` estimated active use.
7. Follow-up questions clarified that freelist pages occupy disk space, do not
   directly slow keyword search, and usually come from historical deletion or
   rebuild work that SQLite keeps for reuse.
8. The user asked how mature projects handle this and why CueSeeker does not
   yet do so.

## Evidence Surfaced

- Current database path:
  `~/Library/Application Support/CueSeeker/CueSeeker.sqlite`.
- Current schema version: `11`.
- Indexed subtitle files:
  - ASS: `78` files, `132999925` bytes.
  - SRT: `41` files, `2598571` bytes.
  - Total indexed subtitle source size: `135598496` bytes.
- SQLite file and page data:
  - Main file: `883511296` bytes.
  - Page size: `4096`.
  - Page count: `215701`.
  - Freelist count: `135668`.
  - Freelist bytes: `555696128`.
  - Used estimate: `327815168` bytes.
- Active logical database footprint from `dbstat`:
  - Cue groups and lines: `136007680` bytes.
  - ASS render segments: `134299648` bytes.
  - FTS: `57126912` bytes.
- SQLite connection configuration currently sets WAL, synchronous mode,
  foreign keys, cache size, and mmap size, but does not define `VACUUM`,
  `auto_vacuum`, incremental vacuum, or a user-facing database compaction
  workflow.
- Current database reports `auto_vacuum = 0`.
- A copied database compacted with WAL checkpoint plus `VACUUM` shrank from
  `883511296` bytes to `325963776` bytes in about `2.2` seconds on the test
  machine, and `PRAGMA integrity_check` reported `ok`.

## Emerging Insight

The database size concern is not only about how much active subtitle data
CueSeeker stores. A large share of current disk usage is inactive SQLite
freelist space created by historical delete-and-rebuild workflows.

That means a future optimization should likely separate two concerns:

- Search/index data shape, where active storage is dominated by cue lines, cue
  groups, ASS render segments, and FTS.
- SQLite maintenance strategy, where large freed pages should be monitored and
  compacted under explicit conditions.

The questioning path produced a new engineering concern: CueSeeker needs a
documented local database compaction strategy for rebuild-heavy derived index
data.

## Accepted First Pass

After comparing mature freelist handling options, the user accepted a first
implementation focused on making the condition observable before optimizing the
whole lifecycle.

The accepted first pass is:

- Add Storage Stats in Settings so the app can distinguish active database use
  from reclaimable freelist pages.
- Add a manual `Compact Database` action that performs WAL checkpointing and
  `VACUUM` under explicit user control.
- Defer automatic compaction, execution history diagnostics, and
  `auto_vacuum=INCREMENTAL` until there is more evidence about real indexing
  workflows and acceptable trigger conditions.

This keeps the reason for the change tied to the Socratic path: the immediate
problem is not proving that a particular indexing step is wrong, but giving the
project and user a way to see and reclaim inactive SQLite space.

## Open Questions

- Are the initial `100 MiB` and `25%` recommendation thresholds appropriate
  after more real libraries are indexed?
- Which concrete indexing or rebuild workflows create the largest freelist
  growth after maintenance stats are available?
- Should compaction later become automatic after index rebuilds, and what user
  interruption budget would make that acceptable?
- Should new databases use `auto_vacuum=INCREMENTAL`, and how should existing
  databases migrate if that direction is accepted?
- How should compaction coordinate with WAL mode, search reads, indexing writes,
  and app foreground responsiveness?
- Should ASS render segments remain in the main app database or move to a
  separate rebuildable cache database?

## Next Update Trigger

Update this chronicle when the user continues the Socratic questioning path and
explicitly asks to record the next stage of the process.
