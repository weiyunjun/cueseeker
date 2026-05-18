# Native App UI/UX Rewrite Plan

Status: Accepted

## Background

The accepted Liquid Glass HTML prototype is the source of truth for the native
macOS UI rewrite. The native App must not keep patching the previous persistent
bottom-player implementation, because that approach leaves old visual states,
old button behavior, and old playback chrome logic mixed with the new design.

The native implementation direction is now a replacement rewrite:

1. Remove the obsolete native playback UI/UX code path.
2. Rebuild the playback page and playback chrome from the accepted HTML
   prototype and mapping documents.
3. Reconnect only the existing playback, Search, Library, Shiori, and
   persistence behaviors that are still product requirements.

## Source References

Implementation must follow these references in order:

1. `ui/prototypes/cueseeker-liquid-glass-v5/`
2. `docs/product/11_liquid_glass_component_mapping.md`
3. `docs/product/12_liquid_glass_ux_mapping.md`
4. This rewrite plan
5. Native SwiftUI code under `apps/macos-native/`

If implementation exposes a missing visual, state, layout, timing, or UX rule,
update the HTML prototype and mapping documents before continuing App code.

## Goals

- Replace the old native playback UI/UX path instead of patching it.
- Remove old persistent bottom-player, empty bottom-player, expand/collapse,
  and old playback chrome behavior before rebuilding the new UI.
- Rebuild the playback page, bottom chrome, right playback sidebar, and main
  Search/Library/Shiori card visuals from the accepted HTML prototype.
- Keep existing non-UI behavior: playback backend, subtitle rendering, Search
  cache, lazy loading, first-screen rendering, Library progress history, and
  Shiori persistence.
- Keep Settings out of this rewrite.

## Non-goals

- Do not redesign Settings.
- Do not change Search ranking, query parsing, cache semantics, lazy loading, or
  first-screen rendering.
- Do not change database schema or subtitle parsing.
- Do not replace the playback backend.
- Do not add picture-in-picture in this rewrite.
- Do not use test/build success as visual acceptance.

## Phase 1: Delete The Old Playback UI/UX Path

This phase is a code-structure gate. It is not a visual completion phase.

Delete or disconnect these old UI concepts:

- Persistent bottom player shown outside the video playback page.
- Empty bottom player / `No video selected` chrome.
- Bottom-left expand/collapse video control.
- Collapsed playback placeholder.
- Old playback page insertion or scaling transition.
- Old bottom-player button style, progress bar style, speed menu, and volume
  hover UI.
- Old playback page layout if it continues to own video, bottom chrome, or
  side-panel presentation in a way that conflicts with the HTML prototype.

Keep these non-UI capabilities:

- Existing player and subtitle render pipeline.
- Play/pause, seek, time, duration, volume, mute, speed, subtitle visibility,
  copy subtitle, Shiori save/remove, fullscreen, and previous/next actions.
- Search, Library, and Shiori entry points that open playback.
- Search result cache, lazy rendering, first-screen rendering, Library progress
  history, and Shiori persistence.
- Data builders for right playback sidebar content.

Acceptance criteria:

- The old bottom-player implementation no longer exists or is no longer
  referenced by the App.
- The old expand/collapse playback UI is no longer callable from visible UI.
- There is no UI path that shows a bottom player before the playback page.
- Opening playback can only enter the new playback-page route.
- Non-video pages show no playback UI and reserve no playback chrome space.
- `swift test` passes.

## Phase 2: Build The New Playback Page Skeleton

Build the new playback-page structure after Phase 1 passes.

Scope:

- New playback page root.
- Left black playback stage.
- Real video frame sized by source aspect ratio.
- Close capsule anchored to the actual video frame top-left.
- Optional right playback sidebar container.
- Bottom playback chrome container owned by the playback page.

Acceptance criteria:

- Video area, bottom chrome container, and right sidebar appear together as one
  playback page.
- The bottom chrome never appears as a full-width intermediate state.
- Close ends playback and returns to the normal page.
- Player UI means bottom chrome plus the `Close` capsule. They share the same
  visible/not-visible state while `Close` remains a separate video-frame
  anchored command.
- Right sidebar visibility is independent from fullscreen state.
- Opening playback or navigating Search results does not force the right
  playback sidebar visible.
- `swift test` passes.

## Phase 3: Rebuild Playback Chrome

Rebuild the bottom playback controls from the HTML/component mapping.

Scope:

- New button components for circular buttons and capsule buttons.
- New progress bar.
- New volume control.
- New speed menu.
- New fullscreen, subtitle, sidebar, Shiori, copy subtitle, transport, and
  navigation controls.
- New `LiquidGlassFeedbackOverlay` for playback shortcut, mouse, and button
  feedback. This includes play/pause, relative seek, Search result navigation,
  subtitle visibility, speed, volume, Shiori, copy subtitle, and fullscreen
  text-only feedback.
- Player UI visible/not-visible behavior for the playback page.

Acceptance criteria:

- Player UI hides after three seconds without mouse movement in the frozen
  display-check area and reappears only from mouse movement inside the player
  area.
- Hiding chrome does not resize the video or sidebar.
- Icons, button size, spacing, selected states, hover states, and pressed states
  match the accepted HTML prototype.
- Feedback HUD visuals, placement, icon/text ordering, and animation timing
  match the accepted HTML prototype. Repeated relative seek feedback accumulates
  in the same HUD, and forward feedback displays text before the arrow.
- Repeated feedback commands update the visible HUD without a full remount or
  flashing entry animation.
- Playback time labels fit at least `10:00:00` without wrapping.
- The speed menu closes on preset selection and on clicks outside the menu.
- The copy-current-subtitle button uses the prototype copy glyph.
- Shiori remains a plain fixed-icon command button.
- Subtitle and sidebar controls may show selected state when active.
- `swift test` passes.

## Phase 4: Rebuild The Right Playback Sidebar

Rebuild the playback sidebar from the accepted HTML and UX mapping.

Scope:

- Search Results and Subtitles segmented tabs.
- Count label.
- Result and subtitle rows.
- Selected row state.
- Scroll behavior.
- Match highlighting where applicable.

Acceptance criteria:

- Sidebar visual style matches the accepted HTML prototype.
- Selected row state remains only inside the playback sidebar.
- Main Search, Library, and Shiori pages do not show playback-selected cards.
- Result-to-result navigation does not clear the existing Search result cache.
- `swift test` passes.

## Phase 5: Rebuild Main Search, Library, And Shiori Surfaces

Rebuild the non-playback surfaces after the playback page no longer depends on
old UI code.

Scope:

- Search result cards.
- Library cards/groups.
- Shiori cards/groups.
- Main-page hover, pressed, selected, empty, and loading states.

Acceptance criteria:

- Main cards match the accepted HTML prototype.
- Main pages do not retain playback selection visuals.
- Search lazy loading and first-screen rendering behavior remain unchanged.
- Library progress history and Shiori persistence remain unchanged.
- `swift test` passes.

## Phase 6: Full UX Regression

Run full App behavior validation after the visual rewrite is complete.

Acceptance criteria:

- Search, Library, and Shiori playback all open the same new playback page.
- Close, fullscreen, Esc, mouse play/pause, keyboard shortcuts, seek feedback,
  subtitle toggle, speed, volume, Shiori, copy subtitle, and right sidebar
  behavior match the UX mapping.
- Repeated seek feedback accumulates the displayed amount.
- Fullscreen and right sidebar visibility remain decoupled.
- Settings is unaffected.
- `swift test` passes.

## Step Document Rule

This plan is the required step document for the native UI/UX rewrite. If a
phase, sequence, or acceptance criterion changes, update this document before
changing App code.

## Relationship To Earlier Proposals

This plan supersedes the persistent bottom-player, empty bottom-player, and
collapsible playback-surface portions of
`docs/proposals/2026-05-card-search-bottom-player-staging.md`.

It does not supersede backend playback decisions, Search performance decisions,
Library history behavior, Shiori persistence, or the Liquid Glass mapping
documents.

## Decision

Accepted.

The native UI/UX rewrite must delete or disconnect the old playback UI/UX path
before rebuilding the playback page and playback chrome. Implementation should
not continue as incremental patches on the old bottom-player structure.
