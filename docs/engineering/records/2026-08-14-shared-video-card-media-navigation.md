# Requirement

- `docs/human/requirements/20260814-Feature-Shared Video Card And Media Navigation Interaction.md`
- `docs/human/design/UI Design System.md`

# Scope

Reuse the Recent Videos card in Workbench Library Folder Detail and Playback
Video Playlist. Remove forced selection centering from the two Command Panel
recent lists and Playback Video Playlist, prefer the current video when a new
Playlist Session initializes, preserve selection and offset within a Session,
and suppress mouse Hover while the Playback Pointer is hidden.

# Architecture

- Platform UI/UX: one adaptive Grid and one video-card renderer accept Recent
  and complete-folder presentation data through a small value projection.
- Session coordination: the existing Playback media selection store remains the
  only Playlist selection and scroll-state owner; it accepts one optional
  preferred initial identity.
- Pointer interaction: the existing Playback Pointer visibility store gates
  Hover visuals and Pointer cursor presentation without writing Playlist
  selection.
- Product semantics, persistence, playback execution, and UI tokens remain
  unchanged. No cache, asynchronous lifecycle, dependency, or new E2E input
  capability was added.

# Steps

1. Replaced the separate Library Episode row implementation with the existing
   Recent-style adaptive card Grid and retained one shared card body, context
   menu, availability rule, progress, time, watch-state, and full-card
   selection treatment.
2. Passed the Folder Detail title into every complete-folder card so all three
   hosts render `folderTitle`, `EPxx`, and the existing watch Badge rather than
   `displayTitle` or file metadata.
3. Injected Playback Pointer visibility into Command Panel and gated Recent
   Video card and Recent Shiori row Hover without changing keyboard selection.
4. Removed center anchors and selection animations from Command Panel Recent
   Videos, Recent Shioris, and Playback Video Playlist. Unanchored
   `ScrollViewReader` requests retain visible positions and reveal offscreen
   items at the nearest edge.
5. Kept the existing adaptive grid-direction algorithm for Playlist and updated
   its column count from the real viewport width.
6. Passed the normalized current video path into the existing Library Session
   store. Initial selection prefers that available item, falls back to the first
   available item, and does not reset on later module visits or detail refreshes.
7. Added focused preferred-selection, asynchronous-detail, and scroll-reveal
   tests and updated the existing Session-continuity integration test.
8. Removed the shared video card's Hover-selection callback and the Playlist
   selection store's Pointer mutation entry point. Hover now remains visual
   state and can coexist with keyboard selection on another card.

# Verification

- `swift build -c release --product CueSeeker` passes.
- `swift test --filter 'PlaybackLibrary|playbackMedia|WorkbenchScrollView'`
  passes 21 tests, including preloaded and asynchronous current-video
  selection, nearest-edge reveal, and no movement for an already visible
  target. The obsolete Pointer-selection expectation was removed with its
  production mutation path.
- `swift test --filter 'playbackCommandPanel|recentShioriPlayback'` passes 13
  Command Panel navigation, recent-page, and Recent Shiori playback tests.
- The Debug in-app E2E flow passed in the real `1433 x 821`-point, `2x` Light
  Mode window. Captures verified the shared Recent-style cards in `Ave Mujica`
  Library Detail and Playback Playlist. EP01 was selected on first entry; EP02
  selection and position survived a Current/Playlist round trip; after EP02
  began playback, a new Overlay Session selected EP02 rather than EP01.
- Default parallel `swift test` ran 998 tests and reported 25 unrelated shared
  window, database, native playback timing, and table-mount issues. Explicit
  serial `swift test --no-parallel` reduced this to three existing environment
  or timing failures: one shared-default migration expectation and two Shiori
  table anchor waits. The migration test passed alone; the two Shiori waits
  reproduced alone. No failing test touches this change's files or behaviors.
- `git diff --check` passes.

# Outcome

Recent Videos, Library Folder Detail, and Playback Video Playlist now render one
video-card implementation. Playlist initialization follows the current video,
Session continuity is retained, and keyboard navigation no longer re-centers
visible selections. Hidden Pointer state no longer leaves card or Recent Shiori
Hover feedback active, and Pointer movement cannot replace Playlist selection.

# Follow-ups

- Pointer-hidden Hover and Hover/Selected independence remain owner-approved
  manual acceptance items because the current Debug E2E controller
  intentionally cannot move the real Pointer.
- The human owner will update `docs/human/design/UI Design System.md` only after
  the visual iteration is accepted, as required by the current requirement.
- After that acceptance, synchronize the derived component and UX mappings in
  `docs/product/11_liquid_glass_component_mapping.md` and
  `docs/product/12_liquid_glass_ux_mapping.md`; they are intentionally unchanged
  during the current visual iteration.
