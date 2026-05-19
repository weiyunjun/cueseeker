# ADR-0011: Playback Fullscreen Uses Main Window Presentation

Status: Superseded by ADR-0013

Supersedes: ADR-0010 dedicated playback fullscreen window

Superseded by: ADR-0013 info-page / video-page layout and fullscreen strategy.
ADR-0011's main-window video-only fullscreen contract still holds, but its
`69861f2` render-layout synchronization repair line is no longer an independent
repair: the S1–S4 structural refactor (dedicated full-window video page, overlay
panel that never resizes the video, info page no longer co-resident-squeezing)
removes the root cause ADR-0011 was band-aiding. The repair is being converged
in S5; see "S5 Convergence Of The 69861f2 Render-Sync Band-Aid" below.

Implementation status: Converging (S5). The fullscreen contract is implemented;
S5 verifies ADR-0011 acceptance now passes by structure and removes the
redundant render-sync band-aid under a measured, layered, reversible protocol.

## S5 Convergence Of The 69861f2 Render-Sync Band-Aid

The `69861f2` band-aid spans four layers, deepest last:

1. `PlaybackFullscreenManager` — `synchronizeFullscreenRenderLayout()` invoked at
   ~8 fullscreen lifecycle boundaries.
2. `PlaybackView` — `PlaybackRenderViewWrapper` token-driven `updateNSView`
   resync.
3. `PlaybackPlayer` — container frame-sync entry points.
4. `SFXNativePlaybackPlayer.m` (+ header) — native-side layout sync hook.

S5 convergence rules:

- ADR-0011 acceptance (this document's "Acceptance Focus" plus the proposal's
  Acceptance: no video freeze, no workbench relayout flash on enter/exit,
  `D`/`X` and seek shortcuts unchanged and smooth, cursor balance preserved) is
  the agreed benchmark.
- A pre-removal baseline must be checked first with the band-aid still in. Per
  the project-owner decision (2026-05-19), this baseline is **functional only**
  (no per-step memory measurement; memory diagnosis is deferred until the full
  UI refactor is complete — see the proposal's Memory Regression section). If
  functional acceptance fails even with the band-aid, the structural premise is
  disproven — stop and report; do not remove the band-aid. Resolved 2026-05-19:
  a rough functional run found no fullscreen problems.
- Removal proceeds layer by layer, least-deep first (1 → 2 → 3 → 4), each its
  own reversible commit with a real-machine before/after measurement.
- The native layer (4) is removed only if layers 1–3 measurably prove the
  band-aid redundant and only with explicit per-step user authorization, since
  it crosses the standing "do not touch the native render path" non-negotiable.
- Benchmark honesty: any regression defaults to reverting that layer and
  documenting the measured result. Keeping a still-needed layer requires an
  explicit documented reason, not silent reinterpretation.
- The measured fullscreen result is reported as an explicit observation; a
  green `swift test` is necessary but not sufficient because it does not cover
  the fullscreen GUI path.

Confirmed implementation contract:

- Playback fullscreen uses the main CueSeeker workbench window's AppKit native
  fullscreen lifecycle.
- Playback fullscreen must not create a second playback fullscreen `NSWindow`.
- The singleton playback render container remains in the main window hierarchy
  during fullscreen entry, active fullscreen, and fullscreen exit.
- The playback fullscreen presentation is video-first: the user should not see
  the normal workbench shell as the fullscreen experience.
- App switching while playback fullscreen is active should return the user to
  the fullscreen video presentation, not to a separate workbench window whose
  playback surface has been detached.
- Entering and exiting playback fullscreen should not freeze visible playback
  because of cross-window render-view movement.
- The first repair pass should focus on fullscreen windowing and presentation
  ownership before revisiting detailed player-UI chrome visibility rules.

Current implementation sequence:

1. Replace the playback fullscreen Bool combination with an explicit player
   fullscreen state machine. Acceptance: playback fullscreen has distinct
   windowed, entering-system-fullscreen, active-fullscreen, and
   exiting-system-fullscreen states; repeated `F`, fullscreen button, and Escape
   commands during entering or exiting are ignored instead of starting another
   transition; ordinary app fullscreen remains distinct from playback
   fullscreen; failed AppKit fullscreen callbacks return the manager to a known
   state.
2. Bind playback fullscreen presentation to AppKit's native fullscreen
   lifecycle. Acceptance: `toggleFullScreen` is the only standard-path system
   fullscreen entry or exit trigger; video-only presentation starts from AppKit
   will-enter callbacks and ordinary workbench presentation is restored only
   after did-exit callbacks; Cmd-Tab away and back returns to the fullscreen
   video presentation; no fixed guessed delay is used to finish fullscreen
   transition state.
3. Add native render-view fullscreen transition hooks without changing the
   playback decode pipeline. Acceptance: the singleton native playback render
   view and its display layer remain in the main window hierarchy; fullscreen
   entry, active fullscreen, and exit force native layout/frame synchronization;
   `flushAndRemoveImage` is not used as a fullscreen-transition workaround; if
   visible video still freezes while audio continues, the result is recorded as
   a display-layer issue rather than accepted fullscreen behavior.
4. Explore a rendering-layer replacement only if the state-machine and native
   layout fixes leave a reproducible transition freeze. Acceptance: the
   investigation compares the current `AVSampleBufferDisplayLayer` presentation
   path with a possible Metal/`CAMetalLayer` presentation path for decoded
   `CVPixelBuffer` frames; the investigation is documented before any renderer
   replacement is implemented; it does not imply replacing FFmpeg demuxing or
   VideoToolbox decoding.

## Background

ADR-0010 replaced the old borderless Theater Mode with a dedicated playback
`NSWindow` that enters AppKit Full Screen Space. That direction improved system
fullscreen integration compared with a manually simulated overlay, but it still
splits the app into two visible window identities during playback fullscreen:

```text
Main CueSeeker workbench window
Dedicated playback fullscreen window
```

That split creates user-visible problems. When the user switches away from a
fullscreen video, macOS can reveal the normal CueSeeker workbench window without
the video UI because the playback surface has moved into a separate fullscreen
window. Cursor hiding also becomes harder to reason about because fullscreen
chrome state belongs to the dedicated playback window while app activation
belongs to the whole app. The fullscreen transition can also freeze the visible
video presentation because the live native render view is moved between windows
immediately before AppKit performs a Space transition.

Mainstream macOS video experiences such as browser video fullscreen, QuickTime,
and IINA behave more like one player window entering a video-first fullscreen
presentation. The user does not see a separate empty app shell while fullscreen
video remains in another window.

## Decision

Playback fullscreen should use the main CueSeeker workbench window's native
fullscreen capability, then switch that same window into a video-only playback
presentation for the duration of playback fullscreen.

Rules:

- The standard playback fullscreen path must not create a second playback
  fullscreen `NSWindow`.
- The playback render container must not be moved across windows during
  fullscreen entry or exit.
- Playback fullscreen may put the main CueSeeker workbench window into AppKit
  Full Screen Space, but the visible presentation should be video-first and must
  not expose the normal workbench shell as the fullscreen experience.
- The workbench UI, panel state, search state, selection state, sidebar position,
  panel widths, scroll positions, and focus state should be preserved while the
  video-only presentation is active.
- Exiting playback fullscreen should restore the prior workbench presentation
  without rebuilding unrelated Library, Search, or Shiori rows.
- App fullscreen and playback fullscreen must be represented as distinct states:
  the green traffic-light button or system View fullscreen command may request
  ordinary app fullscreen, while the playback fullscreen command requests
  video-only playback presentation.
- If playback fullscreen starts while the main window is already in ordinary app
  fullscreen, CueSeeker should enter video-only playback presentation inside the
  existing fullscreen Space instead of creating another window.
- If ordinary app fullscreen starts while playback fullscreen is active, the
  playback fullscreen state remains authoritative until the user exits playback
  fullscreen.
- Cursor hiding and fullscreen chrome visibility are still owned by the playback
  fullscreen manager, but cursor hide/unhide calls must be balanced across
  entry, exit, app deactivation, app reactivation, and failed transitions.
- Playback close while playback fullscreen is active must first leave the
  video-only fullscreen presentation, or perform the fullscreen exit as part of
  the same close command, then stop the current playback session. Close must not
  leave the user in fullscreen with no active video.
- App switching while playback fullscreen is active should rely on AppKit's
  normal fullscreen Space behavior and must not reveal a separate CueSeeker
  workbench window that has lost its video surface.
- If custom fullscreen animation is later required, it should use AppKit's
  fullscreen delegate callbacks and the system-provided duration.

## Rationale

This aligns CueSeeker with professional player behavior while keeping AppKit in
charge of the system fullscreen Space. The user experiences one app window
becoming a playback-focused fullscreen surface, not a second playback window
separated from the workbench.

Keeping the render container in the same window hierarchy avoids the riskiest
part of the ADR-0010 path: moving a live native video presentation surface across
windows immediately before a fullscreen Space animation. If fullscreen animation
still freezes video after this change, the remaining problem should be diagnosed
inside the native display layer, main-queue frame submission, or AppKit layer
commit behavior rather than in window ownership.

The product-level promise remains that playback fullscreen is about the video
experience, not turning the workbench into a general fullscreen workspace. The
implementation may use the main window at the system level, but it must present a
video-only playback mode and restore the workbench afterward.

## Tradeoffs

- CueSeeker must now distinguish ordinary app fullscreen from playback
  fullscreen. The state machine is more explicit and must handle green-button,
  menu, keyboard, Escape, Cmd-Tab, and close-window paths.
- Workbench presentation must be hidden without losing state. Conditional
  teardown of SwiftUI workbench views would risk losing scroll positions,
  selection, panel state, and focus.
- Future UI redesigns must respect the playback fullscreen presentation layer
  instead of assuming fullscreen is a separate playback window.
- Some AppKit fullscreen animation stutter may remain because the system
  fullscreen transition is still controlled by macOS.

## Risk Register

The implementation should be treated as a windowing and presentation change, not
as a narrow playback button change.

Known risks:

- Custom app titlebar and traffic-light positioning can regress when the main
  window enters playback fullscreen. The normal window, ordinary app fullscreen,
  and playback fullscreen states must each restore titlebar visibility and button
  placement correctly.
- The green traffic-light button, system View fullscreen command, playback
  fullscreen button, `F` shortcut, and Escape path can conflict if ordinary app
  fullscreen and playback fullscreen share ambiguous state.
- Shared Content Panel, Mode Rail, sidebar-position, and Playback Area resize
  animations can be accidentally triggered by playback fullscreen. Playback
  fullscreen should not look like a side-panel collapse animation.
- SwiftUI conditional rendering can destroy the workbench subtree if fullscreen
  swaps the entire root view. That would risk losing Library expansion state,
  Search and Shiori scroll positions, selected rows, focus state, hover state,
  and panel widths.
- Titlebar safe-area handling can leave a top gap, crop the video, or push
  fullscreen overlays away from the screen edge.
- Embedded playback controls, fullscreen controls, subtitle overlays, and
  feedback overlays can accidentally render in duplicate or remain visible behind
  the video-only presentation.
- Cursor hiding can remain unbalanced across Cmd-Tab, app deactivation,
  reactivation, failed fullscreen transitions, repeated `F`, repeated Escape, and
  window close.
- Removing cross-window render-view movement should reduce video freeze risk, but
  AppKit fullscreen animation, `AVSampleBufferDisplayLayer`, main-queue frame
  submission, or layer commits may still produce animation-time stutter.
- Future broad UI redesigns can invalidate assumptions in the playback
  fullscreen presentation layer. The fullscreen state model should be kept
  narrow and explicit before larger UI work resumes.

## Future Technical Exploration

The accepted repair path remains a fullscreen state-machine and presentation
ownership change first. It should not be treated as a playback decoder rewrite.

CueSeeker's current native playback path demuxes and decodes video before the
display layer presents frames. A future Metal/`CAMetalLayer` exploration would
replace only the final presentation layer: decoded `CVPixelBuffer` frames would
be rendered into a GPU-backed Metal layer instead of being wrapped into
`CMSampleBuffer` values and enqueued into `AVSampleBufferDisplayLayer`.

This exploration becomes relevant only if:

- the playback fullscreen state machine is explicit and stable;
- the render container remains in the main window hierarchy through AppKit
  fullscreen entry and exit;
- native layout hooks prove that the display layer frame is synchronized before,
  during, and after the transition; and
- video still visibly freezes during fullscreen transition while audio continues.

The purpose of that exploration would be to evaluate display-layer control,
resize/fullscreen synchronization, black-background ownership, and future
subtitle composition. It must not silently change the selected decode strategy.

## Acceptance Focus

When implementation resumes, acceptance must include the existing normal
workbench UI in addition to the fullscreen video path.

Required acceptance focus:

- Normal window mode still shows the custom app top bar, traffic lights, Mode
  Rail, Shared Content Panel, and Playback Area in their pre-change positions.
- Ordinary app fullscreen from the green traffic-light button or system View
  fullscreen command does not enter video-only playback fullscreen.
- Playback fullscreen hides the normal workbench shell without destroying
  workbench state.
- Playback fullscreen does not trigger ordinary side-panel open, close, or resize
  animations.
- Exiting playback fullscreen restores traffic lights, titlebar presentation,
  panel width, active panel mode, selection, scroll position, and playback state.
- Fullscreen controls, embedded controls, subtitles, and feedback overlays do not
  duplicate or remain behind the wrong presentation.
- Cmd-Tab away and back restores cursor visibility and does not reveal a separate
  CueSeeker workbench window that lost its video surface.
- Repeated `F`, Escape, fullscreen button clicks, titlebar double-click zoom, and
  green-button interactions do not leave the app in a half-fullscreen state.
- The video-stage Close command exits playback fullscreen and ends playback,
  while the fullscreen exit command only returns to embedded playback.
- Video should continue animating through fullscreen entry and exit. Any remaining
  freeze should be classified as native presentation-layer work, not as accepted
  fullscreen behavior.

## Alternatives Considered

### Keep ADR-0010 Dedicated Playback Window

Rejected. It keeps the main workbench out of system fullscreen, but exposes a
split-window model that does not match mainstream player behavior. It can leave
the user looking at a CueSeeker workbench window with no video UI after app
switching, and it increases the chance of video presentation freeze by moving
the render container across windows during fullscreen entry and exit.

### Return To Borderless Theater Mode

Rejected. It avoids AppKit's fullscreen Space transition, but it requires
CueSeeker to emulate Dock, menu bar, Spaces, app switching, and system overlay
behavior. That was the maintenance burden ADR-0010 correctly removed.

### Use AVPlayerView Fullscreen Directly

Rejected for the current playback stack. CueSeeker owns a project native backend
with FFmpeg demuxing, selectable decode mode, `AVSampleBufferDisplayLayer`
presentation, app-owned controls, and source-faithful ASS overlay rendering.
Replacing that with `AVPlayerView` would be a playback-engine decision, not only
a fullscreen presentation decision.

## Consequences

- ADR-0010 remains historical context but no longer defines the active playback
  fullscreen mechanism.
- Product and engineering documents should describe playback fullscreen as a
  main-window video-only presentation using AppKit native fullscreen behavior.
- The current implementation may remain on the ADR-0010 dedicated-window path
  until playback fullscreen implementation is explicitly restarted.
- Implementation should first update fullscreen state modeling, then replace the
  dedicated playback window path, then verify cursor behavior, app switching, and
  video animation smoothness.
