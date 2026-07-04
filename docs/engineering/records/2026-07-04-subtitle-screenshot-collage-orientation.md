# Subtitle Screenshot Collage Orientation

## Requirement

- `docs/human/requirements/20260704-Bug-Subtitle Screenshot Collage Orientation.md`

## Scope

Fix SRT subtitle orientation and placement in Screenshot and Collage exports
without changing subtitle indexing, search, playback timing, ASS rendering, or
the existing save-panel flows.

## Steps

- Confirmed that the current human-owned requirement is committed before
  changing implementation files.
- Changed simple subtitle export layout so SRT text is drawn in the export
  bitmap's unflipped drawing space while the crop band remains a top-origin
  pixel range for collage extraction.
- Added an explicit bottom-anchored subtitle placement helper so future simple
  subtitle renderers do not need to reinterpret image coordinates locally.
- Added a pixel-level regression test that verifies SRT screenshot export keeps
  the source video orientation and places the subtitle band in the bottom part
  of the output image.

## Verification

- Passed: `swift test --package-path apps/macos-native --filter SubtitleScreenshotExporterTests`
- Passed: `git diff --check`
- Passed: `swift test --package-path apps/macos-native` with 7 XCTest tests
  and 375 Swift Testing tests.

## Outcome

SRT Screenshot and Collage export now share a single bottom-anchored placement
contract for simple subtitles, reducing the chance that future subtitle formats
repeat the same coordinate inversion bug.
