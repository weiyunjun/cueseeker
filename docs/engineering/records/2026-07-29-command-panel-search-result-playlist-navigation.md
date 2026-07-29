# Command Panel Search Result Playlist Navigation

## Requirement

- `docs/human/requirements/20260729-Bug-Command Panel Search Result Playlist Navigation.md`
- `docs/human/design/Command Panel.md` remains the authority for the temporary
  empty-Filter Search behavior.
- `docs/human/design/UI.md` remains the authority for entering the complete
  Search result Playlist from a Command Panel result.

## Classification

- Search result projection and playback intent resolution: product semantics.
- Command Panel and Playback Overlay presentation: unchanged native UI/UX.
- Native media execution: unchanged.

## Cause

Command Panel Search correctly executed with a temporary empty Filter, but
Playlist installation and later refresh read the Workbench facet projection.
When a persisted Workbench facet excluded the Command Panel results, the
Playlist boundary became empty or incomplete. Enter therefore opened an
Overlay without the Playlist module, and navigation remained inside Current
video subtitles instead of the Search result collection.

## Implementation

- Recorded whether each Search Playlist source uses the Workbench facet
  projection as part of its existing source origin.
- Made Command Panel temporary Search install and refresh from the complete
  resident Search results.
- Preserved Workbench Search playback against its active facet projection.
- Added an integration regression test covering real database Search, result
  activation, temporary-host completion, Enter opening the Overlay, selected
  result restoration, and two consecutive Playlist navigation steps.

## Verification

- Before the fix,
  `swift test --filter playbackCommandPanelDatabaseSearchOpensCompletePlaylistOverlay`
  reproduced the bug: only Current was available and `playlistWindow` was
  `nil`.
- After the fix, the same integration test passed with 30 Playlist results,
  the clicked second result selected, and two consecutive forward navigation
  commits.
- The combined Command Panel, Playback Playlist, Playback Subtitle Focus,
  Playback Segment Completion, and Search Store run passed all 179 tests.
- The complete run executed 904 tests and reported 15 concurrent timing or
  shared-fixture issues in native media timing, Subtitle Focus persistence,
  row-menu timing, and UI invalidation probes. Every affected suite or test
  passed in isolated serial reruns: 2 presentation-transition tests, 5 media
  timeline tests, 2 Subtitle Focus tests, 10 row-menu tests, and 1 UI
  invalidation test.

## Outcome

Command Panel Search now promotes its complete temporary empty-Filter result
collection into Playlist, retains that collection across later result refresh,
restores the clicked result, and exposes Playlist when Enter opens the Playback
Overlay. Workbench facet-scoped Playlist behavior remains unchanged.
