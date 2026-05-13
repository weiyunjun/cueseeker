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

## Reference Images

The visual references for this staged direction are stored under
`docs/assets/ui-references/card-search-bottom-player/`.

Reference files:

- `search-results-card-layout.png`: card-based Search results grouped by source
  title.
- `library-grid-layout.png`: Library grouping and episode grid reference.
- `spotify-style-bottom-player.png`: bottom player structure reference with
  video information, playback controls, and secondary controls.
- `bottom-player-right-controls.png`: current bottom-player control alignment
  and playback-speed menu reference.

These images are references for alignment and review. They do not replace the
behavioral requirements that must be written into proposals or stable product
documents before implementation depends on them.

## HTML Prototype

The current static prototype for the Step 1 visual and interaction reference is
`docs/prototypes/card-search-bottom-player-v1.html`.

The prototype should be checked before implementing major frontend UI changes
for this direction. It currently demonstrates:

- Card-based grouped Search results.
- Library grouped-folder and episode-grid browsing.
- Shiori grouped cards that follow the same basic layout as Search result
  cards.
- Icon-only Library and Shiori controls beside the top Search field.
- A bottom player without cover art.
- A video-window expand or collapse button in the former cover-art position.
- A concise video title with volume control beside it.
- Source-aware center playback controls for Library episode navigation and
  Search result navigation.
- A light gray rounded bottom-player surface with white button controls.
- A three-dot menu placed after the next-episode control.
- A gray rounded playback-speed menu matching the current app UI direction.
- A right-side control group aligned with the current playback controls:
  Shiori, copy current subtitle, subtitle visibility, playback speed, and
  fullscreen.
- A three-dot menu containing `Video Folder`, `Subtitle Folder`, `Results`, and
  `Subtitles`.

## Staging Plan

### Step 1: Establish the New Main Layout

Rework the primary application layout around a top navigation/search bar, a
card-based content area, and reserved space for a bottom player.

Scope:

- Convert Search results to a card-based layout.
- Move Library and Shiori icon navigation to the left side of the top Search
  field. Use the current app icon semantics (`folder` for Library and
  `bookmark` for Shiori), and avoid visually emphasizing a selected relationship
  in this topbar prototype.
- Remove the right sidebar.
- Reserve space for a bottom player bar.
- Add a basic visual bottom bar shell with working prototype controls.

Initial bottom-player alignment:

- The left area does not show cover art in the first prototype. The former cover
  position becomes the video-window expand or collapse button.
- The bottom player should visually match the current app UI direction: use a
  light gray rounded surface with white button controls.
- When the video window is collapsed, the expand or collapse button points
  right. Clicking it expands the video window and changes the arrow upward.
  Clicking it again collapses the video window and changes the arrow downward.
- The bottom-player title should use concise video identity such as
  `AVE MUJICA EP 01`.
- Volume control belongs next to the title.
- The center playback controls are, in order: previous episode video, previous
  Search result, play or pause, next Search result, next episode video.
- Previous or next episode buttons are active only for Library-launched
  playback. Previous or next result buttons are active only for Search-launched
  playback. Missing targets should disable the corresponding button.
- The right-side controls should match the refined right-control reference:
  Shiori, copy current subtitle, subtitle visibility, playback speed, and
  fullscreen.
- `Video Folder`, `Subtitle Folder`, `Results`, and `Subtitles` move into the
  secondary menu opened by the vertical three-dot button after the next-episode
  video control.
- The `Results` and `Subtitles` popup interfaces are not changed in this step.
- The playback-speed menu should use the current app's gray rounded menu style,
  not the earlier dark menu reference.
- Bilingual subtitle lines should use the same text color. The prototype must
  not imply that Chinese and Japanese subtitle lines have different semantic
  color roles.

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
- Keep Shiori's basic layout aligned with Search: grouped card sections with
  the same card structure and scanning rhythm.
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
