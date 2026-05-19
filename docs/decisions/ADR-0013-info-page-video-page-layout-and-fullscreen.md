# ADR 0013: Info-Page / Video-Page Layout and Fullscreen Strategy

## Status
Accepted

## Background
Playback is currently presented by swapping the workbench content for a
`PlaybackPageView` that lays out the video and a right sidebar in an `HStack`
where the sidebar squeezes the video stage. The workbench shell and the dynamic
sidebar share the main window's view tree with the live render view.

This co-residence is the root cause of fullscreen enter/exit jank. ADR-0010
established that playback fullscreen uses the main-window AppKit fullscreen
Space. ADR-0011 then added a repair sequence that forces render-layout
synchronization at every AppKit fullscreen lifecycle boundary, because the
surrounding workbench and squeezing sidebar relayout fights the fullscreen Space
animation. ADR-0011 is a mitigation of a structural problem, not a structural
fix.

## Decision
Refactor the app into two presentations:

1. An info page (Library / Search / Shiori).
2. A dedicated video page presented as an overlay layered **above a still-alive
   info page** (not a route swap). The video stage is the root content at a
   fixed size. The top bar and the side content are overlays above the video,
   never `HStack` siblings that resize it.

The video page has:

- A custom top bar with a centered video title and a left custom-drawn
  traffic-light cluster. Close returns to the info page (not quit); minimize
  miniaturizes the window to the Dock (native NSWindow miniaturize); maximize
  enters fullscreen. The custom top bar is windowed-only: in fullscreen it is
  hidden and the macOS native fullscreen titlebar takes over (native close +
  exit-fullscreen + centered video alias, no minimize); the native fullscreen
  close is intercepted to run the app close semantic (exit fullscreen + end
  playback + return to the originating info page) and never quits the app.
  The real NSWindow traffic lights are suppressed on the video page.
- An overlay middle panel that replaces the right sidebar and floats over the
  video without squeezing it.

This refactor is the structural resolution of the playback fullscreen jank. It
**absorbs and supersedes the ADR-0011 repair process**: with no workbench or
squeezing sidebar co-resident with the video, entering fullscreen is "hide the
top-bar overlay, let the video fill", which is essentially the native behavior
and removes the need for per-boundary render-layout synchronization.

## Rationale
- A dedicated video presentation whose root is the video stage means the
  fullscreen Space transition has nothing extra to re-lay-out, eliminating the
  jank at its source rather than synchronizing around it.
- Keeping the info page alive under the overlay preserves scroll, disclosure,
  lazy pages, and the Search cache without fragile manual state hoisting, and
  makes the "search on the video page, then view it on the info page" flow
  correct by construction.
- An overlay panel that does not resize the video stage protects the existing
  smooth seek and native render path, which must not be disturbed.
- The close-returns-to-info-page semantic is a deliberate UX tradeoff (analogous
  to Windows apps where close minimizes to tray); native window-close semantics
  would create worse UX problems for this single-window playback model.

## Tradeoffs
- Both the info-page and video-page view trees are mounted simultaneously. The
  cost is negligible because occluded SwiftUI lazy containers do not render and
  the data already lives in `AppState`. The known startup memory regression
  (~30 MB → 60–70 MB) is a separate incomplete cleanup, not a consequence of
  this decision.
- Custom-drawn traffic-light buttons must be kept visually and behaviorally
  reconciled with native window-button mechanics; this is explicitly a
  native-mechanics concern handled outside the HTML prototype.

## Alternatives considered
- Keep ADR-0011's per-boundary render-layout synchronization as the fullscreen
  fix. Rejected: it mitigates symptoms of the co-resident layout rather than
  removing the cause, and remains fragile.
- Implement the video page as a true route swap that destroys/rebuilds the info
  page. Rejected: it loses UI-local state, requires fragile state hoisting into
  `AppState`, and risks re-triggering Search first-screen/lazy/cache behavior
  that must be preserved.

## Relationship to ADR-0010 and ADR-0011
- ADR-0010 (main-window AppKit fullscreen Space) remains in force; this decision
  relies on it.
- ADR-0011's in-progress render-layout synchronization repair (commit
  `69861f2`) ceases to be an independent repair line. This refactor is the
  resolution; ADR-0011's acceptance criteria are expected to be met trivially by
  the new structure.
- ADR-0011 is now marked `Superseded by ADR-0013`. S5 converges the `69861f2`
  band-aid under the layered, measured, reversible, benchmark-honest protocol
  recorded in ADR-0011's "S5 Convergence Of The 69861f2 Render-Sync Band-Aid"
  section and the proposal's S5 measurement protocol: a pre-removal baseline is
  measured first; removal is least-deep-layer first; the native layer is removed
  only if layers 1–3 prove it redundant and only with explicit per-step user
  authorization; regression defaults to revert + documented result.
- S5 convergence completed 2026-05-19: all four band-aid layers were removed
  (S5.2 `c1a950a`, S5.3 `7ef3dbf`, S5.4 `9501254`), each functionally verified
  on the user's real machine with no obvious fullscreen regression; the
  `69861f2` normal-layout refactor was retained as the ordinary layout path.
  ADR-0011's repair line is closed; fullscreen correctness is now structural.
  Per-step memory measurement was deferred by project-owner decision (see the
  proposal's Memory Regression section).

## Consequences
- **Positive:** Near-native fullscreen behavior, simpler playback presentation,
  preserved info-page state, protected seek/render path.
- **Negative:** Requires the documentation-first sequence and HTML prototype
  v6 before App code; the startup memory regression must still be diagnosed and
  measured separately.

Stable conclusions here are reflected in
`docs/proposals/2026-05-ui-info-page-video-page-refactor.md` and will be merged
into the relevant product/engineering documents per the implementation order in
that proposal.
