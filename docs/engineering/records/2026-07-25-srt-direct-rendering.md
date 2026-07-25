# SRT Direct Rendering

## Requirement

- `docs/human/requirements/20260725-Feature-SRT Direct Rendering And Deterministic Layout.md`

## Scope

Replace the SRT-to-ASS/libass presentation path with one direct
CoreText/CoreGraphics renderer while preserving the ASS pipeline and indexing
semantics.

## Implementation

1. Added playback-only SRT decoding and parsing for UTF-8, BOM-marked UTF-16,
   short physical cues, duplicates, and timestamp-line position parameters.
2. Added stable physical cue ordering and an interval-tree active-cue query.
3. Added one deterministic SRT layout and drawing core with video-height
   scaling, bottom anchoring, zero cue gap, stable overlap placement, inline
   text styles, and glyph-path stroke-then-fill drawing.
4. Added a dedicated playback overlay that reads and lays out SRT off the main
   actor, cancels replaced work, and redraws only when the active cue set
   changes.
5. Kept ASS sources isolated in the existing source-faithful libass overlay.
6. Routed Current Frame Screenshot through the immutable SRT image currently
   presented by the playback overlay.
7. Prepared each distinct SRT source once per screenshot or collage batch, then
   reused the same layout and drawing core at the exported video-frame size.
8. Removed the SRT-to-ASS converter, its libass branches and tests, and the old
   SwiftUI playback and screenshot text overlays.

## Verification

- `swift build --package-path apps/macos-native`
- `swift test --package-path apps/macos-native --filter 'SRTParserTests|PlaybackRequestTests'`
- `swift test --package-path apps/macos-native --filter 'SRTParserTests|PlaybackRequestTests|PlaybackCurrentFrameScreenshotTests|SubtitleScreenshotExporterTests|CASSRenderingProbeTests'`
  - 51 Swift Testing tests and 7 ASS XCTest tests passed.
- `swift test --package-path apps/macos-native`
  - All SRT, screenshot, export, and ASS tests passed.
  - Six unrelated media-timing, keyboard-action, and menu-timing tests were
    disrupted by concurrent full-suite resource contention.
- `swift test --package-path apps/macos-native --no-parallel --filter 'NativePlaybackMediaTimelineTests|playbackPlaylistCopyAndShioriTargetTheSettledPrimaryCue|subtitleTableShioriSubmenuStaysOpenAcrossDirectPointerTransfer'`
  - All 7 affected and associated tests passed when rerun serially.
- Generated 720p and 1080p Japanese subtitle images through the shared drawing
  core to inspect scale, bottom margin, zero-gap stacking, fill, and outline.

## Outcome

SRT playback and every screenshot/export entry now share one direct renderer;
none enters libass or creates an ASS script. The renderer uses a calibrated
44-point CoreText base size at a 720-high video canvas and scales all visual
metrics from the video canvas rather than the player window.
