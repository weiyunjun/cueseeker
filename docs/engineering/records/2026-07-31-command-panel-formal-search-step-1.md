# Command Panel Formal Search — Step 1

## Requirement

- `docs/human/requirements/20260731-Feature-Command Panel Search Integration And Recent Videos Refresh.md`
- `docs/human/design/Command Panel.md`

## Classification

- Search query, Filter, result projection, and Playlist scope: product
  semantics.
- Command Panel preview and selection: native platform UI/UX.
- Native media execution: unchanged.

## Cause

Command Panel Search replaced the shared Search result collection with a
temporary empty-Filter run. Closing the panel restored the previous Workbench
Filter result, so entering Search Result without playback did not remain the
formal Workbench Search state. The Command Panel preview and promoted Playlist
also read the unfiltered resident collection instead of the Workbench facet
projection. A later selected-text entry exposed that the persisted Workbench
facet Filter was copied into Search state only when the Workbench Search view
appeared or a URL Scheme search started.

## Implementation

- Removed the temporary playback Filter lifecycle and its restore calls.
- Made Command Panel Search use the normal non-debounced Search pipeline while
  retaining the persisted Workbench facet Filter.
- Made Command Panel preview count, result actions, and promoted Playlist read
  the same filtered Search projection as Workbench.
- Initialized shared Search state from the persisted Workbench facet Filter, so
  every search entry uses it without depending on Workbench view lifecycle.
- Kept the 50-result preview Window as the only Command Panel selection owner.
- Preserved Playback Return Context changes only for successful playback.

## Verification

- `swift test --filter 'playbackCommandPanel|playbackSearch'`: 9 tests passed.
- `swift test --filter
  'playbackCommandPanel|playbackPlaylist|playbackReturnContext|playbackSearch'`:
  24 tests passed.
- Three focused persisted-Filter, Command Panel, and URL Scheme tests passed.
- `swift build`: passed.
- `swift test --no-parallel`: ran 932 tests with the same three unrelated
  pre-existing issues; the persistence issue passed alone, while the two
  Subtitle Table right-click menu position tests still failed alone.
- `git diff --check`: passed.

## Outcome

Command Panel Search is now a formal shared Search operation. Closing it
without playing retains the current Query, Filter, and filtered results for
Workbench Search. Selected-text Search also receives the persisted Workbench
facet Filter even when Workbench Search has not appeared during the session.
