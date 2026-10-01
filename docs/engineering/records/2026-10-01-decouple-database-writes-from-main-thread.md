# Decouple Database Writes From Main Thread

Human-owned documents:

- `docs/human/requirements/20261001-Engineering-Decouple Database Writes From Main Thread.md`

## Why

During long-running database operations (such as Subtitle Indexing, Add Folder, or Remove Folder):
1. In SQLite WAL mode, readers do not block writers and writers do not block readers, but only a single writer transaction (`IMMEDIATE` transaction) is permitted at a time.
2. User interactions such as adding, editing, moving, duplicating, deleting Excerpts, or deleting Excerpt Lists previously executed immediate write transactions directly on `@MainActor`. When a background library task held SQLite's write lock, the main actor was blocked waiting for SQLite busy timeout (up to 5 seconds), causing the app UI to freeze and beachball (rainbow wheel).
3. Playing a video located in a folder currently being removed suffered from video frame stalling due to main thread stalls and active playback history write contention.

## What changed

- **Optimistic UI Updates on `@MainActor`**:
  - `saveExcerpt`: updates cue counts and presents success toast optimistically on `@MainActor`.
  - `moveExcerpt`: checks existence upfront via fast non-blocking read (`excerptRelationExists`), performs optimistic cue count adjustments on `@MainActor`, and presents success toast immediately.
  - `duplicateExcerpt`: checks existence upfront via fast non-blocking read (`excerptRelationExists`), performs optimistic cue count adjustments on `@MainActor`, and presents success toast immediately.
  - `removeExcerpt`: optimistically removes excerpt from current projection and adjusts cue counts on `@MainActor` before delegating deletion to background.
  - `deleteExcerptList`: optimistically navigates workbench and removes list summary from in-memory overview before background deletion.
  - `recordRecentExcerptPlayback`: optimistically computes and prepends the new `ExcerptListSummary` in `recentListSummaries` on `@MainActor`.

- **Asynchronous Background Database Writes**:
  - All write transactions for `saveExcerpt`, `moveExcerpt`, `duplicateExcerpt`, `removeExcerpt`, `deleteExcerptList`, and `recordRecentExcerptPlayback` are dispatched to detached background tasks (`Self.runCancellableDetached`) off the main thread.
  - Added `excerptMutationTask: Task<Void, Never>?` to `AppCoordinator` to track in-flight background excerpt mutations and allow cancellation or test completion synchronization.
  - Added public `excerptRelationExists(cueID:listID:)` on `ExcerptDatabase` for fast non-blocking existence checks before write operations.
  - In `performFolderRemoval`, proactively stops playback history tracking (`stopLibraryPlaybackHistoryTracking()`) if the currently playing video is within the folder being removed, preventing write contention during deletion.

- **Tests**:
  - Updated `waitForExcerptTasksToFinish` in `ExcerptPresentationTests.swift` to also await `excerptMutationTask == nil`.
  - Updated `removeExcerptDoesNotHydrateLegacyPresentationWhenTableOnly` and `excerptTransfersRefreshPresentationAndPublishRegisteredToasts` to await `waitForExcerptTasksToFinish(app)` to observe asynchronous background write completion.
