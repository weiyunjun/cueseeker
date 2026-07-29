# Shared UI Full Regression and Cleanup — Step 8

## Requirement

- `docs/human/requirements/20260729-Feature-Workbench Playback And Command Panel Shared UI.md`
- Step 8: regress every requested surface, confirm shared presentation,
  selection, keyboard, scrolling, playback, and return behavior, and remove
  superseded implementations introduced or replaced by this requirement.

## Classification

- Source-path cleanup and cross-surface verification: native platform UI/UX.
- Search, Shiori, Library, Recent, and Playback product semantics: unchanged.
- Native media execution: unchanged.

## Audit

- Confirmed Shiori Tag presentation, application state, Core API, and current
  schema creation are absent. Only historical migration SQL and migration tests
  retain the old table names.
- Confirmed Shiori has no submitted-query path or Display Title matcher and
  continues to use the shared Primary Cue query matcher.
- Confirmed Library and Shiori use the shared Overview primitives, while
  Workbench Library Detail and Playback Video Playlist use the same Episode
  Grid with only their documented host selection differences.
- Confirmed all three Recent Video surfaces use `RecentWatchingGrid` and all
  requested Recent Shiori surfaces use `RecentShioriResumeList`. The replaced
  Command Panel-only Recent Video Row is absent.
- Confirmed Current retains its dedicated primary-only Reel hot path while
  sharing the accepted Badge presentation boundary. Cue Playlist and Command
  Panel Search use the same Cue Result Reel, and the replaced Command Panel
  cover and result Row are absent.
- Confirmed every Playback Cue keeps a fixed Badge-row extent and selection
  changes only the Playback-specific neutral palette.
- Found no remaining superseded production implementation from Steps 1–7, so
  no application source deletion or refactor was required during closeout.

## Verification

- `swift test`: all 898 tests compiled and ran. The concurrent run reported 20
  issues across 12 timing, temporary-database, native-media, and UI probe tests.
- Each of the 12 reported tests passed when rerun individually, so the full-run
  issues were not reproducible as a shared-UI regression.
- The source audit found no old Command Panel Recent Video Row, Command Panel
  Search cover/result Row, active Shiori Tag API, or submitted Shiori query
  implementation.
- `swift build`: passed.
- `git diff --check`: passed before final review.

## Outcome

- Step 8 required no production code changes. The implementation introduced by
  this requirement is closed out without adding another abstraction or
  replacing any stable host-specific interaction path.
