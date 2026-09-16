# Packaged app crashes when searching

Human-owned documents:

- `docs/human/requirements/20260917-Bug-Packaged App Crashes When Searching.md`
- `docs/human/requirements/20260916-Feature-Filter Dialog Folder Group And Fixed Height.md`

## Why

After the Folder group change (`2f63076d`), the packaged App aborted on every search, typed (`の`) or started by a search Deep Link; the build before it did not. The four crash reports of 2026-09-17 (00:39 to 00:47) share one stack: `swift_task_dealloc` aborting inside `asyncLet_finish_after_task_completion`, called from the search task in `SearchStore.startSearch`.

A search runs the scan off the main actor as an `async let` while the main actor reads its first page from a stream, then awaits the scan. Swift 6.1's optimizer can free an `async let` out of order when its result does not fit the preallocated buffer, and the concurrency runtime then aborts with "freed pointer was not the last allocation" (Swift Forums, "Fix for async let teardown ordering crash"). Debug builds and `swift test` do not run those optimizations, so neither saw it. The search code itself was unchanged since 2026-09-15; the Folder group added the folder of every match and the folder counts to the facet snapshot the scan returns, which grows the `async let` result. That the growth is what crossed the limit is inferred, not measured.

Classified as platform integration (task execution). No product semantics change.

## What changed

- The scan is a detached task started where the `async let` was; the first page is still read from the stream while it runs, and the result is awaited under a cancellation handler that cancels the scan, as the other search reads already do through `runCancellableDetached`. No `async let` remains in the search, so the result type can grow without reaching the bug. A comment at the scan says why.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Search/SearchStore+Execution.swift`

## Verification

- `swift build`: compiles.
- `swift test`: 1237 tests, 25 issues in 14 tests, all in the environment-sensitive set of the earlier records: native playback (6), `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, Debug E2E scene and width (2), Library folder removal (2), Excerpt remount and scoped invalidation (2) and `progressiveSearchProjectionRefreshesOnlyMountedTable`. Run alone with the Search store, Search settings, playback search overlay and `libraryFolderRemovalAndIndexingRejectEachOther` tests, 68 tests pass.
- Packaged App: not built or driven here. The crash only occurs in optimized builds and the Debug E2E controller is compiled into Debug builds only, so the owner packages the App and verifies acceptance items 1 and 2 by hand, per the requirement.

## Known limits

- The cause of the abort rests on the crash stack and the Swift Forums report; the size of the `async let` result before and after the Folder group was not measured.
