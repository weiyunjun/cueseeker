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
- Cue Result and Current adapters share one two-field metadata value and plain
  text renderer while retaining their existing specialized text measurement
  paths.
- Cue Result adapters expose the full sequence denominator separately from the
  resident item count. This preserves the complete Search count in Command
  Panel Search without putting position text into metadata.
- Editing Collage uses the existing checkbox renderer as its timeline marker;
  no checkbox state or interaction owner was added.

# Steps

1. Added shared semantic color, typography, size, and spacing tokens for Cue
   sequence, timeline, and metadata presentation.
2. Replaced the Badge-array presentation model with Display Title and Time
   Range metadata rendered after the complete visible Cue stack.
3. Added a fixed-width 24-point Semibold sequence lane, exact focused `x / y`
   text, one-based source ordinals, dots, and consecutive connector lines to
   the shared Reel document.
4. Reused the 24-point Collage checkbox in place of the dot and kept all new
   accessories inside the existing right-side Reel region.
5. Updated layout, adapter, command-search, virtualization, and Collage tests
   for fixed geometry and the new presentation contract.

# Verification

- `swift test --filter 'playbackCueResult|playbackCurrent|playbackCueTimeline|editingCollage|playbackPlaylist|playbackCommandPanel'`
  passes all 46 focused Cue Result, Current, timeline, Collage, Playlist, and
  Command Panel tests.
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
focus changes do not move Cue content, metadata contains only Display Title and
Time Range without Badge decoration, and Collage keeps its existing checkbox
behavior while gaining connector lines.

# Follow-ups

- After visual acceptance, the human owner will update and commit
  `docs/human/design/UI Design System.md` with the accepted tokens and component
  rules.
