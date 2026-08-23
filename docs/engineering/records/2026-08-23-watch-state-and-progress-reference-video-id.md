# Watch state and progress reference the VideoID

Human-owned documents:

- `docs/human/design/Data.md`
- `docs/human/requirements/20260823-Bug-Index Path Identity And Missing Resource Forgetting.md`

## Why

`Data.md` says watch state, playback progress and playback history reference the
`VideoID`. They were stored keyed by the video path instead, with the VideoID as
a nullable side column. A path key means the same path reappearing silently
inherits the old progress, which is the opposite of the accepted rule that a
resource which left the index is forgotten.

## What changed

Schema 44 rebuilds `library_playback_history` and `library_watch_states` with
`video_file_id` as the primary key and a cascading reference to `video_files`.
Rows that were never bound to a video are dropped, since they point at nothing in
the index. Reads and writes now look up and conflict-resolve on the VideoID, and
the video path in the returned history comes from the video record itself.

## Verification

- `swift build`, `swift build --build-tests` clean; `CueSeekerCoreTests` fully
  green (271 tests).
- Full `swift test`: the remaining failures are the same load- and
  device-dependent ones that also fail on the unmodified tree; they pass when run
  in isolation and the set rotates between runs on both trees.
- Migration chain 42 → 44 run against a copy of the real database: integrity
  check `ok`, foreign key check clean, both tables keyed by `video_file_id`,
  `library_playback_history` 307 → 253, `library_watch_states` 447 → 365,
  `shioris` 678 → 678, no row pointing at a missing video. The dropped rows are
  the ones that had no VideoID (38 and 48) plus those belonging to videos that
  had already left the index.
- The dropped values are preserved in
  `~/Library/Application Support/CueSeeker/watch-data-backup-20260823.json`.

## Outcome

Matched expectations.
