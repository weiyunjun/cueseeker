# Remove resource identity and binding state machine

Human-owned documents:

- `docs/human/design/Data.md`
- `docs/human/requirements/20260823-Bug-Index Path Identity And Missing Resource Forgetting.md`
- `docs/human/requirements/20260823-Engineering-Single App Instance Guard.md`

## Why

Adding `/Volumes/Samsung/测试` failed with `Library became unavailable before
indexing started.` although the directory was fine. The directory had been
removed once before, which left a historical Library record whose path had been
rewritten to `cueseeker-unbound://library/175` with state `removed` and its
platform resource identity intact. Re-adding the directory matched that record by
resource identity, and the next statement only accepted records in state
`available`, so the run failed before any file was scanned.

The root cause was an entire resource identity and binding state machine that
`Data.md` never defined and that contradicts it: `Data.md` decides new versus old
files by path and file name only, and content change by size and modification
time only.

## What changed

Schema 43 removes `resource_identity`, `content_fingerprint`, `binding_state`,
`last_known_path`, `last_seen_at`, `is_configured`, `latest_index_token`,
`published_index_token`, the resource identity unique indexes, and the
`resource_binding_conflicts` table. Resources that had already left the index are
deleted together with the covers, watch states, progress and playback history
that belonged to them; Cues still referenced by a Shiori are tombstoned first.

Indexing now binds a Library by its absolute path alone. A resource that is not
in the current scan result is deleted rather than retired, so removing a Library
really removes it and re-adding the same path starts a new LibraryID. Search,
Library, Shiori, facet counts, covers and the indexed content tree no longer
filter on binding state, so historical state can no longer hide valid content.

The persistent index publication token is replaced by a single running instance
(`SingleInstanceGuard`) plus a serialized index entry: a second launch activates
the existing window and exits, and triggering an index while one runs is
rejected instead of cancelling the running one.

## Verification

- `swift build` and `swift build --build-tests` clean.
- `swift test`: the failures that remain are the timing- and device-dependent
  tests that also fail on the unmodified tree (native playback, window scene,
  and the main-actor-timing tests in `LibraryFolderRemovalTests`,
  `CueGroupRefreshScopeIntegrationTests` and the Shiori focus suites). The set
  shifts between runs on both trees. No failure remains that is caused by this
  change.
- Migration checked against a copy of the real database: integrity check `ok`,
  foreign key check clean, schema 43, no retired columns or conflict table left.
  `search_paths` 3 → 1, `subtitle_files` 789 → 614, `video_files` 680 → 644,
  `library_watch_states` 447 → 413, `library_playback_history` 307 → 291,
  `user_video_covers` 14 → 12, `user_folder_covers` 10 → 10, `shioris` 678 → 678,
  and no Shiori references a Cue that is neither live nor tombstoned.
- Watch progress and watch state were exported to
  `~/Library/Application Support/CueSeeker/watch-data-backup-20260823.json`, and
  the whole database to `CueSeeker.sqlite.backup-20260823-before-identity-removal`,
  before any migration was run.

## Outcome

Matched expectations. One behaviour change follows from the rule and is worth
naming: a subtitle that leaves the index and later returns at the same path is a
new resource, so a Shiori that pointed into it stays available as a record but
remains unavailable against its Tombstone instead of being restored.

## Left for the owner

- `apps/macos-native/Sources/CueSeekerCore/FileResourceIdentity.swift` is now
  dead code and should be deleted.
- `apps/macos-native/Sources/MigrationCheck/main.swift` was a throwaway tool used
  only to run the migration against a copy of the real database; its package
  target has been removed and the file should be deleted.
