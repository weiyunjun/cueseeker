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
4. Aligned dots and the existing 24-point Collage checkbox to the measured
   Primary Cue first-line visible glyph center, used the shared 24-point gap on
   both sides, and kept the 8-point connector gap around every marker.
5. Updated layout, adapter, command-search, virtualization, and Collage tests
   for fixed geometry and the new presentation contract.

# Verification

- `swift test --filter 'playbackCueResult|playbackCurrent|playbackCueTimeline|editingCollage|playbackPlaylist|playbackCommandPanel'`
  passes all 45 focused Cue Result, Current, timeline, Collage, Playlist, and
  Command Panel tests.
- The revised timeline layout test failed before implementation because the
  measured glyph-center offset, digit-width token, shared 24-point gap, and new
  row-layout input were absent, then passed after the geometry changes.
- `swift build -c release --product CueSeeker` passes.
- Serial `swift test --no-parallel` ran 1,002 tests and reported three unrelated
  existing issues: one shared-default migration expectation polluted by the
  full run and two Shiori table timing waits. The migration test passed in the
  isolated rerun; the same two Shiori waits reproduced in isolation. None of
  the failures touches Playback Cue timeline code or its tests.
- `git diff --check` passes.
- No additional Debug E2E input capability was required or added. Final visual
  acceptance remains a real-app check because token fine-tuning is explicitly
  deferred to owner review.

# Outcome

All four Playback Cue surfaces now reuse one timeline structure. Sequence
focus changes only color and do not move Cue content, marker centers align to
the Primary Cue's visible first-line glyph center, marker-side spacing is equal,
sequence width grows from the dataset's digit count without changing fonts,
connector lines leave the specified gap, metadata contains only Display Title
and Time Range without Badge decoration, and Collage keeps its existing
checkbox behavior.

# Follow-ups

- After visual acceptance, the human owner will update and commit
  `docs/human/design/UI Design System.md` with the accepted tokens and component
  rules.
