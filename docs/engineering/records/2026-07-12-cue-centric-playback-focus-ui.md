# Cue-Centric Playback Subtitle Focus UI

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Cue-Centric Search Shiori Context Playback And Export.md`
- `docs/human/design/UI.md`

## Scope

Replace Playback Subtitle Focus's fixed-height Cue Group reel with the accepted
content-driven individual-Cue presentation. This phase changes only native
Focus measurement, virtual layout, motion, drawing, and scrollbar behavior;
the preceding Cue data/action phase remains the product-semantic owner.

## Classification

- Platform UI/UX: content-driven Cue measurement, accepted Focus Placement,
  local virtual drawing, wheel motion, and ordinal scrollbar interaction.
- Product semantics: unchanged. Stable Cue identity, ordering, loading,
  selection commits, and keyboard action payloads remain Core/session-owned.
- Playback execution: unchanged. Focus navigation does not seek or publish
  playback time; Space continues to use the settled Cue action handoff.

## Implementation

- Replaced the fixed 104-point Cue slot and 136-point pixel document with a
  fractional stable-Cue ordinal position and local native virtual layout.
- Added unlimited TextKit measurement using the complete Cue text, source line
  breaks, automatic wrapping, a fixed 52-point visual line height, and 12-point
  top and bottom padding. Natural Cue Height is `52L + 24`; Resolved Cue Height
  is clamped to the reel viewport.
- Centered every fitting selected Cue on the fixed screen-space Focus Anchor.
  An oversized selected Cue resolves to the viewport height, so the same center
  geometry places its top at zero and consistently restores head-first display.
- Interpolated fractional ordinals between neighboring accepted placements
  using `currentHeight / 2 + 8 + targetHeight / 2`.
- Resolved placements outward from the fractional target only until the visible
  viewport plus four-Cue overscan is covered. A 64-entry LRU measurement cache
  retains no full-document TextKit or height index.
- Changed precise wheel movement from fixed pitch to local content-dependent
  pixel distance. Keyboard and discrete wheel movement settle an integer Cue;
  precise wheel and scrollbar previews remain local until final settlement.
- Changed scrollbar value to fractional Cue ordinal and its thumb ratio to
  visible Cue-center capacity divided by total Cue count. The shared scrollbar
  primitive continues to enforce the 24-point minimum thumb length.
- Preserved stable selected Cue identity across width/viewport reflow and
  restored the accepted fitting-center or oversized-top placement.
- Added a native background pointer shield across the complete overlay so Cue,
  reel-empty, and top/bottom inset clicks are consumed without changing
  selection or actions. The native Reel remains above the shield, preserving
  wheel and scrollbar navigation.
- Removed fixed-pitch, cumulative pixel-document, two-line clipping, and
  forced-sub-pitch precise-wheel settlement code paths.

## Verification

### Refresh-scope probe

- Owner: `PlaybackSubtitleFocusOverlay`, its native Reel/Document, local Cue
  measurements, local fractional position, and Focus scrollbar presentation.
- Allowed invalidation: the overlay body/native update, local layout, visible
  Cue drawing, measurement-cache misses, local motion preview, selected-Cue
  settlement, and scrollbar thumb.
- Forbidden invalidation: Search/Shiori/Library/table snapshots, App chrome,
  high-frequency playback time, and the Playback render host. Focus navigation
  continues to avoid playback seek/time publication.
- `CUESEEKER_PERF_UI=1` now records Focus user actions for keyboard, discrete or
  precise wheel, scrollbar drag, and width/height reflow; it counts overlay
  body, native make/update, layout update, Cue measurement miss, and Cue draw.
  These events can be compared with the established `UI.ContentView.body`,
  `UI.Workbench.body`, table/library counters, `UI.PlaybackTime.published`, and
  the existing `PlaybackRenderHostView.layout` performance probe to verify
  forbidden owners remain unchanged.
- Automated tests prove width reflow preserves selected Cue identity and its
  accepted placement, active keyboard/wheel reflow publishes no selection, and
  callback-free local measurement/layout remains bounded.

- Focus tests cover 76/128/180-point one/two/three-line heights, hard and soft
  wrapping, CRLF and empty visual lines, Resolved height clamping, 84/110/162
  point adjacent placement distances, fractional interpolation, fitting-center
  and oversized-top placement, complete fitting-line drawing, resize identity,
  content-dependent precise wheel movement, ordinal scrollbar mapping, minimum
  thumb size, and one final scrollbar commit.
- A 50,000-Cue direct-target probe verifies that only the local visible plus
  overscan neighborhood is measured and that the measurement cache stays
  bounded. A second probe visits 100 distant targets and verifies both cached
  measurements and measurement instrumentation remain capped at 64 entries;
  a huge precise-wheel event is also bounded to its current local layout.
- A mounted AppKit hit-test probe covers the top inset, reel-empty area, Cue
  text, and bottom inset. Every click remains above an underlying sentinel and
  leaves Cue selection, fractional position, commits, and actions unchanged.
- `swift test --filter subtitleFocus` passed 63 focused Core, Session, action,
  geometry, rendering, motion, and lifecycle tests.
- `swift test` passed the complete package suite: 537 Swift Testing tests and
  7 XCTest tests, with 0 failures.
- `swift build` and `git diff --check` passed.

## Outcome

Playback Subtitle Focus now presents one complete, content-driven Cue at a
time, keeps fitting Cues centered, keeps oversized Cues head-first, and
navigates a bounded local virtual reel through fractional stable Cue ordinals.
