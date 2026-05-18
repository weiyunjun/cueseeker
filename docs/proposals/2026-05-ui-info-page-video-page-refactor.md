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
  and extended by the Player-UI / cursor visibility state machine (v1) below.

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
  analogous to Windows apps where close minimizes to tray); minimize collapses;
  maximize enters fullscreen. The real NSWindow traffic lights are
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

## Player-UI / Cursor Visibility State Machine (v1)

This is the first version of the user-provided rules and may be tuned later.

Definitions: Player UI = bottom bar + top bar (traffic lights + centered video
alias). Player area = the App window region while the video page exists. Shown =
Player UI and cursor visible. Hidden = Player UI not visible (cursor per the
policy below).

Two states, mouse-movement-driven, no transition animation. Clicks and
keystrokes do not count as activity (they neither reset the idle timer nor
restore Shown).

- Init: entering the video page → Shown.
- Shown → Hidden when any of: (1) the mouse moves out of the player area;
  (2) the mouse is in the player area and does not move for 3 seconds; (3) the
  App loses focus. Cursor policy on transition: if the mouse is in the player
  area and the App is focused, hide Player UI and cursor; otherwise hide Player
  UI only and keep the cursor. Thus (1) UI only, (2) UI and cursor, (3) UI only.
- Hidden → Shown when: the App is focused, the mouse is in the player area, and
  the mouse moves → show Player UI and cursor.
- Entering fullscreen: force Hidden, both UI and cursor hidden (entry moment
  only; afterwards the normal rules apply inside fullscreen).
- Mouse movement always shows the cursor.

Implementation note: this is a single explicit state machine covering both UI
and cursor, reconciled with the existing
`PlaybackFullscreenManager.beginInitialPointerSuppression()` /
`hidePlayerUI(hideCursor:)` so cursor hiding is not performed in two competing
places.

## Memory Regression

Startup RSS regressed from approximately 30 MB to 60–70 MB. The likely cause is
that the rewrite plan's Phase 1 delete gate was not completed cleanly, so old UI
code, retained observers, or stale view trees coexist with the new code.
Approximately 30 MB is the baseline metric. The regression must be diagnosed and
the measured RSS reported as an explicit acceptance number before concluding
that the rewrite fixes it; no unapproved mitigation may be silently layered on.
This work is effectively finishing the Phase 1 code-structure gate properly.

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
5. Top/bottom bar show/hide behavior follows the state machine (v1) above.

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
8. Implement, sequenced within the rewrite plan's visual-rebuild stages (player
   Chrome → right-panel visual → main-page cards), then update
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
If a decision, sequence, or acceptance criterion changes, update these documents
before changing App code.

## Decision

Accepted. The app is refactored into an info page and a dedicated video page;
the video page is an overlay above a live info page with a custom app-semantic
top bar and an overlay middle panel that does not squeeze the video. This
refactor is the resolution of the playback fullscreen jank and absorbs the
ADR-0011 repair process (see ADR-0013).
