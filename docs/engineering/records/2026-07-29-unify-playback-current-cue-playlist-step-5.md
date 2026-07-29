# Unify Playback Current and Cue Playlist — Step 5

## Requirement

- `docs/human/requirements/20260729-Feature-Workbench Playback And Command Panel Shared UI.md`
- Step 5: share the Cue presentation structure between Playback Current and
  Cue Playlist, remove both left covers and the Playlist sequence lane, add the
  documented selected-item Badges, and place Cue Group text below Primary Cue.

## Scope

- Reused one Cue Result measurement and rendering layout for Playback Current
  and Cue Playlist while retaining their existing Reel, Session, selection,
  scrolling, and action owners.
- Removed both left-side cover presentations and the Playlist sequence lane.
- Added independent selected-item information Badges. Current supplies Display
  Title and Time Range; Cue Playlist supplies `[x/y]`, Display Title, and Time
  Range.
- Ordered Primary Cue above optional Cue Group text. Current never supplies Cue
  Group text, while Cue Playlist shows it below every result when the existing
  setting is enabled.
- Preserved Current's existing measurement invalidation probe while routing its
  geometry through the shared Cue Result cache.
- Updated focused layout, adapter, and Current integration tests, the shared
  architecture rule, and the changelog. Human-owned documents, including
  `docs/human/design/UI.md`, were not modified.

## Verification

- `swift build`: passed.
- `swift test --filter playbackCueResult`: all 12 focused tests passed.
- `swift test --filter playbackPlaylist`: all 13 focused tests passed.
- `swift test --filter playbackCurrentUsesSharedCueResultWithTwoInformationBadges`:
  passed.
- `swift test --filter subtitleFocus`: all 69 focused tests passed.
- `swift test`: all 894 tests compiled and ran; the parallel run reported 12
  issues across 6 existing native-media timing, Shiori persistence I/O, and UI
  refresh-scope tests. Each failed test passed when rerun individually,
  confirming shared-resource or timing flakiness rather than a Step 5
  regression.
- The two Playback mount-probe integration tests passed both individually and
  in the final full run after the Current measurement probe was preserved.
- `git diff --check`: passed before the final review.

## Outcome

- Step 5 matched the requirement in focused verification. Playback Current and
  Cue Playlist now share the Cue Result layout and differ only through their
  documented information Badge and Cue Group policies.

## Follow-up: Restore Stable Reel Selection Geometry

- Corrected the Step 5 regression that made selected Badge presence part of an
  adapter-owned measurement key and invalidated all measurements after every
  selection commit. That mismatch allowed the Reel's visual selection and the
  delayed external selection to use different item heights during motion.
- Kept Primary Cue and resident Cue Group content in one selection-independent
  base extent. Badge text and selection no longer participate in the base
  measurement cache or dataset revision.
- Made the Badge row height a fixed 23 points with the documented 8-point Cue
  gap. The Reel now applies that fixed decoration from its own current visual
  selection and immediately recomputes local placements for only the selection
  transition.
- Added regression coverage for a 50,000-item rapid scrollbar drag followed by
  selection and keyboard transitions. The test verifies stable adjacent center
  distance, retained resident Cue Group content, bounded virtualization, and
  fixed Badge height transfer without adapter selection invalidation.

### Verification

- `swift build`: passed.
- `swift test --filter playbackCueResult`: all 12 focused tests passed.
- `swift test --filter playbackPlaylist`: all 13 focused tests passed.
- `swift test --filter subtitleFocus`: all 69 focused tests passed.
- `swift test`: all 894 tests compiled and ran; the parallel run reported 18
  issues across 10 existing native-media timing, temporary-database, action
  timing, and UI refresh-scope tests. Each failed test passed when rerun
  individually, confirming shared-resource or timing flakiness rather than a
  Reel regression.
- `git diff --check`: passed before the final review.

## Follow-up: Restore Current Reel Performance

- Replaced the over-shared Current implementation with its original
  primary-only text measurer, bounded measurement cache, and native text
  drawing path. Cue Playlist continues to use the general Cue Result layout
  needed for Cue Group content.
- Kept the accepted visual reuse at the smallest stable boundary: Current and
  Cue Playlist share the information Badge layout and drawing implementation,
  typography tokens, and visible presentation rules rather than the complete
  high-frequency measurement path.
- Applied the fixed 31-point selected information decoration to Current's
  cached base Cue extent without constructing a Cue Result or formatting Badge
  text during measurement.
- Added a one-item Current Badge text and width-plan cache so repeated Reel
  frames reuse the selected Cue's Display Title, Time Range, and Badge widths.
  Removed the duplicate production dictionary that had tracked measurement
  access only for tests.
- Preserved the existing teardown path, which synchronously cancels both Reel
  animators, pending settle and motion tasks, and the local scroll event monitor
  before releasing the document adapter.

### Verification

- `swift test --filter playbackCurrent`: all 2 focused tests passed. The hot-path
  regression test performs 1,000 selected extent reads with one text
  measurement and 1,000 identical Badge plan requests with one plan build.
- `swift test --filter playbackCueResult`: all 12 focused tests passed.
- `swift test --filter playbackPlaylist`: all 13 focused tests passed.
- `swift test --filter subtitleFocus`: all 69 focused tests passed.
- `swift build`: passed.
- `swift test`: all 895 tests compiled and ran; the parallel run reported 14
  issues across 7 existing native-media timing, temporary-database action, and
  UI refresh-scope tests. Each failed test passed when rerun individually.
- `git diff --check`: passed before the final review.
