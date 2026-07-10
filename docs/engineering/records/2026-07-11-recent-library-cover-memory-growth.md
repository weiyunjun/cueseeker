# Recent and Library Cover Memory Growth

## Requirement

- `docs/human/requirements/20260711-Bug-Recent Library Cover Memory Growth.md`

## Scope

Reduce stable Activity Monitor memory growth caused by Recent and Library cover
loading, route switching, scrolling, and window resizing while preserving the
original-resolution cover master.

The accepted display rendition keeps the source aspect ratio, fits within a
`512 x 288` pixel bounding box without cropping, stretching, or padding, and is
stored as a high-quality JPEG. Window resizing changes only presentation size;
it must not create a new rendition or decoded-image identity.

## Baseline

The production debug app was inspected while the current Recent page contained
19 distinct folder covers.

- Search launch observed by the owner: approximately 26 MB.
- Repeated Search and Recent navigation observed by the owner: approximately
  66 MB.
- Recent window resize observed by the owner: approximately 140 MB.
- `vmmap -summary` at the reproduced stable state reported a 140.3 MB physical
  footprint and a 162.1 MB peak.
- The same snapshot contained 45.2 MB of `CG raster data` and 46.8 MB of
  `CoreAnimation` regions.
- Heap inspection found 166 `NSImage` objects, 164
  `NSCGImageSnapshotRep` objects, and 19 active SwiftUI optional-image state
  slots.
- `leaks -quiet` reported zero ordinary leaked allocations.

This evidence identifies retained size variants and their render surfaces as
the primary resize multiplier rather than an ordinary retain-cycle leak.

## Planned Steps

1. Separate original-resolution masters from bounded display renditions in the
   cover data model and migration path.
2. Generate and backfill aspect-preserving high-quality JPEG display
   renditions.
3. Replace geometry-keyed image loading with one stable rendition identity,
   bounded decoded-image caching, duplicate-request coalescing, bounded decode
   concurrency, and stale-result protection.
4. Integrate the stable loader into Recent, Library folder, and Library episode
   views and release offscreen view ownership.
5. Avoid rebuilding unchanged Recent and Library presentation snapshots during
   route-only navigation.
6. Run automated coverage, inspect live VM categories, and hand the complete
   owner-authored Activity Monitor flow back for final end-to-end acceptance.

## Verification

Each implementation step will record its focused tests here. Final automated
verification must include the full Swift test suite and a debug build. Runtime
verification must inspect physical footprint, decoded raster regions, render
surfaces, cache accounting, in-flight decode count, and ordinary leaks.

Data-model verification:

- `swift test --filter libraryCoverRecordsStoreVideoSnapshotAndFolderReference`
  passed.
- `swift test --filter migrationAddsDisplayCoverFieldsWithoutReplacingMaster`
  passed, including a repeated migration call.
- `swift test --filter libraryCover` passed with three selected tests.
- The focused test build compiled the complete macOS application and test
  targets successfully.

Display-rendition implementation:

- Display profile version 1 is a JPEG at quality `0.90`. It preserves the
  orientation-normalized source aspect ratio, never upscales a small master,
  and fits completely within `512 x 288` pixels.
- ImageIO performs thumbnail decoding directly from the master. The generated
  bytes are reopened and validated for JPEG type, one image, orientation 1,
  and the pixel bounds before an atomic file write publishes them under
  `Covers/Display/v1/`.
- The display-only backfill path accepts database master records but has no
  video or FFmpeg input. It deduplicates candidates, runs at most four
  rendition jobs concurrently, skips current files, and updates the database
  only after successful generation.
- Each completed encode is committed as it leaves the four-job task group;
  compressed JPEG data is never accumulated for the full Library, so temporary
  generation memory remains bounded by the concurrency window.
- Encoded bytes remain private to a generation until a lock-protected commit
  token publishes the final file and database reference together. Cancelling,
  removing a folder, compacting, or starting a new index invalidates the token
  synchronously, so an older task cannot publish after the newer operation
  begins.
- Explicit Library indexing is two-stage: master freshness still controls
  frame extraction, while missing or old display renditions are generated from
  a fresh master without causing another video frame extraction.
- Existing databases are upgraded lazily when Recent or Library is first
  requested. Search-only startup remains free of background maintenance, as
  required by
  `docs/human/requirements/20260602-Bug-App Startup Database Side Effects.md`.
- A normally completed scope is marked attempted for the current App session
  even if one legacy master is missing or corrupt. Per-item failures therefore
  do not restart the entire batch on every route visit; a new App session,
  scope/profile change, or explicit index can retry them.
- If a current-profile database path points to a missing file and its master
  cannot regenerate it, the invalid display pair is cleared so presentations
  return a placeholder rather than repeatedly exposing a nonexistent path.
- Recent, complete Library, folder-summary, and folder-detail queries return
  only the current display profile. A missing or old display rendition returns
  `nil`; no query falls back to the master path.

Display-rendition verification:

- `swift test --filter LibraryCoverDisplay` passed five tests covering the
  fixed profile, wide/16:9/4:3/tall/small/oriented sources, real JPEG metadata,
  atomic failure preservation, stale-generation commit rejection, legacy
  backfill, invalid-path clearing, and idempotent reuse.
- `swift test --filter libraryCoverPresentationsNeverFallBackToMasterRendition`
  passed, including current-profile and stale-profile query behavior.
- `swift test --filter completeLibraryFolderSummariesAndDetailSplitFolderAndEpisodeData`
  passed with display-only folder and episode paths.
- `swift test --filter libraryRouteBackfillsLegacyDisplayCoverWithoutStartupMaintenance`
  passed, proving that startup remains idle, the first Recent hydration performs
  display-only backfill, the master bytes remain unchanged, and a partial
  missing-master failure does not restart or rewrite the batch on the second
  route hydration.
- `swift test --filter appStartupDoesNotRunDatabaseMaintenanceWhenIdle` passed.
- `swift test --filter libraryCover` passed seven selected tests after the
  display-rendition changes.

Decoded-image pipeline implementation:

- Cache identity is the display path, database-provided display revision, and
  display profile version. It deliberately excludes the SwiftUI frame or
  window size, so resizing cannot create another decoded variant.
- Recent, complete Library, folder-summary, and folder-detail presentations
  now carry the matching `video_covers.generated_at` value as `coverRevision`.
  Display updates use a fractional-second timestamp, and path/revision fallback
  selection is kept paired in folder-summary queries.
- The actor-owned cache is a deterministic cost-LRU with a hard 16 MiB budget,
  a 64-entry ceiling, and `CGImage` byte cost. A single decoded entry larger
  than the budget is returned to its caller but never cached.
- Same-key callers share one decode. The internal scheduler permits at most
  four actual ImageIO decodes, keeps cancelled running work in the active count
  until it finishes, and resumes queued work only when a real slot becomes
  free.
- Each waiter has a synchronous cancellation flag plus actor cleanup. The last
  waiter cancels the decode; a late result is discarded and cannot enter the
  cache or update a caller. A new waiter arriving during cancellation receives
  a fresh decode after the old task has actually exited.
- The production decoder reads the already-bounded display JPEG directly into
  `CGImage`; it rejects a file larger than `512 x 288`, preventing accidental
  Master decoding even if an invalid path reaches the pipeline.

Decoded-image pipeline verification:

- `swift test --filter LibraryCoverImagePipeline` passed nine tests covering
  deterministic LRU eviction, the 16 MiB-style cost contract, same-key request
  coalescing, hard decode concurrency, partial waiter cancellation, late-result
  rejection and restart, immediate pre-registration cancellation, oversize
  cache exclusion, full cache/in-flight removal with late completion, and the
  production decoder's Master-size guard.
- `swift test --filter libraryCoverPresentationsNeverFallBackToMasterRendition`
  passed with path/revision pairing for master-only, current-profile, and stale
  profile states.
- `swift test --filter completeLibraryFolderSummariesAndDetailSplitFolderAndEpisodeData`
  passed with matching fallback path and revision in folder and episode data.

View integration:

- Recent cards, Library folder cards, and Library episode rows now pass their
  paired display path and revision into one `LibraryCachedCoverImage` view.
- The view task identity is only the pipeline key. Window size, backing scale,
  and card geometry are absent, so resizing changes the SwiftUI frame without
  restarting or creating another decode.
- The former cover `GeometryReader`, per-render file-attribute reads,
  size-keyed ImageIO thumbnail decode, `NSImage` state, and 48 MiB `NSCache`
  were removed. SwiftUI now renders the pipeline's bounded `CGImage` directly.
- Per-card state stores the key with the image and tracks a request UUID. It
  checks cancellation and request identity after every await; disappearance
  invalidates the request UUID before clearing the image, so a late task cannot
  restore an offscreen reference. Lazy-grid scrolling, route changes, and
  Library level transitions therefore release view-owned image references
  while the shared cache remains capped at 16 MiB.

View-integration verification:

- `swift test --filter libraryCoverImage` passed ten tests, including the
  path/revision-pair requirement used by the view.
- `swift test --filter LibraryCoverProgressPresentation` passed and compiled
  the complete App target with the new cover view.
- A source audit found no remaining `LibraryDownsampledCoverImage`,
  `LibraryCoverImageFileVersion`, old `LibraryCoverImageCache`, old
  `LibraryCoverImageLoader`, size-keyed cover request, or `NSImage` use in
  `WorkbenchTestLibraryView.swift`. Remaining `GeometryReader` instances are
  unrelated progress or menu layout helpers.

Route snapshot reuse:

- Route hydration now loads Library, Recent, test Recent, and complete Library
  only while their presentation is idle or failed. Once a snapshot reaches
  `completed`, leaving and re-entering the route reuses it without starting a
  database task or incrementing its presentation revision.
- An empty selected-folder scope is also idempotent. Repeated route entry does
  not keep applying another empty snapshot; a stale nonempty snapshot is still
  cleared once if the scope becomes empty.
- Recent and Library hydration still asks the lazy display-rendition backfill
  to run before the completed-snapshot guard. A legacy database can therefore
  receive its bounded display renditions even when its presentation snapshot
  was already loaded.
- Folder indexing, folder removal, display-rendition publication, and explicit
  refresh continue to call the force-refresh methods. The view-level folder
  observers no longer start duplicate Recent or complete-Library refreshes;
  the Library observer only closes a detail whose selected scope changed.
- Playback-history and manual watch-state changes no longer rebuild the
  complete-Library folder summary because that query contains no playback
  state. They increment `libraryPlaybackHistoryRevision`, refresh Recent, and
  let an open folder detail reload from the existing history-aware task ID.

Route-snapshot verification:

- `swift test --filter libraryRouteHydrationReusesCompletedSnapshotsUntilExplicitRefresh`
  passed. It covers an idempotent empty scope, the first real load of all four
  presentations, completed route re-entry with no task or revision change, and
  an explicit refresh that increments every revision once.
- `swift test --filter playbackHistoryChangesReloadRecentAndDetailWithoutRebuildingLibrarySummary`
  passed for both direct history recording and asynchronous manual watch-state
  changes. Recent data reloaded, the history revision advanced, and no complete
  Library task or summary revision was created.
- `swift test --filter closingLibraryPlaybackSavesHistoryAndMarksHistoryRevision`
  passed with the added assertion that playback close does not start or revise
  a complete-Library summary.
- `swift test --filter libraryRouteBackfillsLegacyDisplayCoverWithoutStartupMaintenance`
  passed after the completed-snapshot guard, confirming that lazy display
  backfill remains compatible with route snapshot reuse.

The owner will perform the final Activity Monitor UI acceptance flow. Its final
stable physical footprint must not exceed 75 MB, with no more than 5 MB growth
after repeated Library navigation and no more than 10 MB growth after window
resize relative to the first completed flow.

## Outcome

The diagnostic baseline and implementation boundaries were recorded before
code changes.

Schema version 27 now separates the existing original-resolution master path
from an optional display-cover path and profile version. The migration preserves
all legacy master and folder-cover rows and deliberately leaves display fields
empty so a master can never be mistaken for a bounded display rendition. The
database API validates that display path and profile version are stored or
cleared together.

Display profile version 1 and its lazy backfill path are implemented. Existing
masters remain unchanged, explicit indexing and migration backfill share the
same bounded display-only generator, and all Recent/Library presentation
queries are now unable to expose a master path. This establishes one fixed
on-disk rendition identity before the decoded-image cache and SwiftUI ownership
changes.

The decoded-image pipeline is implemented and covered independently of the
views. Its budget, request coalescing, decode concurrency, and cancellation
rules are deterministic. All current Recent and Library cover surfaces now use
that pipeline, and view-owned decoded images are released when their cards leave
the viewport or route.

Completed Recent and Library snapshots are now stable across route-only
navigation. Explicit data changes retain their force-refresh path, while
playback-only changes reload Recent and an open history-aware folder detail
without rebuilding the unchanged cover-bearing Library summary.
