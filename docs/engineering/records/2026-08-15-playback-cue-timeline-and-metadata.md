# Requirement

- `docs/human/requirements/20260815-Feature-Playback Cue Timeline And Metadata.md`
- `docs/human/design/UI Design System.md`

# Scope

Replace Playback information Badges with one shared sequence, timeline marker,
and plain metadata presentation across Current, Cue Playlist, Command Panel
Search, and Editing Collage.

# Architecture

- The existing virtual Reel remains the only layout, selection, and scrolling
  owner. Its document draws the shared sequence lane, connectors, and marker
  around each adapter's existing Cue content.
- Existing text measurement records the Primary Cue first visual line's visible
  glyph center in each cached extent. Timeline placement consumes that scalar;
  it does not add a second text-layout pass, cache, or state owner.
- Sequence drawing reuses the existing visible-glyph text layout and targets
  that same center. Its nominal 32-point line box is not used for vertical
  alignment.
- Cue Result and Current adapters share one two-field metadata value and plain
  text renderer while retaining their existing specialized text measurement
  paths.
- Editing Collage uses the existing checkbox renderer as its timeline marker;
  no checkbox state or interaction owner was added.

# Steps

1. Added shared semantic color, typography, size, and spacing tokens for Cue
   sequence, timeline, and metadata presentation.
2. Replaced the Badge-array presentation model with Display Title and Time
   Range metadata rendered after the complete visible Cue stack.
3. Added a right-aligned proportional 24-point Semibold plain-ordinal lane.
   Its width is the maximum ordinal digit count multiplied by the shared
   16-point digit-width token, so it has no fixed digit limit.
4. Aligned sequence ink, dots, and the existing 24-point Collage checkbox to the
   measured Primary Cue first-line visible glyph center, used the shared
   24-point gap on both sides, and kept the 8-point connector gap around every
   marker.
5. Added a raster regression test that inspects the final sequence and marker
   pixels, alongside the layout, adapter, command-search, virtualization, and
   Collage coverage.

# Verification

- `swift test --filter 'playbackCueResult|playbackCurrent|playbackCueTimeline|editingCollage|playbackPlaylist|playbackCommandPanel'`
  passes all 46 focused Cue Result, Current, timeline, Collage, Playlist, and
  Command Panel tests.
- The new raster test failed before the sequence correction with a 13-pixel
  sequence-to-marker center difference, then passed after sequence drawing
  reused visible-glyph measurement.
- `swift build -c release --product CueSeeker` passes.
- Serial `swift test --no-parallel` ran 1,002 tests and reported three unrelated
  existing issues: one shared-default migration expectation polluted by the
  full run and two Shiori table timing waits. The migration test passed in the
  isolated rerun; the same two Shiori waits reproduced in isolation. None of
  the failures touches Playback Cue timeline code or its tests.
- `git diff --check` passes.
- Debug in-app E2E captured the actual `1433 × 821 @2x` WindowServer output for
  Current, a Shiori-origin Cue Playlist, and Editing Collage. Current and Cue
  Playlist each measured identical sequence, marker, and Primary Cue centers;
  Collage measured `852.0`, `852.0`, and `852.5` pixels respectively, within the
  one-physical-pixel acceptance tolerance.
- The existing Debug E2E controller cannot emit the backtick required to open
  Command Panel, so no separate Command Panel Search capture was fabricated and
  no new E2E capability was added. Cue Playlist exercised the same Cue Result
  measurement and shared sequence renderer, while the focused suite covered
  Command Panel Search behavior.

# Outcome

All four Playback Cue surfaces now reuse one timeline structure. Sequence
focus changes only color and do not move Cue content; sequence ink and marker
centers align to the Primary Cue's visible first-line glyph center. Marker-side
spacing is equal, sequence width grows from the dataset's digit count without
changing fonts, connector lines leave the specified gap, metadata contains only
Display Title and Time Range without Badge decoration, and Collage keeps its
existing checkbox behavior.

# Follow-ups

- After visual acceptance, the human owner will update and commit
  `docs/human/design/UI Design System.md` with the accepted tokens and component
  rules.
