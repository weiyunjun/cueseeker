# SRT Playback Reload Latency

## Requirement

- `docs/human/requirements/20260731-Bug-SRT Playback Reload Latency.md`

## Classification

Playback execution performance fix. The change stays inside the existing
macOS `CueSeekerPlayback` direct-SRT renderer and does not change product
semantics, persistent data, ASS rendering, or the paused Rust shared-core
direction.

## Scope

Remove perceptible SRT preparation latency for first load and same-file Search
result switches while preserving deterministic SRT layout and the shared
playback, Screenshot, and Collage rendering core.

## Steps

1. Added an opt-in real-file benchmark that reports file read, playback parse,
   full layout, and representative image generation time without storing a
   local file path in the repository.
2. Measured a real Japanese SRT containing 323 Cues and 25,255 bytes. The
   pre-change result was 0.61 ms read, 5.02 ms parse, 115.85 ms layout, and
   9.02 ms image generation.
3. Reused loaded Cues and prepared layout when a playback request changes only
   the timestamp or preparation window for the same standardized SRT URL and
   unchanged video canvas.
4. Skipped unchanged visibility and canvas assignments, preventing same-file
   result switches from starting redundant layout and image work.
5. Added cooperative cancellation checkpoints to SRT loading and full layout
   so replaced tasks stop before completing obsolete work.
6. Changed inline-style construction from one attributed-string append and
   font lookup per character to one append per continuous style run.
7. Kept deterministic full-track Placement calculation but deferred glyph
   outline creation until a Cue is active and actually drawn.
8. Added opt-in playback performance probes for read, parse, layout, image
   generation, and main-actor completion delay.
9. Re-measured the same real SRT in the final code state. Full layout decreased
   to 26.39 ms while image generation remained 9.03 ms. Because image
   generation did not become a perceptible bottleneck, no additional
   background image lifecycle was added.

## Verification

- Passed the focused SRT reuse, cancellation, layout, and direct-overlay tests:
  6 tests.
- Passed the combined SRT parser, playback request, Current Frame Screenshot,
  Subtitle Screenshot/Collage, and ASS renderer regression selection:
  57 Swift Testing tests and 7 ASS XCTest tests.
- Passed the full serial suite with three unrelated known failures excluded:
  921 tests.
- The unfiltered 924-test serial run reported the pre-existing
  `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  suite-state failure and two subtitle-table right-click menu-position
  failures. The persistence test passed when rerun alone; both menu-position
  tests reproduced when rerun alone with the same 40-point discrepancy. None
  of these tests exercises files changed by this requirement.
- Confirmed by test counters that changing only the timestamp/preparation
  window for the same SRT and assigning the same canvas performs one source
  load and one layout; an actual canvas-size change rebuilds layout without
  reloading the source.
- `git diff --check` passed during implementation review.

## Outcome

The measured first-load preparation path for the representative 323-Cue SRT
decreased from approximately 130 ms to approximately 42 ms. Same-file Search
result switches now reuse the loaded track and layout instead of repeating the
full preparation path. Final acceptance remains the project owner's
end-to-end verification with real playback files.
