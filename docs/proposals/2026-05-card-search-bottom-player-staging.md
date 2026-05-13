# Card Search and Bottom Player UI Staging

Status: Draft

## Background

The next UI/UX direction moves CueSeeker from a side-panel-centered search and
playback workbench toward a search-driven media workspace.

The change is large enough that it should not be implemented as one broad
rewrite. The work should be staged so each step produces a visible,
reviewable interface state before detailed interaction decisions are finalized.

## Goals

- Rework Search results toward a card-based browsing surface.
- Introduce a persistent bottom player inspired by modern media-player
  layouts.
- Move Library and Shiori access into the top bar near Search.
- Remove the right sidebar from the target main layout.
- Keep each implementation step small enough to review and refine before the
  next step starts.

## Non-goals

- Do not finalize every detailed interaction in this staging document.
- Do not rewrite playback semantics as part of the staging plan itself.
- Do not restart the Rust shared-core migration.
- Do not change indexing, Search matching, database schema, or subtitle
  parsing semantics.
- Do not treat later-step UI details as accepted before the corresponding step
  is reviewed.

## Staging Plan

### Step 1: Establish the New Main Layout

Rework the primary application layout around a top navigation/search bar, a
card-based content area, and reserved space for a bottom player.

Scope:

- Convert Search results to a card-based layout.
- Move Library and Shiori navigation to the left side of the top Search field.
- Remove the right sidebar.
- Reserve space for a bottom player bar.
- Add a basic visual bottom bar shell if needed, without requiring complete
  playback behavior.

Goal:

- Validate the new overall structure and Search-result readability before
  implementing complex playback interactions.

### Step 2: Implement the Bottom Player Bar

Build out the Spotify-style bottom player once the main layout is visually
stable.

Scope:

- Left area: current video information.
- Center area: playback controls and progress.
- Right area: lyrics, queue, fullscreen, and related controls.
- Connect the bar to actual playback state where practical.

Goal:

- Make playback persistent and globally visible across the app.

### Step 3: Implement the Video Overlay

Add the video overlay behavior after the bottom player has a stable structure.

Scope:

- Clicking a Search result card can open a video overlay.
- When no video is currently playing, the overlay should slide out from the
  bottom player area.
- The overlay should cover the current interface as a playback-focused layer.
- Detailed behavior should be refined after seeing the first implementation.

Goal:

- Turn Search results into direct playback entry points without forcing a full
  page navigation model.

### Step 4: Adapt Library and Shiori to the New Shell

After the main Search and playback shell is validated, adapt Library and Shiori
to the same top-navigation layout.

Scope:

- Ensure Library works without the old sidebar.
- Ensure Shiori fits the new global layout.
- Align active navigation states, spacing, and page transitions.
- Keep future refinements based on actual UI review.

Goal:

- Make the whole app feel like one coherent search-and-playback experience.

## Implementation Approach

Each step should be implemented, reviewed visually, and adjusted before the next
step begins. Details that depend on seeing the actual UI should be decided in
the step where they become relevant, not prematurely in this staging document.

Step 1 should be aligned in detail before any code implementation begins. Later
steps should receive their own focused alignment before implementation.

## Product Documentation Impact

If this direction is accepted, the stable conclusions should be merged into the
relevant product UI and UX documents before implementation relies on them as
final product rules.

This proposal is expected to revise or supersede portions of the currently
accepted workbench, topbar Search, and player-first Search layout directions,
but those stable documents should not be rewritten until the next accepted
direction is clear.

## Decision

Draft. Use this document to coordinate the staged UI/UX rewrite before accepting
stable product documentation changes.
