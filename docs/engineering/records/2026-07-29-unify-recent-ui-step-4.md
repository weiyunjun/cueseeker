# Unify Recent UI — Step 4

## Requirement

- `docs/human/requirements/20260729-Feature-Workbench Playback And Command Panel Shared UI.md`
- Step 4: reuse the same Recent Videos and Recent Shioris components across
  Workbench preview, Workbench detail, and Playback Command Panel, with Command
  Panel Recent Videos using the video-card layout and four-direction visual
  Grid navigation.

## Scope

- Reused the existing adaptive Recent Watching card Grid for Workbench preview,
  Workbench detail, and Playback Command Panel Recent Videos.
- Removed the replaced Command Panel-only horizontal Recent Video Row.
- Added one shared Recent Shiori resume-row list and used it from Workbench
  preview, Workbench detail, and Playback Command Panel Recent Shioris.
- Mapped Command Panel's existing ordinal selection to stable item identities
  for shared selected visuals and scroll-to-selection behavior. The existing
  item counts, keyboard navigation, opening paths, and data owners were not
  changed.
- Updated the shared-host architecture rule and changelog. Human-owned
  documents, including `docs/human/design/UI.md`, were not modified.

## Verification

- `swift build`: passed.
- `swift test --filter playbackCommandPanel`: all 6 focused tests passed.
- `swift test`: all 892 tests compiled and ran; the parallel run reported 12
  issues across 5 existing native-media timing and refresh-scope tests.
- Each of those 5 full-run failures passed when rerun individually, confirming
  concurrent shared-resource or timing flakiness rather than a Step 4
  regression.
- `git diff --check`: passed before the final review.

## Outcome

- Step 4 matched the requirement. All requested Recent surfaces now share the
  same video-card and Shiori-row implementations, while Command Panel retains
  its existing selection source, item counts, and open behavior.

## Follow-up: Four-Direction Command Panel Navigation

- Kept Command Panel's existing ordinal as the only Recent Video selection
  state and added only a transient adaptive-column and visible-frame layout
  snapshot.
- Reused the existing Playback media-grid direction rule to resolve the nearest
  card in the requested visual direction. Left and Right no longer use the old
  list offset, Up and Down follow visual rows, and boundaries do not wrap.
- Updated the Recent Videos Footer to expose all four supported arrow keys.
- Kept the existing Enter action and scroll-to-selected identity path.

### Verification

- `swift build`: passed.
- The new four-direction Command Panel keyboard test passed.
- The existing shared visual-grid direction and scroll-target test passed.
- `swift test --filter playbackCommandPanel`: all 7 focused tests passed.
- `swift test`: all 893 tests compiled and ran; the parallel run reported 13
  issues across 7 existing folder-removal, Shiori-save, refresh-scope, and
  native-media timing tests.
- Each of those 7 full-run failures passed when rerun individually, confirming
  concurrent shared-resource or timing flakiness rather than a navigation
  regression.
