# ADR-0009: Native Source-Faithful ASS Rendering

Status: Accepted

Updated: 2026-05-03

## Background

CueSeeker currently uses ASS Lite as an app-owned text overlay for `.ass`
playback. ASS Lite is useful for simple readable dialogue, but it is not a
source-faithful ASS renderer.

Real-world ASS files can contain tens of thousands of timed events, including
vector drawing, clipping, fades, alpha changes, blur, rotation, karaoke effects,
and short-duration `Effect=fx` events. These features are common in opening
themes, ending themes, signs, comments, and stylized on-screen text. They cannot
be faithfully reconstructed from the SQLite search projection or from a simple
`NSAttributedString` text overlay.

The accepted source-faithful ASS rendering proposal states that playback
rendering must preserve timed source ASS events and that the source `.ass` file
or a cache generated from that exact source identity remains the rendering
authority.

The same proposal now defines a project-owned native subtitle engine direction.
The first detailed phase is `v0` native text rendering for ordinary ASS
dialogue. Later native phases remain high-level and flexible because real ASS
coverage must be driven by user-provided samples, analysis scripts, visual
comparison, and user review rather than by a fixed static-versus-complex split.

## Decision

CueSeeker will implement ASS playback through a project-owned native subtitle
rendering pipeline.

The immediate implementation direction is native `v0`: a small, testable native
text core for ordinary ASS dialogue. The long-term product direction is a fully
self-owned native ASS rendering pipeline. Non-native renderer paths may remain
available during the transition for comparison, diagnostics, or user-selectable
fallback, but they are not the final architecture.

The production direction is:

```text
Search result selection
Immediate native video open or seek
Asynchronous native ASS source loading and render preparation
Native model built from the source .ass file
Native subtitle surfaces composited over the displayed video rectangle
Renderer output catches up to the current playback clock
```

Rules:

- ASS Lite remains a simple readable-text fallback and regression-isolation
  path. It must not be treated as the fix for complex ASS effects.
- A `libass`-backed path may remain as a legacy selectable renderer while the
  native engine matures, but new design discussion and implementation should
  default to the native renderer path.
- The final target is to keep only the native ASS rendering pipeline.
- Complex ASS playback must use source ASS data, not database cue projection.
- Renderer failures must be exposed as explicit subtitle-rendering failures
  during native renderer development. Silent fallback to ASS Lite or to a
  legacy renderer must not hide native renderer defects.
- Video open, seek, play, pause, and fullscreen controls must not wait for ASS
  renderer preparation.
- The first native implementation step is `v0` native text rendering for common
  ASS dialogue, not danmaku-specific behavior or full VSFilter compatibility.
- Native `v0` is not complete until ordinary dialogue visual alignment is
  credible for subtitle-context review, including source style sizing and the
  leading static size overrides documented in the implementation plan.
- The native app must not reintroduce `libmpv` as a playback backend to get ASS
  rendering behavior.

## Rationale

ASS compatibility is a specialized rendering problem. Correct handling of
`\pos`, `\move`, `\clip`, `\iclip`, `\p` vector drawing, blur, border, alpha,
karaoke, transforms, font fallback, and dense short-duration effects is too
large to solve by extending ASS Lite.

The project direction is to own this renderer rather than depend on an external
ASS semantic renderer as the endpoint. A native renderer keeps memory behavior,
surface ownership, playback integration, fullscreen behavior, and future
feature routing under CueSeeker control. It also matches the project rule that
playback rendering is source-file-owned while search remains a readable-text
projection.

Native `v0` deliberately starts with ordinary dialogue. This reduces risk while
establishing the parser model, active-event selection, layout surface ownership,
video-rectangle coordinate mapping, subtitle visibility behavior, and playback
clock integration that later native phases can extend.

## Tradeoffs

- A project-owned native renderer is a larger implementation effort than
  relying on `libass` as the final renderer.
- Full visual compatibility with complex ASS files will arrive through a long
  sample-driven exploration process rather than a fixed up-front tag checklist.
- Font discovery, fallback, and style interpretation must be tested carefully
  on macOS.
- Renderer output must be composited into the existing playback render
  container without breaking Theater Mode lifecycle rules.
- The app must keep clear failure states while the renderer path is under
  development because silent fallback would hide defects.
- ASS Lite, native `v0`, and any legacy `libass` path must have explicit
  ownership boundaries so fallback behavior does not obscure the native
  renderer's state.
- Legacy `libass` memory work must distinguish validated optimization
  directions from unvalidated ideas. The accepted legacy optimization evidence
  currently covers layer-contents presentation, cropped subtitle bitmap
  presentation, and the lifecycle-safe subset of explicit clear or stop
  recovery. Other optimization ideas need fresh measurement before adoption.
- If the legacy `libass` path is included in a release build, it still affects
  dependency bundling, signing, notarization, and license review.

These tradeoffs are acceptable because the final product goal is a native
renderer owned by CueSeeker, with legacy renderer paths removed once the native
pipeline is sufficient.

## Alternatives Considered

### Continue Extending ASS Lite

This is rejected for complex ASS rendering. It may handle additional simple
text cases, but it is not a credible path for dense `Effect=fx`, vector
drawing, clipping, karaoke, blur, alpha, and transform-heavy files.

### Render From Database Cue Projection

This is rejected. The database intentionally stores searchable text and
approximate layout metadata. It does not preserve enough raw override tags,
style state, drawing commands, or timed effects to reconstruct source visuals.

### Reintroduce `libmpv`

This is rejected. ADR-0007 selected native-only playback. ASS rendering work
must not reintroduce MPV as a production playback fallback.

### Keep `libass` As The Final Renderer

This is rejected as the final architecture. A `libass`-backed path may remain
temporarily selectable for diagnostics, comparison, or fallback while the native
engine matures, but it is not the long-term renderer direction.

### Build A Project-Owned Native Renderer

This is selected. The native renderer starts with `v0` ordinary ASS dialogue
and expands in later phases toward complete source-faithful ASS rendering.

## Implementation Plan

1. Implement native `v0` as the first renderer phase for ordinary ASS dialogue.
2. Parse source sections into native model types such as `NativeASSDocument`,
   `NativeASSStyle`, `NativeASSEvent`, and `NativeASSCue`.
3. Support source style font, size, color, basic outline, basic shadow,
   alignment, margins, layer, source order, raw text, cleaned text, and `\N`
   line breaks.
4. Select active events by playback timestamp and render small subtitle
   surfaces bounded by text layout instead of full-video transparent frames.
5. Composite native subtitle surfaces over the displayed video rectangle, not
   the full black playback container.
6. Keep search result selection, Playback Inspector visibility, video open,
   video seek, and playback controls independent from ASS parsing and rendering.
7. Keep current renderer selection behavior available during the transition, but
   design new renderer work around native mode.
8. Complete ordinary dialogue visual alignment inside Phase 1 by verifying ASS
   script-coordinate mapping, source style sizing, and leading `\fs`, `\fscx`,
   and `\fscy` size overrides against `legacy libass` and a reference player.
   Phase 1.1 must first document and verify native font fallback parity before
   further font-size calibration is accepted.
9. Treat Phase 2 as a user-led, real-sample ASS coverage exploration phase. The
   user provides representative samples, the AI analyzes their ASS syntax and
   rendering features, each feature is translated into human-readable behavior,
   and implementation scope is decided per cycle from that evidence.
10. Treat Phase 3 as the point where behavior not precisely solved in Phase 2
    receives an explicit compromise, omission, diagnostic, or temporary legacy
    routing policy.
11. Treat Phase 4 as performance, memory, and long-run stability work after the
    major visual behavior questions are understood.

## Verification Plan

Native ASS renderer acceptance is primarily manual. Real ASS subtitle files can
be very large and visually complex, and user-visible quality cannot be approved
by isolated automated tests alone.

Required `v0` manual acceptance before the native renderer is considered usable:

- Common ASS dialogue appears correctly enough for subtitle-context review.
- Ordinary dialogue size and placement are close enough to `legacy libass` and a
  reference player for common static dialogue samples.
- Leading `\fs`, `\fscx`, and `\fscy` overrides affect native `v0` ordinary
  dialogue sizing.
- Simple bilingual or multi-line subtitles remain readable.
- Unsupported override tags are stripped or omitted rather than shown as raw
  subtitle text.
- Subtitle output maps to the displayed video rectangle.
- Playback, seek, subtitle visibility toggling, Playback Inspector, and Theater
  Mode remain stable.
- Search result selection updates immediately, and video open or seek does not
  wait for native ASS parsing or rendering.
- Memory behavior is directionally better than full-frame subtitle presentation
  for ordinary dialogue.

Automated tests may still support parser, model, timing, cancellation, and
non-blocking behavior, but they are not the authority for native subtitle visual
acceptance.

## Status Notes

- The source-faithful implementation plan lives in
  `docs/proposals/2026-05-source-faithful-ass-rendering-pipeline.md`.
- Product playback rules continue to live in
  `docs/product/06_playback_requirements.md`.
- Release documentation must be updated before a build containing any non-system
  legacy ASS renderer dependency is treated as a formal release.
