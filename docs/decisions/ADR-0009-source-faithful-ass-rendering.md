# ADR-0009: Libass Source-Faithful ASS Rendering

Status: Accepted

Updated: 2026-05-13

## Background

CueSeeker playback must render the selected source `.ass` file, or a cache
generated from that exact source identity. The SQLite search projection is only
for searchable text and cue timing; it is not a rendering authority.

The earlier version of this ADR selected a project-owned native ASS renderer as
the long-term direction, with `libass` retained as a selectable comparison path.
Real-world ASS behavior and font fallback compatibility now make that direction
too risky for the current product goal. In practice, `libass` is the factual
standard that mainstream players use for complex ASS subtitle rendering.

## Decision

CueSeeker will use the `libass`-backed source-faithful overlay as the only active
ASS playback renderer.

Rules:

- The active playback path must not expose a native ASS renderer mode.
- Settings must not expose an ASS renderer selector while only `libass` is
  supported.
- Native ASS renderer code must not be reachable from playback.
- ASS Lite may exist only as archived or test-only legacy code. It must not be a
  playback fallback for ASS rendering failures.
- ASS rendering failures must surface explicitly instead of silently routing to
  another renderer.
- Video open, seek, play, pause, and fullscreen controls must not wait for ASS
  renderer preparation.
- Large ASS optimization should preserve source-faithful render context through
  indexed render segments that are loaded by `libass`.
- The native app must not reintroduce `libmpv` as a playback backend to obtain
  ASS rendering behavior.

The active production flow is:

```text
Search result selection
Immediate native video open or seek
Asynchronous libass source or render-segment loading
Libass renders source-faithful subtitle surfaces
Subtitle surfaces composite over the displayed video rectangle
Renderer output catches up to the current playback clock
```

## Rationale

ASS compatibility is a specialized rendering problem. Correct handling of
`\pos`, `\move`, `\clip`, `\iclip`, `\p` vector drawing, blur, border, alpha,
karaoke, transforms, dense short-duration effects, and font fallback is too
large to solve reliably with a project-owned renderer in the current product
phase.

Using `libass` as the single active renderer reduces behavioral ambiguity. There
is one source of truth for ASS playback output, one failure path, and one
dependency surface to improve when system-font fallback or render-segment
loading need better support.

## Tradeoffs

- CueSeeker depends on a non-system renderer dependency for source-faithful ASS
  playback.
- Packaging, signing, notarization, license review, and font-provider behavior
  must account for `libass`.
- CueSeeker intentionally does not support player-compatible cases that require
  adjacent font folders, loose font files, or media-container font attachments.
  ASS playback uses system-installed fonts and platform fallback only.
- A project-owned native renderer no longer serves as a fallback if `libass`
  fails.

These tradeoffs are acceptable because a single `libass` renderer matches the
expected behavior of mainstream ASS playback better than maintaining parallel
renderers with different compatibility gaps.

## Alternatives Considered

### Continue Extending ASS Lite

Rejected. ASS Lite is not a credible path for source-faithful rendering of
dense effects, vector drawing, clipping, karaoke, transforms, or font fallback.

### Render From Database Cue Projection

Rejected. The database intentionally stores searchable text and timing
projection. It does not preserve enough source styling, override tags, drawing
commands, or timed effects to reconstruct source visuals.

### Reintroduce `libmpv`

Rejected. ADR-0007 selected native-only playback. ASS rendering work must not
reintroduce MPV as a production playback fallback.

### Maintain Native ASS As The Default Direction

Rejected. This was the previous ADR direction. It created two competing ASS
rendering semantics and made real-sample compatibility depend on a large
project-owned renderer before the product needed that complexity.

### Make `libass` The Only Renderer

Selected. It gives CueSeeker one ASS rendering authority and lets future work
focus on feeding `libass` the right source script, render segment, frame size,
system-font context, and playback clock.

## Implementation Notes

- Remove Settings renderer selection and persisted ASS renderer mode.
- Remove the native ASS playback route, parser, renderer, overlay, and tests.
- Keep `CASSRendering` and `SourceFaithfulASSSubtitleOverlayView` as the ASS
  playback path.
- Keep `ASSRenderSegmenter` and `ass_render_segments` as source-preserving
  `libass` performance optimizations.
- Update diagnostics such as `PlaybackSyncProbe` to report `libass` only.
- External font-resource plumbing is superseded by the strict local-file
  boundary in `docs/engineering/04_architecture_rules.md`. CueSeeker must not
  pass matched-video attachments, adjacent font directories, or app-owned font
  caches to the `libass` session.

## Verification Plan

Required checks:

- ASS playback routes to `SourceFaithfulASSSubtitleOverlayView`.
- Settings has no ASS renderer picker.
- Native ASS renderer code is not reachable from playback.
- Search result selection updates immediately, and video open or seek does not
  wait for ASS renderer loading or rendering.
- Subtitle visibility toggles the `libass` overlay without stopping playback.
- Complex ASS samples render from the source `.ass` file or the matching
  source-derived render segment.
- Font fallback behavior is checked with system-installed fonts and platform
  fallback only. Tests must not depend on adjacent font folders, extracted
  media-container font attachments, or app-owned font caches.

Automated tests should cover routing, non-blocking behavior, render-segment
cache boundaries, unchanged-frame reuse, and failure propagation. Manual testing
remains required for visual parity against real player output.
