# Unify Library UI — Step 3

## Requirement

- `docs/human/requirements/20260729-Feature-Workbench Playback And Command Panel Shared UI.md`
- Step 3: unify Library level one with the Shiori Overview structure, and
  solidify the shared Workbench Library Detail and Playback Video Playlist.

## Scope

- Added shared Overview, adaptive Grid, Media Card content, and Media Card
  interaction primitives used directly by both Library and Shiori level one.
- Added Library Folder, Video, and Subtitle totals. Folder count follows the
  current displayed Library Folder summaries; each displayed Library Episode
  owns one matched video and subtitle, so both item totals use that same
  authoritative summary count.
- Added `Add Content` through the existing Settings window entry point, whose
  default category is Library.
- Kept one shared Episode list for Workbench Library Detail and Playback Video
  Playlist, with explicit Workbench and Playback modes for persistent selection
  and the existing `Context` capability difference.
- Preserved Playback's existing first-available Episode selection in its
  Session-local media selection store; Workbench still has no default Episode
  selection.
- Updated architecture, end-to-end verification, and changelog records.
  Human-owned documents, including `docs/human/design/UI.md`, were not modified.

## Verification

- `swift build`: passed.
- Focused Library/Playback/Shiori run: 10 tests passed.
- `swift test`: all 892 tests compiled and ran; the parallel run reported 8
  issues across 5 existing native-media timing, Shiori-save timing,
  refresh-scope, and folder-removal tests.
- Each of those 5 full-run failures passed when rerun individually, confirming
  concurrent shared-resource or timing flakiness rather than a Step 3
  regression.
- `git diff --check`: passed.

## Outcome

- Step 3 matched the requirement. Library and Shiori level one now share their
  Overview and Media Card structures, Library exposes its requested statistics
  and Settings entry point, and both Library Episode surfaces retain one shared
  implementation with explicit host selection differences.
