# ADR-0009: Source-Faithful ASS Rendering

Status: Accepted

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

The accepted source-faithful ASS rendering proposal already states that
playback rendering must preserve timed source ASS events and that the source
`.ass` file or a cache generated from that exact source identity remains the
rendering authority.

## Decision

CueSeeker will implement source-faithful ASS playback through a dedicated ASS
renderer path, with `libass` as the preferred renderer dependency to evaluate
and integrate first.

The production direction is:

```text
Search result selection
Immediate native video open or seek
Asynchronous ASS renderer preparation
libass-backed rendering from the source .ass file
Alpha bitmap or texture compositing over the native playback surface
Renderer output catches up to the current playback clock
```

Rules:

- ASS Lite remains a simple readable-text fallback and regression-isolation
  path. It must not be treated as the fix for complex ASS effects.
- Complex ASS playback must use source ASS data, not database cue projection.
- Renderer failures must be exposed as explicit subtitle-rendering failures
  during development. Silent fallback to ASS Lite must not hide source-faithful
  rendering defects.
- Video open, seek, play, pause, and fullscreen controls must not wait for ASS
  renderer preparation.
- The first implementation step must validate the renderer outside the main UI
  path before integrating it into Playback Inspector or Theater Mode.
- The native app must not reintroduce `libmpv` as a playback backend to get ASS
  rendering behavior.

## Rationale

ASS compatibility is a specialized rendering problem. Correct handling of
`\pos`, `\move`, `\clip`, `\iclip`, `\p` vector drawing, blur, border, alpha,
karaoke, transforms, font fallback, and dense short-duration effects is too
large and too error-prone to rebuild incrementally on top of ASS Lite.

Using a dedicated renderer keeps the project-owned native video backend intact
while moving ASS rendering to a component designed for ASS semantics. It also
matches the project rule that playback rendering is source-file-owned while
search remains a readable-text projection.

## Tradeoffs

- `libass` adds a native dependency that affects build setup, packaging,
  signing, notarization, and license review.
- Font discovery and fallback behavior must be tested carefully on macOS.
- Renderer output must be composited into the existing playback render
  container without breaking Theater Mode lifecycle rules.
- The app must keep clear failure states while the renderer path is under
  development because silent fallback would hide defects.
- ASS Lite and the source-faithful path must have explicit ownership boundaries
  so the fallback does not become a second renderer implementation.

These tradeoffs are acceptable because ASS Lite cannot meet the product
requirement for complex ASS playback and because a dedicated renderer avoids
turning the app into a hand-written VSFilter/libass clone.

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

### Integrate `libass` Or Equivalent Dedicated Renderer

This is selected. `libass` is the preferred first renderer to evaluate because
it directly targets ASS rendering semantics and can produce overlay output that
the native app can composite over the video surface.

## Implementation Plan

1. Add a minimal `CASSRendering` native bridge or equivalent isolated target.
   This first step must not change the production playback UI.
2. Build a renderer probe or test harness that accepts:
   - source `.ass` URL,
   - video frame size,
   - playback timestamp,
   - optional font directory inputs when needed,
   and produces an RGBA image or equivalent alpha output.
3. Validate the probe against complex ASS samples before UI integration,
   including files with:
   - `\p` vector drawing,
   - `\clip` and `\iclip`,
   - `\pos` and `\move`,
   - `\fad`, alpha, blur, border, rotation, and transforms,
   - short-duration or zero-duration `Effect=fx` events,
   - signs and special-position text.
4. Introduce a real `ASSRenderCoordinator` for playback. It owns source
   identity, renderer preparation, cancellation, cache lookup, failure state,
   and current-time catch-up.
5. Add a `SubtitleOverlayHost` capable of presenting renderer bitmap, texture,
   or layer output over the native playback render container.
6. Keep Playback Inspector and Theater Mode using the same overlay lifecycle.
7. Keep ASS Lite available only as a simple fallback or diagnostic comparison
   path, not as the source-faithful renderer.

## Verification Plan

Required verification before the source-faithful path is considered usable:

- A complex ASS sample renders `\p` vector drawing without showing drawing
  commands as text.
- `\clip` and `\iclip` affect renderer output.
- `\pos` and `\move` place text at source-specified coordinates.
- Fades, alpha, blur, border, rotation, and transform-heavy events are visible
  when present in the source file.
- Dense short-duration effects do not block main UI interaction.
- Selecting an ASS search result updates selection and opens or seeks video
  before ASS renderer preparation finishes.
- Renderer failures are visible as subtitle-rendering failures and are not
  silently hidden by ASS Lite during development.

## Status Notes

- The source-faithful implementation plan lives in
  `docs/proposals/2026-05-source-faithful-ass-rendering-pipeline.md`.
- Product playback rules continue to live in
  `docs/product/06_playback_requirements.md`.
- Release documentation must be updated before a build containing `libass` is
  treated as a formal release.
