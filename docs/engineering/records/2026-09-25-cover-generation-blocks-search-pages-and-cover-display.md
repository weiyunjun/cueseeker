# Cover generation blocks Search, the pages and cover display

Human-owned documents:

- `docs/human/requirements/20260925-Bug-Cover Generation Blocks Search Pages And Cover Display.md`
- `docs/human/design/Data.md` (Index流程 第 6 步)
- `docs/human/requirements/20260918-Feature-Task Concurrency And Nested Root Folders.md` (5. Index 进度)

## Why

The cover stage generated up to 32 covers at once as child tasks of the Index task. Each cover runs ffmpeg and waits for it, and the waiting held one of the threads Swift concurrency shares across the whole App. The Index task awaits those children at the priority it was started with, so the children took over that priority's threads, and once they were all taken, nothing else at that priority started until the last cover was done: the Search scan, the page loads (Recent, Library) and the cover images, which are read through an actor the views call at that priority. So existing covers showed placeholders, Search did not finish, and a page opened for the first time since launch stayed on its spinner. The stored covers never changed. The cause dates from the first cover generation commit (`390f025`, 2026-06-21); no earlier requirement covered it.

A standalone probe on this machine (10 cores), not in the App, showed the same: with 32 children waiting on a process, a task at that priority started only after 11.5 seconds, and work queued on a global dispatch queue waited as well. With the waiting moved to a dispatch queue of its own, every probe started at once. Waiting on a process takes no CPU, so the queue's threads do not crowd anything out.

## What changed

- **Covers wait on their own queue.** Each cover's ffmpeg work runs on a concurrent dispatch queue of the cover indexer and the child task suspends until it is done, so the shared threads stay free for Search, the pages and the cover images.
- **The default concurrency is the core count.** The 32 was never reached: the shared threads held it to about the core count. With the covers off those threads it would be reached, so the default now names what actually ran, to keep the stage's speed and the disk load as they were.
- A removed task still stops once the covers in hand are done; the rules for which covers are made and what is kept are untouched.

Files:

- `apps/macos-native/Sources/CueSeekerPlayback/LibraryCoverIndexer.swift`
- Tests: `LibraryCoverIndexerTests`

## Verification

- `coverGenerationLeavesSearchAndPageWorkRunning` generates covers for at least 32 videos with the default concurrency and an ffmpeg stand-in that takes 2 seconds per frame, and asks, from a thread of its own, for a task at the priority Search and the pages use 0.3 seconds into the stage. Before the change it started after 6.2 seconds and the test failed; after it, within a millisecond, three runs out of three. A first version asked from a dispatch queue and passed on the old code, because the queue itself waited for the stage; it was corrected before the fix, not loosened.
- `cancelledCoverIndexStartsNoFurtherCover` and the other cover tests pass; the video fixture loop they shared is now one helper.
- `swift test` (full, parallel): 1279 tests, 13 failing, none from this change: exactly the environment-sensitive set earlier records name (the eight native playback tests including `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, the two Debug E2E scene and width tests, `progressiveSearchProjectionRefreshesOnlyMountedTable`, `excerptTableStartsAtTopAfterPanelRemount`, `showCueGroupInvalidationIsScopedToMountedExcerpt`). They are playback timing, window sizes, scroll anchors and refresh counts; none generates a cover.
- In-App: acceptance items 1 to 3 (covers, Search and first page loads during the cover stage, and the stage's duration) are the owner's.

## Known limits

- The other Index stages still run on one shared thread each; they never took all of them.
