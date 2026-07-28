# Search And Shiori Old Filter Cleanup

## Requirement

- `docs/human/requirements/20260728-Feature-Search Shiori Secondary Views And Table UI Refinement.md`, Step 9.
- `docs/human/design/UI.md` remains the human-owned UI authority; its final synchronization is deferred to Step 10.

## Scope

- Removed the unused Workbench Filter Builder UI, rule conversion models, session rule state, and Filter-only empty-query projection.
- Removed the replaced global Search language and watch-scope settings and the old Filter count Badge implementation.
- Preserved the core filter model and the all-Cue loading path still used by Context and Command Panel workflows.
- Removed tests that only exercised deleted paths and retained coverage for the surviving Search, Shiori, Context, Playback, Command Panel, selection, copy, and export boundaries.

## Verification

- `swift build`: passed.
- `swift test --filter SearchStoreTests`: 29 tests passed.
- `swift test --filter CueGroupRefreshScopeIntegrationTests`: 14 tests passed.
- `swift test --filter Shiori`: 76 tests passed.
- `swift test --filter CommandPanel`: 11 tests passed.
- `swift test --filter Clipboard`: 15 tests passed.
- `swift test --filter Export`: 10 tests passed.
- `swift test --filter Selection`: 71 tests passed.
- `swift test --filter LibraryFolderRemovalTests`: 8 tests passed.
- `swift test --filter NativePlaybackMediaTimelineTests`: 5 tests passed.
- `swift test --filter subtitleFocusShioriKeySavesIdempotentlyAndKeepsPausedSession`: passed.
- The concurrent full run executed 903 tests and reported 10 timing or shared-fixture issues in Library removal, native media timing, Shiori save timing, and one UI invalidation assertion. Every reported test or suite passed when rerun in its focused scope.
- `git diff --check`: passed.

## Outcome

The replaced Filter paths were removed without adding compatibility state or replacement abstractions. All affected feature boundaries pass focused regression testing. The repository-wide concurrent run remains subject to pre-existing cross-test timing and shared-fixture interference; this cleanup did not expand scope to those unrelated test-harness issues.
