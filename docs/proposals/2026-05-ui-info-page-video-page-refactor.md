# UI/UX Refactor: Info Page + Dedicated Video Page

Status: Accepted

## Background

The current playback UX is a full overlay swap inside `SearchView`:
`mainContent` (Library/Search/Shiori) is replaced by `PlaybackPageView`, which
lays out video plus a right sidebar in an `HStack` where the sidebar **squeezes**
the video stage (`stageWidth = totalWidth - sidebarWidth`). The workbench shell
(custom topbar, repositioned native traffic lights, info panels) and the dynamic
sidebar share the main window's view tree with the live render view.

This is the root cause of fullscreen enter/exit jank. ADR-0011 has been
band-aiding it by forcing render-layout synchronization at every AppKit
fullscreen lifecycle boundary, precisely because the surrounding workbench and
sidebar relayout fights the fullscreen Space animation.

The structural fix is to make the video page a dedicated presentation whose
video stage is the root content, with the top bar and side content layered
**above** it as overlays (not `HStack` siblings). Entering fullscreen then
becomes "hide the top-bar overlay, let the video fill" — nothing remains to be
re-laid-out, which is essentially the native solution. This refactor therefore
**is** the fullscreen-jank fix, not merely UX polish.

Seek smoothness (immediate UI feedback plus native ffmpeg keyframe seek, no
layout thrash) is good and is a non-negotiable invariant: the seek and native
render path must not be touched. The overlay-not-squeeze choice is what protects
it — toggling the panel must never resize the video stage.

This refactor continues the already-staged visual rebuild defined by
`2026-05-native-app-ui-ux-rewrite-plan.md`; it does not start from scratch.

## Relationship To `2026-05-native-app-ui-ux-rewrite-plan.md`

This document amends and partially supersedes the accepted native UI/UX rewrite
plan. It is not an unrelated proposal.

Inherits (unchanged discipline):

- Replacement rewrite, not patching; delete the old path before rebuilding.
- Non-UI behavior preserved: playback backend, subtitle render, Search
  cache/ranking/lazy/first-screen, Library history, Shiori persistence.
- HTML prototype and mapping documents are the source of truth; `swift test`
  must pass.
- Settings is excluded from this work.

Supersedes (design changes):

- Rewrite-plan Phase 2 acceptance "Close capsule anchored to the video frame"
  and "Player UI means bottom chrome plus the Close capsule" — the **Close
  capsule is removed**; close moves to the new top-bar red button and means
  "return to the info page", not quit.
- Rewrite-plan Phase 4 "rebuild the *right* sidebar that squeezes the video"
  and `docs/product/12_liquid_glass_ux_mapping.md` §10.1 — replaced by an
  **overlay middle panel that floats over the video and does not squeeze it**.
- Net-new: a **video-page top bar** (three traffic-light buttons plus a centered
  video title), absent from the rewrite plan and the mapping documents.
- Rewrite-plan Phase 3 chrome auto-hide acceptance and doc 12 §10.4 — superseded
  and extended by the Player-UI / cursor visibility state machine (v4) below.

Does not supersede: backend/Search/Library/Shiori logic decisions, the playback
engine and ASS ADRs, and the non-affected sections of the Liquid Glass mapping
documents.

## Goals

- Collapse the app into two presentations: an info page and a dedicated video
  page, so fullscreen becomes a near-native operation.
- Make the playback side content an overlay that never resizes the video stage.
- Add a custom video-page top bar with app-semantic traffic-light controls.
- Finish the rewrite plan's Phase 1 code-structure gate so the startup memory
  regression is removed.

## Non-goals

- Do not change Search ranking, query parsing, cache semantics, lazy loading, or
  first-screen rendering.
- Do not change the database schema, subtitle parsing, or the playback backend.
- Do not touch the seek or native render path.
- Do not redesign Settings.
- Do not finalize the overlay middle panel's detailed interaction rules in this
  document; that design is still embryonic and is intentionally deferred.

## Target Architecture

Two presentations:

1. Info page — Library / Search / Shiori, accessed as today via the topbar mode
   buttons. Its state stays alive while the video page is shown.
2. Video page — a dedicated presentation **layered as an overlay above the
   still-alive info page** (consistent with the existing
   `isPlaybackSurfaceExpanded` model), not a route swap. Keeping the info page
   alive preserves scroll, disclosure, lazy pages, and the Search cache without
   fragile manual state hoisting, and makes the "search on the video page, then
   view it on the info page" flow correct by construction. The memory cost of
   keeping it mounted is negligible; the startup regression is the separate
   Phase 1 cleanup, not this.

The video page is composed of:

- Video stage as root content, fixed size, never resized by the panel.
- Custom top bar: a centered video title and a left custom-drawn traffic-light
  cluster. Close returns to the info page (a deliberate accepted tradeoff,
  analogous to Windows apps where close minimizes to tray); minimize
  miniaturizes the window to the Dock (native NSWindow miniaturize); maximize
  enters fullscreen. The custom top bar is shown only in windowed mode; in
  fullscreen it is hidden and the macOS native fullscreen titlebar (auto-shown
  on top-edge hover) takes over, showing native close + exit-fullscreen and the
  centered video alias, with no minimize control. The native fullscreen close
  is intercepted so it performs the app close semantic (exit fullscreen + stop
  playback + return to the originating info page) and never quits the app.
  The real NSWindow traffic lights are
  hidden/suppressed on the video page so they do not conflict with
  `AppDelegate.WindowButtonsProxyView` / `adjustTrafficLights()`. This is a
  native-mechanics concern handled outside the HTML prototype.
- Overlay middle panel replacing the right sidebar: floats over the video and
  does not squeeze it. It hosts the existing Search Results / Subtitles content
  (logic intact; the views were removed by the rewrite plan's Phase 1 delete
  gate). Visibility is driven by the bottom-bar three-line button. The panel
  never auto-hides; it closes only via that button. Clicking a row during
  playback seeks to it. The panel is **not** part of "Player UI" and its
  visibility is independent of the state machine below.

## Player-UI / Cursor Visibility State Machine (v4)

v4 supersedes v3 by separating Player UI state from cursor state, defining
player focus separately from App focus, and defining when the current player is
allowed to decide cursor visibility.

Definitions:

1. Player UI: the bottom player plus the video-page top bar.
2. Player area: the video window area while the playback page exists.
3. Player has focus: the current effective interaction target still belongs to
   the player. Settings, independent windows, system dialogs, and future
   non-player interfaces that receive interaction are player-focus loss even
   when CueSeeker remains the foreground App. Playback-page-owned menus and
   popovers do not count as player-focus loss.
4. Player UI state:
   1. Player UI visible: the player area exists and Player UI is shown.
   2. Player UI hidden: the player area exists and Player UI is not shown.
5. Cursor state:
   1. Cursor visible: the player area exists and the cursor is shown.
   2. Cursor hidden: the player area exists and the cursor is not shown.
6. Cursor governed by the current player: the player area exists, the physical
   cursor position is inside the player area, and the player has focus.

Core rules:

7. When the cursor is governed by the current player, mouse movement puts the
   cursor in the visible state.
8. Initialization: entering the playback page puts Player UI and cursor in the
   visible state.
9. Fullscreen special case: entering fullscreen forces Player UI and cursor to
   the hidden state.
10. When Player UI is visible:
    1. If the cursor is governed by the current player and then moves out of
       the player area, Player UI switches to hidden.
    2. If the cursor is governed by the current player and has not moved for
       three seconds, Player UI switches to hidden.
    3. If the player loses focus, Player UI switches to hidden.
11. When Player UI is hidden, Player UI switches to visible only when the
    cursor is governed by the current player and the cursor moves.
12. When the cursor is visible:
    1. If the cursor is governed by the current player and then moves out of
       the player area, final cursor visibility is decided by other rules.
    2. If the cursor is governed by the current player and has not moved for
       three seconds, the cursor switches to hidden.
    3. If the player loses focus, this state machine performs no additional
       cursor action; final cursor visibility is decided by other rules.
13. When the cursor is hidden, if the cursor is governed by the current player
    and moves, the cursor switches to visible.
14. When the cursor is not governed by the current player, the current player
    no longer decides cursor visibility. Final cursor visibility is decided by
    whichever other rule owns it.

Supplementary rules:

15. Visibility transitions are primarily driven by mouse movement. Mouse
    movement means physical pointer position changes, including ordinary
    movement and dragging while any mouse button is held. Mouse clicks, mouse
    button down/up events without pointer-position changes, and keyboard input
    do not count as movement.
16. Player UI and cursor state transitions do not animate.

Implementation notes:

- Player focus is an explicit player interaction-focus state, not simply
  `NSApplication` active state or `NSWindow.isKeyWindow`.
- Cursor governance is evaluated from the live cursor location and player
  focus at each decision point. The playback page must not assume that cursor
  visibility becomes visible merely because the current player stopped
  governing it.
- Entering / leaving the player area and ordinary in-area movement come from a
  single authoritative `NSTrackingArea` on a full-bleed overlay view that is
  transparent to hit-testing (it never intercepts clicks/drag). Its
  `mouseEntered` updates player-area governance but is not treated as real
  movement because layout/fullscreen changes can emit enter events without
  physical pointer motion. `mouseMoved` is the ordinary governed movement signal
  and `mouseExited` drives "moved to another area" (rule 10.1). Dragged movement
  (`leftMouseDragged`, `rightMouseDragged`, and `otherMouseDragged`) is also
  governed movement when the live cursor remains governed by the current player,
  because AppKit sends drag events to the original press target rather than
  reliably through the tracking overlay. `NSEvent` global/local mouse-move
  monitors and SwiftUI hover are not reliable substitutes for enter/exit/ordinary
  movement tracking. Layout/fullscreen/focus changes do not produce real pointer
  movement, so they never count as movement. Exiting fullscreen does not change
  state.

## Memory Regression

Startup RSS regressed from approximately 30 MB to 60–70 MB. The likely cause is
that the rewrite plan's Phase 1 delete gate was not completed cleanly, so old UI
code, retained observers, or stale view trees coexist with the new code.
Approximately 30 MB is the baseline metric.

Sequencing (revised): a dedicated mid-stream "fix the memory regression" step is
mis-placed because the suspected source is the old playback/video path that
S1–S5 rebuild (so much of the bloat should be reclaimed as a side effect), and
because the info-page card-visual rebuild (rewrite-plan Phase 5) is a separate
later stage whose memory contribution is unknown. Therefore:

- Record the ~30 MB baseline (idle / not-playing is the normal state for that
  figure) and the current 60–70 MB band; the S5.1 functional-baseline point
  read ≈73.6 MB phys_footprint. Measurement metric: `phys_footprint` (Activity
  Monitor "Memory" column / `footprint`) as primary, with RSS and Shared as
  context; `ps -o rss=` is the inflated RSS and is not the primary number.
- Per explicit project-owner decision (2026-05-19): per-step S1–S5 RSS
  re-measurement is **deferred** until the full UI refactor is complete.
  Rationale documented per git-workflow §10 (explicit owner approval plus a
  reason separate from any performance goal): mid-refactor numbers are
  confounded by many unrelated factors, and optimizing memory/CPU before the UI
  is fully rebuilt is premature and likely wasted effort. This is a sequencing
  deferral, not acceptance of any regression.
- S5.1 is therefore reduced to a **functional acceptance gate only** (fullscreen
  enter/exit, shortcuts, panel/v4 independence); memory is not a gate at this
  step. A rough functional run on 2026-05-19 found no functional fullscreen
  problems, so the structural premise is supported and S5 proceeds.
- Do the actual memory diagnosis and residual cleanup once the UI refactor is
  complete (at S7 and again after the separate info-page Phase 5 rebuild),
  reporting the measured phys_footprint as an explicit number; no unapproved
  mitigation may be silently layered on. App-wide memory acceptance remains
  deferred until info-page Phase 5 is also done and measured.

## HTML Prototype Change List (v6)

1. Move the right sidebar to a centered overlay over the video; do not change
   the panel's internal content yet. Visibility driven by the bottom-bar
   three-line button; the panel never auto-hides; keep the click-row → seek
   behavior. Detailed panel rules are deferred; keep this minimal.
2. Remove the video-page Close button.
3. Add the video-page top bar: three traffic-light buttons plus a centered video
   title.
4. Other necessary changes implied by the new top bar and removed Close (for
   example fullscreen control adjustments).
5. Top/bottom bar show/hide behavior follows the state machine (v4) above.

## Implementation Order

Documentation-first, per `docs/engineering/02_git_workflow.md` §10,
`docs/engineering/01_documentation_rules.md` §11, and
`docs/product/10_ui_collaboration_workflow.md`:

1. This document (and ADR-0013) — committed first.
2. HTML prototype `ui/prototypes/cueseeker-liquid-glass-v6/` covering the info
   page, the video page (custom top bar plus overlay panel), transitions, panel
   show/hide, and close/minimize/fullscreen states; iterate to visual alignment.
3. Update `docs/product/11_liquid_glass_component_mapping.md` for the new
   top-bar / overlay component classes and SwiftUI owners.
4. Update `docs/product/12_liquid_glass_ux_mapping.md` (supersede §10.1 and
   §10.4, add top-bar semantics, state routing, fullscreen behavior).
5. Update `docs/product/04_ux_interaction.md` for info ↔ video navigation, the
   return target, and key-handling continuity.
6. Re-verify `docs/engineering/04_architecture_rules.md` §7 (invalidation
   domains stay separate; product semantics stay out of views).
7. Obtain explicit App-implementation approval (separate from prototype
   approval).
8. Implement per the App Implementation Steps (S1–S7) below, then update
   `docs/changelog.md` on completion.

Phasing of the App work:

- Phase 1 — Structural: two presentations; custom top-bar buttons and their
  semantics; overlay panel shell replacing the squeeze sidebar; restore the
  Search Results / Subtitles content. No new search UX.
- Phase 2 — In-page quick search: a search box in the overlay → Enter → choose
  "play immediately" or "open the Search page" without leaving the video page.
  Must call the existing Search service in `AppState`, not reimplement search in
  the view.
- Phase 3 — Subtitle-driven search/play: select subtitle text in the panel →
  search → play.

## App Implementation Steps (S1–S7)

These steps implement Phase 1 (structural) only. Phase 2 and Phase 3 are out of
scope and will be planned separately.

Scope: this implementation is the **video page**. The info-page card-visual
rebuild (rewrite-plan Phase 5: Search/Library/Shiori cards) is a **separate
later stage** and is not part of these steps. The only info-page-adjacent change
here is S1 structural wiring (keep the info page alive, hide its toolbar on the
video page, remember the originating mode); it is not an info-page visual
change.

Non-negotiables for every step: `swift test` stays green; do not touch the seek
or native render path (`PlaybackViewModel.performSeek`, `PlaybackView` render
wrapper, `PlaybackRenderHostView`, native player); product semantics stay out of
views; each step is its own commit and reports before/after short hashes.

- **S1 — Presentation split + navigation/return target.** AppState remembers the
  originating info-page mode; the video page is a dedicated full-window
  presentation layered above a still-alive info page (not destroyed); hide
  `AppTopBar`/`.toolbar` while the video page is shown; close returns to the
  originating mode with state intact. No new visuals. Files: `AppState.swift`,
  `SearchView.swift`, `ContentView.swift`. Risk: medium. Verify: open/close
  returns to the correct mode; info-page state preserved.
- **S2 — Custom video-page top bar.** New `VideoTopBar` (centered title +
  custom-drawn traffic-light cluster: red = return to info page, yellow =
  minimize (native NSWindow miniaturize to the Dock), green = fullscreen);
  the custom top bar is windowed-only — in fullscreen it is hidden and the
  native macOS fullscreen titlebar takes over (see doc 12 §12);
  remove the old video-frame Close capsule;
  suppress the native NSWindow traffic lights on the video page (coordinate with
  `AppDelegate.WindowButtonsProxyView` / `adjustTrafficLights()`); the top bar
  is Player UI. Risk: medium-high. Verify visually against prototype v6.
- **S3 — Player-UI / cursor visibility state machine (v4).** Implement the v4
  state machine per doc 12 §10.4. A single explicit model owns Player UI state,
  cursor state, player focus, and cursor governance; the dead/competing
  chrome+cursor code in
  `PlaybackFullscreenManager` is removed. Player-area enter/leave and in-area
  movement come from a single authoritative `NSTrackingArea` on a
  hit-test-transparent full-bleed overlay (not `NSEvent` monitors and not
  SwiftUI hover, which are unreliable across embedded subviews / menu-bar /
  Dock / desktop), so layout/fullscreen/focus changes never count as movement.
  Player focus is not App focus or key-window state alone: Settings,
  independent windows, system dialogs, and future non-player interfaces count
  as player-focus loss when they receive interaction, while playback-page-owned
  menus/popovers do not. Cursor visibility is decided by the current player
  only while the cursor is governed by that player; after governance is lost,
  final cursor visibility belongs to whichever other rule owns it.
  Risk: medium.
  Verify: (1) cmd-tab away/back must not reveal the cursor while Hidden;
  (2) entering fullscreen must not show Player UI or cursor; (3) exiting
  fullscreen must not change state; (4) moving out of the player area hides
  Player UI immediately and stops the current player from deciding cursor
  visibility; (5) opening Settings or another non-player interface hides
  Player UI as player-focus loss without treating CueSeeker foreground App
  focus as sufficient player focus.
- **S4 — Overlay middle panel (core layout change).** `PlaybackPageView`:
  `HStack(video + sidebar)` → video stage fills the window + centered floating
  overlay; remove `PlaybackSidebarMetrics` squeeze math; restore the Search
  Results / Subtitles content (logic exists: `searchNavigationResultGroups`,
  `currentSubtitleEntries`); opaque panel; visibility via the bottom-bar
  three-line toggle; never auto-hides; click-row → seek; feedback overlay above
  the panel. Risk: medium-high. Verify seek smoothness is unaffected and the
  panel never resizes the video stage.
- **S5 — Fullscreen simplification + ADR-0011 convergence.** With the collapsed
  dedicated video page, verify ADR-0011 acceptance passes trivially (no freeze,
  no workbench relayout flash); converge the `69861f2` render-sync band-aid
  where no longer needed. The measured fullscreen result must be reported (no
  silent reinterpretation). Risk: medium.
- **S6 — Memory: baseline + per-step measurement.** Record the ~30 MB baseline
  and current 60–70 MB before S1; re-measure RSS after each of S1–S5. This is
  measurement/tracking only, not a mid-stream fix.
- **S7 — Full UX regression + end memory diagnosis + changelog.** End-to-end
  validation (rewrite-plan Phase 6); diagnose and clean any residual memory
  bloat from the old playback path and report the measured RSS as an explicit
  number; update `docs/changelog.md`. App-wide memory acceptance still waits for
  the separate info-page Phase 5.

Dependencies: S1 first; S2 and S3 may follow S1 in parallel; S4 after S1; S5
depends on S1 + S4; S6 runs alongside S1–S5 as measurement; S7 last.

### S5 Detailed Plan And Measurement Protocol

S5 converges the `69861f2` render-sync band-aid (four layers, deepest last:
`PlaybackFullscreenManager` → `PlaybackView`/`PlaybackRenderViewWrapper` →
`PlaybackPlayer` → `SFXNativePlaybackPlayer.m`). This crosses the standing
"do not touch the seek / native render path" non-negotiable, so it is allowed
only within this `69861f2` convergence scope, only under this protocol, and
only with explicit per-step user authorization for the deeper layers.

- **S5.0 — Doc-first + authorization gate (no App code).** Reconcile ADR-0011
  (status → superseded by ADR-0013), ADR-0013, and doc 12 §12; record the
  acceptance benchmark and this protocol. Obtain explicit user authorization
  to touch the named render/native files within the convergence scope, and
  agree the real-machine measurement steps (this environment has no GUI and
  cannot measure fullscreen).
- **S5.1 — Pre-removal functional baseline (no App code; user real-machine).**
  With the band-aid still in, the user verifies fullscreen enter/exit
  acceptance passes by structure. Per the project-owner memory-deferral
  decision (see Memory Regression), this baseline is **functional only**; no
  per-step memory measurement is taken now. If it fails functionally even with
  the band-aid, the structural premise is disproven: stop and report; do not
  remove the band-aid. Resolved 2026-05-19: a rough functional run found no
  fullscreen problems, so S5 proceeds to S5.2.
- **S5.2 — Remove layer 1+2 (SwiftUI/manager triggers).** Remove the
  `PlaybackView`/`PlaybackRenderViewWrapper` token resync and the
  `PlaybackFullscreenManager` `synchronizeFullscreenRenderLayout()` calls.
  Isolated reversible commit; user re-measures; regression → default revert +
  documented result.
- **S5.3 — Remove layer 3 (PlaybackPlayer container sync).** Only if S5.2
  measured clean. Isolated reversible commit; user re-measures; regression →
  default revert + documented result.
- **S5.4 — Remove layer 4 (native `.m`).** Only if S5.2–S5.3 prove layers 1–3
  redundant AND with explicit per-step user authorization. Any doubt or
  regression → native code stays, documented as intentionally retained with the
  measured reason. **Done (`9501254`, 2026-05-19):** authorized; the native
  hook was orphaned by S5.3 so removal was pure dead-code deletion; the
  `69861f2` normal-layout refactor was deliberately retained.
- **S5.5 — Final acceptance + doc finalize.** `swift test` green at every step
  (necessary, not sufficient — it does not cover the fullscreen GUI). Finalize
  ADR-0011 / ADR-0013 / doc 12 §12. Changelog is S7, not S5. **Done
  (2026-05-19): S5 complete.** All four band-aid layers removed (S5.2
  `c1a950a`, S5.3 `7ef3dbf`, S5.4 `9501254`); the user's real-machine
  functional checks after each step found no obvious fullscreen regression
  (functional acceptance, not an instrumented benchmark; memory deferred);
  ADR-0011 / ADR-0013 / doc 12 §12 finalized. Fullscreen correctness is now
  structural with no render-sync band-aid.

Acceptance benchmark for every S5 removal step: no video freeze and no
workbench relayout flash on fullscreen enter/exit; `D`/`X` next/previous-result
and seek shortcuts unchanged and smooth; cursor hide/unhide stays balanced;
overlay-panel and v4 player-UI/cursor state unaffected by fullscreen enter or
exit. The measured result is reported as an explicit observation; per
`docs/engineering/02_git_workflow.md` §10 a regression defaults to reverting
that change and documenting the result, and keeping a still-needed layer
requires an explicit documented reason separate from the failed goal.

## Acceptance

- Fullscreen enter/exit shows no video freeze and no workbench relayout flash.
- Toggling the overlay panel does not change the video stage size.
- Search → Enter → "play immediately" plays without returning to the info page;
  closing the video page returns to the originating info-page mode with state
  intact (query, scroll, disclosure).
- `D`/`X` next/previous-result and seek shortcuts are unchanged and still smooth.
- Startup RSS is measured and reported; the regression toward the ~30 MB
  baseline is addressed, not assumed.
- `swift test` passes.

## Step Document Rule

This document plus ADR-0013 are the required step documents for this refactor.
The App Implementation Steps (S1–S7) section is the authoritative step plan for
App code. If a decision, step, sequence, or acceptance criterion changes, update
these documents before changing App code.

## Status And Remaining Roadmap

This proposal is the **video-page (Phase 1 structural) stage** of the UI
rewrite. S1–S5 are complete (2026-05-19); the stage closes at **S7**
(end-to-end functional regression + `docs/changelog.md`; the end-memory
diagnosis is deferred by project-owner decision and is not part of S7 now).

The info-page card-visual rebuild (rewrite-plan Phase 5: Search / Library /
Shiori card surfaces) is **not in this proposal's scope**. It is the only
remaining net-new UI stage and will be started as its own **new independent
proposal** with its own doc-first / prototype-first cycle when that stage
begins. Per-step / end memory diagnosis and the window aspect-ratio-lock ADR
are parked until after the full UI rebuild and are not part of the remaining
UI stages. See `docs/proposals/2026-05-native-app-ui-ux-rewrite-plan.md`
"Implementation Status And Remaining Roadmap".

## Decision

Accepted. The app is refactored into an info page and a dedicated video page;
the video page is an overlay above a live info page with a custom app-semantic
top bar and an overlay middle panel that does not squeeze the video. This
refactor is the resolution of the playback fullscreen jank and absorbs the
ADR-0011 repair process (see ADR-0013).
