# Unify Recent UI — Step 4

## Requirement

- `docs/human/requirements/20260729-Feature-Workbench Playback And Command Panel Shared UI.md`
- Step 4: reuse the same Recent Videos and Recent Shioris components across
  Workbench preview, Workbench detail, and Playback Command Panel, with Command
  Panel Recent Videos using the video-card layout.

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
  its existing selection, keyboard, footer, and open behavior.
