# Settings Library Folder Removal Responsiveness

## Human-Owned Requirement

- `docs/human/requirements/20260720-Bug-Settings Library Folder Removal Responsiveness.md`

## Classification

- Platform UI/UX: Settings exposes an observable Removing state while keeping
  the macOS main event loop responsive, then reports the removed folder after
  the transaction succeeds.
- Platform integration: folder removal, indexing, folder addition, and database
  compaction are mutually exclusive at both the control and coordinator layers.
- Product semantics: the existing target-folder cleanup, local-file retention,
  Shiori retention, playback-history retention, and remaining Search order are
  unchanged.
- Playback execution: unchanged.

## Root Cause

The Settings confirmation action called the complete SQLite deletion transaction
synchronously from a `@MainActor` coordinator method. The transaction then
rebuilt every Search order row and every FTS row, including CJK segmentation and
individual statement preparation for all retained Cue Groups. Removing a small
folder therefore blocked the main event loop in proportion to the complete
database rather than the removed folder.

## Implementation

1. Added a published `removing(folder)` state and used it to disable Add Folder,
   Remove, Index Now, storage refresh, and database compaction while deletion is
   active.
2. Added symmetric coordinator guards so Indexing rejects Remove and Removing
   rejects folder addition, Index Now, and database compaction even when a UI
   control is bypassed.
3. Moved deletion to a serialized actor that opens a dedicated SQLite connection,
   leaving the main actor responsible only for state transitions and presentation
   refreshes after the transaction succeeds.
4. Kept the existing target-table cleanup transaction but made
   `removeIndexedFolder` skip the global Search-order and FTS rebuild. The shared
   stale-entry cleanup used by batch Indexing still performs its final rebuild.
5. Added deterministic regressions for retained FTS row IDs, Search order,
   observable progress, main-actor responsiveness, mutual exclusion, and failure
   rollback presentation behavior.
6. Added a separate successful-removal notice after the operation returns to
   idle. Settings renders `Removed <folder name>` with success styling, and the
   next Remove or Index operation clears the stale notice.

## Verification

- `swift test --filter LibraryFolderRemoval` passed all 5 App orchestration and
  dedicated-connection integration tests.
- `swift test --filter removingIndexedFolder` passed all 4 target-cleanup,
  retention, and retained-row-ID database tests.
- `swift test --filter SubtitleIndexerTests` passed all 16 Indexing tests,
  including changed-file and stale-file rebuild coverage.
- `swift test --filter CueSeekerCoreTests` passed all 208 Core tests.
- `swift test --filter AppStartupDatabaseTests` passed all 4 startup and
  explicit-Index tests.
- `swift test --filter Settings` passed all 16 Settings-related tests.
- `swift build` passed.
- Runtime interaction with the user's live database was not performed; the
  main-actor responsiveness test uses a controllable serialized executor so it
  verifies progress while deletion remains in flight without mutating user data.

## Outcome

Settings Library removal no longer performs database-scale work on the main
actor. Conflicting write workflows remain serialized, retained FTS row IDs keep
their original ordering, UI state is committed only after successful database
deletion, and Settings confirms the removed folder without keeping the database
operation active.
