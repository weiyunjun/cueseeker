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

## Verification

- `swift build --package-path apps/macos-native`
- `swift test --package-path apps/macos-native --filter 'SRTParserTests|PlaybackRequestTests'`
- Generated 720p and 1080p Japanese subtitle images through the shared drawing
  core to inspect scale, bottom margin, zero-gap stacking, fill, and outline.

## Outcome

SRT playback no longer enters the ASS overlay. The direct renderer uses a
calibrated 44-point CoreText base size at a 720-high video canvas and scales all
visual metrics from the video canvas rather than the player window.
