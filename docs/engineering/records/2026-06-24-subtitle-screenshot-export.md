# Subtitle Screenshot Export

Human requirement:

- `docs/human/requirements/20260624-Feature-Subtitle-Screenshot-Export.md`

## Summary

Implemented Search and Shiori batch screenshot export actions backed by the
human-owned subtitle screenshot export requirement.

## Implementation

- Added a playback-owned `SubtitleScreenshotExporter` so video frame extraction,
  ASS source rendering, font alias rewriting, and long-image composition stay in
  the media/playback boundary.
- Added `Screenshot` and `Collage` buttons next to the existing selected-row
  `Anki` action in the Search and Shiori table utility bars.
- Preserved the requirement's visibility model: both buttons appear when any
  row is selected; `Collage` uses the disabled button style unless selected rows
  come from one standardized video path and the selection has at most 50 rows.
- Added save-panel flows for one screenshot, multiple screenshot folder export,
  and single collage PNG export.
- Added filename and collage eligibility tests for the exported screenshot
  naming rules and same-video limit.
- Follow-up: removed an extra CoreGraphics image flip during screenshot
  composition so video frames and ASS overlays preserve source orientation.
- Follow-up: changed filename cue timestamps to dot-separated `hh.mm.ss` /
  `mm.ss` formatting after the human requirement was refined.

## Verification

- Passed: `swift test --filter SubtitleScreenshotExporterTests`
