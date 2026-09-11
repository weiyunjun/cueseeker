# Liquid Glass UX Mapping

Status: Draft

## 1. Purpose

This document maps the accepted Liquid Glass prototype UX behavior to the
native SwiftUI implementation responsibilities.

`docs/product/11_liquid_glass_component_mapping.md` defines component class
ownership. This document defines behavior, layout, state preservation, and
interaction ownership so the native App rewrite does not visually match the
prototype while drifting from the intended user experience.

This is a review draft. App implementation should not depend on it as accepted
direction until the user approves it.

## 2. Prototype Scope

Current HTML source:

```text
ui/prototypes/cueseeker-liquid-glass-v6/
```

This pass reflects the info-page / video-page refactor
(`docs/proposals/2026-05-ui-info-page-video-page-refactor.md`, ADR-0013) and
**supersedes** the following earlier rules in this document: the §10.1
side-panel-squeeze layout, the §10.4 floating-chrome visibility model, and the
video-frame `Close` capsule lifecycle (§10.5). The video page is now a dedicated
full-window presentation; the side content is a centered overlay that does not
squeeze the video; close moves to a custom video-page top bar.

Surfaces covered by this UX mapping:

- Main workbench shell (info page only; hidden on the video page).
- Topbar Library, Shiori, and Search controls (info page only).
- Search results in the native Cue table.
- Library grouped episode grid.
- Shiori in the native Cue table.
- Playback Multi-Module Overlay with the native Current Cue reel, shared
  Playlist/Search/Shiori Cue Result reel, and Recent/Library media layouts.
- Active-playback bottom player.
- Video page video surface (dedicated full-window presentation).
- Video page top bar (custom traffic-light cluster plus centered title).
- Playback close lifecycle (via the video-page top bar, returns to the info page).
- Playback input feedback overlay.
- Video page right-aligned overlay panel (replaces the former squeezing side panel).
- Playback fullscreen chrome.

Explicitly excluded:

- Settings window redesign.
- Prototype-only theme and disable-all controls.
- Native titlebar mechanics, traffic-light implementation details, AppKit
  fullscreen lifecycle mechanics, playback backend, database behavior, indexing
  behavior, and Search matching semantics.

## 3. Non-Negotiable Preservation Rules

The Liquid Glass UI rewrite must not regress existing product behavior outside
the intended visual and interaction changes.

Rules:

- Search pagination, lazy loading, first-screen rendering, exact counts, and
  result ordering remain owned by the existing Search pipeline.
- Library grouping, natural sorting, playback resume history, and indexed
  resource loading remain owned by existing Library state.
- Shiori persistence, duplicate handling, and playback opening behavior remain
  owned by existing Shiori state.
- Playback render-view ownership, seek, volume, speed, subtitle track, and
  fullscreen lifecycle remain owned by the playback layer.
- Playback close is owned by the playback session lifecycle. It must stop the
  current session and clear playback-derived selection, then restore the
  current Playback Return Context, but it must not clear Search results, database search
  caches, Library rows, Shiori records, or unrelated workbench presentation
  state.
- The right-aligned overlay panel must never resize the video stage. Toggling the
  panel must not change video available size, so playback render and seek are
  not disturbed.
- Settings remains the current independent native Settings window and is not
  part of this UI rewrite.
- A layout-only change must not rebuild Library rows, Search results, Shiori
  groups, playback state, or subtitle data.
- Any command that changes available video size must respect the existing
  rapid-repeat guard so resize animations and fullscreen transitions cannot
  overlap.

## 4. Shell And Topbar

### 4.1 UX Rule Mapping

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| The App opens into one persistent workbench surface. | `.window`, `.main` | `ContentView`, `LiquidGlassSurface` | `AppDelegate`, `AppCoordinator` |
| The topbar contains Library and Shiori icon controls immediately left of the Search field. | `.toolbar`, `ui-icon-button--topbar` | `AppTopBar`, `LiquidGlassIconButton.Kind.topbar` | `WorkbenchLayoutState` |
| The Library/Shiori icon cluster and Search field are visually centered as a group. | `.toolbar-center` | `AppTopBar` layout | Native window sizing |
| The topbar has no heavy divider and uses the Liquid Glass surface treatment. | `.toolbar` | `LiquidGlassSurface.toolbar` | None |
| The Search field is the only Search entry point in the current workbench. | `ui-input-capsule` | `LiquidGlassSearchField` | `TopbarSearchInputState` |
| A duplicate Search field must not be rendered inside the Search results page. | `.search-state` | Search page view | `SearchStore.searchQuery` |
| Settings is not a topbar or main-window panel in this rewrite. | None | Existing `SettingsView` unchanged | Existing app menu action |

### 4.2 Required Behavior

- Typing in the topbar Search field updates the active query automatically
  after a `100ms` debounce. The latest edit wins.
- Return is not a Workbench Search submission command.
- Focusing the topbar Search field activates Search mode when another workbench
  mode is visible.
- Activating Library or Shiori switches the content surface without pausing
  playback, clearing playback, or changing the current video.
- Library and Shiori topbar controls keep outline icon semantics. Hover adds a
  quiet glass background. Selected state changes the button material and
  foreground contrast, not the workbench's data state.
- User-initiated App commands outside text editing should clear Search field
  focus unless the command is explicitly a text-editing command.
- Native traffic lights, titlebar drag behavior, and AppKit fullscreen titlebar
  behavior remain native App concerns and are not synchronized from HTML.

## 5. Workbench State Routing

The workbench has three primary content states:

```text
Library
Search
Shiori
```

The video page is a dedicated full-window presentation layered above a still
alive info page. It is entered from an active playback selection. It is not a
route swap: the info page (Library, Search, or Shiori) keeps its state, scroll,
disclosure, and Search cache alive underneath while the video page is shown. The
workbench `.toolbar` is hidden on the video page; the video page has its own
custom top bar.

Rules:

- The bottom player and the video-page top bar are shown only on the visible
  video page.
- Search, Library, and Shiori pages do not show a collapsed bottom-player-only
  state and reserve no playback chrome space.
- Switching between Library, Search, and Shiori preserves inactive mode state
  where practical, including loaded result state, active Search text, and
  presentation disclosure state that the existing App state already owns.
- Switching modes must not rebuild large lists unless the underlying data or
  query inputs changed.
- The video page may be entered from Search, Library, or Shiori playback state
  when a playable selection exists.
- The Playback Page owns one Return Context initialized from the entering
  Workbench Feature. Successful Playback Search, Shiori, Recent, or Library
  Detail playback replaces it with that Feature target. Closing Playback
  returns to the current Return Context and then destroys it.
- Playback Search is a capability-restricted host of the Workbench Search
  Feature. It uses the same query and result collection with a temporary empty
  Filter context. Closing the Overlay discards only Overlay-local selection,
  scroll, measurement, and unfinished presentation work; the Search query and
  shared results remain Feature state.
- Closing playback ends the active playback session, clears playback selection
  highlights, hides the bottom player and top bar, restores the current
  Playback Return Context, and keeps Search, Library, and Shiori data intact.

## 6. Search UX

### 6.0 Current Cue-Centric Native Contract

The native App contract below supersedes conflicting grouped-card,
subtitle-file disclosure, and `Collapse All` behavior retained from the v6 HTML
prototype in sections 6.3-6.4:

- Search uses `SubtitleTableView`; Shiori uses the same
  native virtual table contract with its additional Tags and Date Added cells.
- Each row has one stable primary Cue identity. Search pages and exact counts
  use individual Cues, so two matching sibling Cues remain two rows.
- Rows are content-driven: `16 + 24P + 20S`, with all source line breaks and
  automatic wrapping visible. No Cue text may be truncated or line-limited.
- `Show Cue Group` is a persisted native switch below Search Scope. Off renders
  only the primary Cue; On renders additional Cues above it in secondary type,
  while selection, playback, copy-Cue, and export targets remain the
  primary Cue.
- While Show Cue Group is On, all displayed Cue text shares one hover, click,
  and context-menu region. `Copy Cue Text` still targets only the primary Cue;
  `Copy Cue Group Text` appears only while On and copies the displayed group.
- Cues-column width and `Show Cue Group` changes may remeasure visible rows plus
  overscan only. They preserve the primary Cue plus first-line screen anchor
  and must not rerun Search, reload Shiori, change
  counts/ordering/identity, or recreate the playback render host.

### 6.1 Live Search Query And Page States

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| Search follows the latest text edit after a `100ms` debounce; Return does not submit. | `#searchInput` | `LiquidGlassSearchField` | AppCoordinator live-query task and revision guard |
| Live results appear in the main content area. | `.search-state` | Search page view | `SearchStore` active query and result snapshot |
| Empty, loading, failed, and no-results states remain explicit. | State demo `.state-view` / `.state-spinner` / `.load-more` (`ui/state-demos/info-page-card-states/`) | Search page state views | `SearchStatus`, active query |
| Search page shows a compact summary row above results. | `.results-header` | Search summary view | Search result counts |

Rules:

- Search results must not flicker or clear unnecessarily while the active query
  revision is still valid.
- Repeating the same query should not trigger expensive work without reason.
- Search focus changes are UI state and must not invalidate Library, Shiori, or
  playback content.
- Search page state, in this order (condition → state; title/message verbatim
  from `SearchView.swift`): active query empty → "No Search Query";
  `SearchStatus.searching` with no results → "Searching" (animated spinner);
  `SearchStatus.failed(message)` with no results → "Search Failed" (shows the
  error message); completed with zero results → "No Results"; results present
  → native Cue table; `SearchStatus.searching` with results already present →
  the current Cue table with a bottom incremental "loading more" spinner.
- The state demo `ui/state-demos/info-page-card-states/` is the provisional
  authority for which state appears and whether it animates; it is not the
  final pixel-level visual authority. The demo's state-view treatment leans
  native and diverges from the accepted Liquid Glass card visual; that
  pixel-level reconciliation is out of the current Phase 5 layout/operation
  scope and deferred to a later visual pass (see proposal "P5.0 C2").

### 6.2 Search Result Lazy Loading

The native Cue table must preserve existing Cue paging semantics.

Rules:

- Search result lazy loading remains based on matched Cues, not subtitle
  file groups.
- The initial visible budget remains 100 Cue results.
- Each incremental global load remains 100 Cue results.
- Additional pages may load only from the table's declared visible-row paging
  trigger and must advance the individual-Cue cursor without duplicate or stale
  rows.
- Dynamic row layout must not make first-screen rendering wait for all rows,
  all measurements, or playback metadata; measure visible rows plus overscan.
- Search thumbnails are not retained. The accepted card design (v6 and the
  state demo) has no thumbnails; the experimental
  `searchResultThumbnailsEnabled` setting, its Settings toggle, and any
  thumbnail slots or thumbnail work are removed together with the legacy
  row-path retirement (an App step gated by App-implementation approval, not
  P5.0). This reverses the prior "thumbnails remain controlled by the existing
  experimental setting" rule. Removing the defunct toggle spans AppCoordinator and
  SettingsView; it is permitted cleanup, not a Settings redesign (see proposal
  "P5.0 Confirmed Audit" finding B). First-screen rendering must never wait for
  thumbnails.

### 6.3 Search Group Headers (Legacy HTML — Superseded)

This subsection records the retired grouped-card prototype and is not a current
native App requirement.

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| Groups are flat subtitle-file groups. | `.group` | Search group view | Search grouping |
| Groups are expanded by default for a new query. | expanded group state | Search group view | Search presentation state |
| Group headers use a disclosure chevron and muted count. | `.group-header` | `LiquidGlassDisclosureHeader` | Collapse state |
| Chevron rotates `0°` collapsed and `90°` expanded over `160ms`. | `.chevron` | Disclosure component | Local animation state |
| Friendly titles use parent folder and one-based natural-sort rank when available. | group title text | Title resolver / Search group view | Existing title resolver |

Rules:

- A group header is one click target for collapse or expansion.
- The disclosure rail lives in the left control space and should not add extra
  indentation to result text.
- Per-file counts are shown as muted plain text in the group header. They are
  not badges.
- Group ordering remains stable and must match the Search result order used by
  playback navigation.
- Fallback raw filenames may wrap, with soft wrap opportunities after common
  delimiters when needed.

### 6.4 Search Result Cards (Legacy HTML — Superseded)

This subsection records the retired grouped-card prototype and is not a current
native App requirement.

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| Results render as grouped cards. | `.result-card`, `ui-selectable-card` | `LiquidGlassSelectableCard` | Search result data |
| Cards show rank and timestamp metadata. | `.card-meta` | Search result card view | Result rank/time |
| Cards show complete cue text without truncating subtitle lines. | card body | Search result card view | Cue display lines |
| Query matches may be highlighted. | highlight spans | Highlight renderer | Search query terms |
| Main-page cards do not retain selected visuals after activation. | absence of `ui-is-selected` on main `.result-card` | Search result card view | Playback opening command |

Rules:

- Cards in the same visual row should share the tallest card height for that
  row when practical.
- Subtitle content should remain readable and must not be clipped by card
  height constraints.
- Card metadata should not infer or display episode labels unless a reliable
  source exists.
- Main Search result cards may show hover and pressed feedback, but they return
  to ordinary card styling after activation.
- Search match highlights must stay readable in default and hover states.
- Clicking a Search result opens or updates playback and clears Search focus.
- The corresponding overlay-panel row should show selected state when the
  active playback context belongs to that Search result.
- If the same video is already open, selecting another result in that video
  should seek instead of reopening when practical.
- Search card, group header, and results-header pixel visuals, the topbar
  (search-field capsule, tool buttons, and toolbar background; NSWindow
  traffic lights stay native and are not aligned), and the info-page
  background (light `#f4f4f6` / dark `#1f2027`) align to the v6 prototype per
  the proposal "P5.2-B Confirmed Pixel Spec" (single source, P5.2 option B).
  The subtitle line font weight/opacity is App-authoritative — the v6
  prototype was updated to match the App, not the reverse (doc 11 §8).

## 7. Library UX

### 7.1 Library Surface

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| Library is entered from the topbar Library icon. | `#libraryToggle` | `AppTopBar` | `activateWorkbenchPanelMode(.library)` |
| Library groups videos by immediate parent folder. | `.library-group` | Library page view | Library grouping |
| Folder groups are collapsed on app startup or Library data refresh. | `.library-group.collapsed` | Library group view | Library presentation revision |
| Folder row is a full click target for disclosure. | `.library-group-header` | Disclosure row component | Local collapse state |
| Episode buttons flow in an adaptive grid. | `.library-episode-grid` | Library episode grid | Library video rows |
| Empty / loading / failed / no-videos states remain explicit. | State demo `.state-view` / `.state-spinner` (`ui/state-demos/info-page-card-states/`) | Library page state views | `selectedFolders`, `libraryStatus` |

Rules:

- Library is separate from Settings > Library.
- Library must not expose a panel-wide `Collapse All` or `Expand All` control.
- Folder groups use Finder-like natural ordering.
- Folder disclosure state is session-only and resets when Library data changes.
- Reindexing or refreshing Library data rebuilds Library rows and resets folder
  groups to collapsed.
- The folder row uses a two-line layout: folder display name and an episode
  count subtitle.
- When the active playback was launched from Library and belongs to the folder,
  the folder subtitle adds `Playing M`, where `M` is the video's one-based
  natural-sort sibling rank.
- Playback opened from Search, Shiori, or any non-Library source must not
  toggle Library playing indicators.
- Library page state, in this order (condition → state; title/message verbatim
  from `SearchView.swift`): no selected folders → "No Library"; `libraryStatus`
  loading with no videos → "Loading Library" (animated spinner); `libraryStatus`
  failed → "Library Failed" (shows the message); videos empty → "No Videos";
  videos present → folder/episode list. The state demo is the provisional state
  authority (see §6.1); pixel-level visual reconciliation is deferred.
- Library folder group, header, and episode-grid pixel visuals align to the v6
  prototype (`.library-group`, `.library-group-header`, `.library-episode-grid`,
  `library-episode-card ui-selectable-card`). P5.3 is an in-place visual
  rebuild with no separable dead path to pre-delete; concrete values come from
  a future owner-confirmed "P5.3 Confirmed Pixel Spec" sub-section (single
  source, like P5.2-B). See proposal "P5.3 / P5.4 Old-Code Audit & Deletion
  Plan".

### 7.2 Library Episode Grid

Rules:

- Expanded folders show compact episode-rank buttons.
- Episode buttons size to their rank label: a fixed minimum width and fixed
  height keep short ranks (`EP01`) compact and uniform, while long ranks
  (`EP120`) widen the button rather than truncate (owner 2026-05-20).
- The HTML prototype uses `EP01` style labels. Resolved (owner, 2026-05-20):
  the native App adopts the `EP01` compact episode-rank label to match v6; it
  must still derive the rank from Finder-like natural sorting. (Closes the
  doc 12 §16 EP01 question; proposal finding H resolved.)
- Episode buttons must not show raw file names, durations, or language tags.
- The grid column count adapts to the current available width.
- The grid is slightly indented relative to the folder row to express
  hierarchy.
- Episode buttons have default, hover, and playing states.
- The playing state appears only for Library-launched playback.
- Expanding a folder that contains the current Library-launched video should
  auto-scroll that episode button into view as part of the expand transition.
  Auto-scroll must not fire for already-expanded folders.
- Clicking an episode button opens or updates playback from persisted
  Library-only resume history, falling back to `0` when no history exists.

## 8. Shiori UX

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| Shiori is entered from the topbar Shiori icon. | `#topbarShioriToggle` | `AppTopBar` | `activateWorkbenchPanelMode(.shiori)` |
| Shiori uses the shared native Cue table. | Native-only | Shiori page view, `SubtitleTableView` | Stable individual-Cue Shiori rows |
| Shiori summary shows total shiori and file counts. | `.results-header` | Shiori summary view | Shiori counts |
| Selecting a Shiori opens or seeks playback from that Cue. | Native table Cues cell | `SubtitleTableView` | `openShiori` |
| Empty state is explicit; there is no Shiori loading or failed state. | State demo `.state-view` (`ui/state-demos/info-page-card-states/`) | Shiori page state view | `shioris` empty |

Rules:

- Every Shiori row owns one Cue and its tags. Complete primary and optional
  additional Cue text follows the shared `16 + 24P + 20S` dynamic geometry and
  must not be truncated.
- `Show Cue Group` changes presentation only; it never changes Shiori identity,
  tags, counts, ordering, playback target, or remove/export action target.
- Saving or removing a Shiori must not pause playback, reset Search state, or
  rebuild Library rows.
- Width and `Show Cue Group` reflow may remeasure visible Shiori rows plus
  overscan, preserving the anchored primary Cue without rebuilding the Shiori
  snapshot, Search, Library, or playback render host.
- Playback Multi-Module Overlay Shiori feedback uses the same transient
  playback feedback system as other playback commands and renders above the
  Overlay.
- Shiori page state (condition → state; verbatim from `SearchView.swift`):
  `shioris` empty → "No Shiori"; shioris present → native Cue table. The App
  has no Shiori loading or failed state and the demo must not invent one. The
  state demo is the provisional state authority (see §6.1); pixel-level visual
  reconciliation is deferred.
- The v6 grouped Shiori-card, group-header, and `Collapse All` mappings are
  Superseded historical prototype references and must not override the native
  table contract.

## 9. Bottom Player UX

### 9.1 Layout

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| Bottom player uses three zones: volume, transport, operations. | `.player-hud` | `LiquidGlassBottomPlayer` | Active playback state |
| Left zone contains volume only in the active target UI. | volume control | Bottom player left cluster | Current playback volume |
| Center zone contains five transport controls. | `.transport-controls` | Bottom player transport cluster | Playback navigation |
| Right zone contains Repeat, Screenshot, subtitle visibility, speed, and fullscreen. | `.right-controls` | Bottom player operations cluster | Playback and App commands |
| Progress scrubber spans the bottom-player width above the control row. | `ui-slider--progress` | `LiquidGlassSlider.Kind.progress` | `PlaybackViewModel` |

Rules:

- The bottom player is rendered only while the video playback page is visible.
  Search, Library, and Shiori pages must not show it.
- In playback visibility rules, `player UI` means the floating bottom player
  and the video-page top bar together. They show and hide as one playback
  chrome surface per the state machine in §10.4.
- The bottom player stays visually stable when control values change.
- Text/value controls use capsule components. Icon-only controls use circular
  icon buttons.
- The old source/title capsule and bottom-left expand-collapse affordance are
  removed from the active target UI.
- The volume button becomes the leftmost bottom-player control.
- The speed capsule has fixed width and tabular text so preset changes do not
  shift neighboring controls.
- Playback time labels have fixed tabular width and must not wrap. The width
  must fit at least `10:00:00` on both current-time and duration labels.
- The current-time label is right-aligned inside its fixed slot and the
  duration label is left-aligned inside its fixed slot. Extra width for
  hour-long videos stays outside the scrubber gap, so the scrubber remains
  centered and visually close to both time labels.
- The speed capsule displays the existing App playback speed presets. If the
  HTML prototype omits a currently supported preset, the existing App preset
  range remains the behavior source until a product rule explicitly changes it.
- The bottom-player controls must not move vertically when the volume popover,
  speed menu, scrubber hover, or scrubber drag state appears.
- Disabled buttons remain visible but clearly inactive when the command is not
  available.
- Repeat is immediately left of Screenshot. It uses the `repeat` glyph and is
  enabled only for Cue Playlist playback with Auto Switch off while the current
  timestamp is inside the target Cue's inclusive time range.
- Toggle icon controls use stable semantic glyphs with selected-state material
  and foreground contrast. Where the prototype defines matching outline and
  filled glyphs, the App should switch glyphs as part of the selected state.
- The Shiori save/remove button is an ordinary circular icon command button.
  Its visible glyph stays the outline bookmark and it does not expose selected,
  pressed, or filled-bookmark state.

### 9.2 Transport And Commands

Rules:

- Center transport order is previous episode, previous Search result, play or
  pause, next Search result, next episode.
- Previous and next episode commands are active only when a Library navigation
  target exists.
- Previous and next Search result commands use the complete active Search
  result order and are active only when that navigation target exists.
- Opening a Search result must update the previous and next Search result
  command availability for that active result immediately, including the first
  result having no previous target.
- Play or pause toggles current playback and must not be blocked by unavailable
  navigation commands.
- The right operation cluster contains Repeat, current-frame Screenshot,
  subtitle visibility, playback speed, and fullscreen. It has no
  normal-playback Shiori or copy-current-subtitle control.
- Subtitle visibility toggles the current player's subtitle overlay without
  resizing the bottom player and uses a standalone circular button.
- The panel toggle shows or hides the right-aligned overlay panel without moving or
  resizing the video or the bottom-player controls.
- Fullscreen enters or exits playback fullscreen through the existing playback
  fullscreen manager.
- Clicking a bottom-player control must not fall through to video-surface
  play/pause toggling.

### 9.3 Menus, Popovers, And Sliders

Rules:

- The playback speed selector opens an app-drawn rounded-rectangle popup menu
  upward from the speed capsule.
- The speed control shows only the current speed value and has no separate
  visible arrow.
- The speed menu uses compact preset rows and a check indicator for the current
  preset.
- The speed menu closes when a preset is selected or when the user clicks
  outside the menu.
- The speed menu does not need a separate show or hide animation.
- Hovering the volume button reveals the volume slider and numeric percentage
  together.
- Volume hover uses the same compact popover motion as the prototype: opacity
  fade plus a small horizontal offset, not a large slide or layout shift.
- The volume popover must not move the playback controls vertically.
- Button pressed and hover animations use compact Liquid Glass timing. Pressed
  scale should be subtle and must not make repeated commands feel jumpy.
- The progress scrubber supports hover, drag, and seek.
- Scrubber hover and drag states may reveal a thumb or strengthen the track,
  but they must not change the bottom-player row height.
- Timeline scrubbing is modal. While the user is dragging the progress
  scrubber, non-Timeline playback controls suppress hover, pressed, click, and
  menu states, and non-Timeline playback keyboard shortcuts are disabled.
- During timeline scrubbing, the red progress track, thumb, tooltip, and visible
  playback time follow the drag target immediately. The white hover-ahead track
  segment is hidden while the drag is active.
- During timeline scrubbing, the video surface remains on the frame that was
  visible when scrubbing began. The drag path does not update keyframes,
  generate thumbnails, perform realtime seeks, or otherwise change the video
  image before mouse release.
- Click seeks and the final seek after timeline dragging preserve the playback
  state from before the seek interaction. If the resulting state is paused, the
  destination frame is still rendered.
- Thumbnail and full-size keyframe preview remain open research directions, but
  they are deferred from the current UI restructure until their memory,
  latency, and decoder-lifecycle tradeoffs justify the added complexity.

## 10. Expanded Playback UX

### 10.1 Layout Structure

The video page uses this conceptual layout (supersedes the prior
side-panel-squeeze layout):

```text
Video page (fills the window; workbench toolbar hidden)
  Black video base (fills the window)
    Custom video-page top bar (player UI)
      Left traffic-light cluster (close, minimize, zoom)
      Centered video title
    Aspect-fit video frame
    Floating bottom-player chrome (player UI)
  Centered overlay panel (floats over the video; does not squeeze it)
  Feedback overlay (above the overlay panel)
```

Rules:

- The video page fills the whole window. The black video base is the full-window
  sizing container; the workbench `.toolbar` is hidden.
- The custom top bar spans the top of the video page: a left traffic-light
  cluster and a centered video title. It is player UI.
- The traffic-light controls are custom-drawn with app semantics: close restores
  the current Playback Return Context (not quit), minimize miniaturizes the app window
  to the Dock (native `NSWindow.miniaturize`, a native-mechanics control outside
  the HTML prototype), zoom enters fullscreen. The real native NSWindow traffic
  lights are suppressed on the video page. The custom top bar is windowed-only;
  in fullscreen it is not shown and the macOS native fullscreen titlebar takes
  over (see §12).
- The right-aligned overlay panel floats above the video and does NOT squeeze or
  resize the video base. Showing or hiding it must not change video available
  size.
- The overlay panel never auto-hides. Its visibility is driven only by the
  bottom-player panel toggle and is independent of player-UI visibility.
- There is no video-frame `Close` capsule. Closing is the top-bar close control.
- The video page must not show an extra video-title/avatar block inside the
  video stage or above the overlay-panel tabs; the only title is the centered
  top-bar title.

### 10.2 Video Frame Sizing

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| The full-window black video base is the sizing container. | `.video-stage` | `PlaybackExpandedLayout` | Window geometry |
| The video frame uses the active video's real aspect ratio. | `.video-frame[data-video-aspect]` | Video stage layout | `PlaybackViewModel.videoAspectRatio` |
| The frame maximizes inside the black base. | JS frame layout logic | Video stage layout | GeometryReader |
| Either width or height reaches the available limit. | JS frame layout logic | Video stage layout | GeometryReader |
| The frame is centered after aspect-fit sizing. | JS frame layout logic | Video stage layout | GeometryReader |
| The bottom player is floating chrome and does not participate in video frame sizing. | `.player-dock` | Bottom-player overlay | Chrome state |

Sizing algorithm:

1. Measure the full-window black video base. The overlay panel floats over the
   video and is not subtracted; there is no squeezing side column.
2. Read the active video's real aspect ratio. Fall back to `16:9` only when no
   video ratio is available.
3. If `baseWidth / baseHeight` is wider than the video ratio, set
   `frameHeight = baseHeight` and `frameWidth = frameHeight * aspectRatio`.
4. Otherwise set `frameWidth = baseWidth` and
   `frameHeight = frameWidth / aspectRatio`.
5. Center the frame horizontally and vertically inside the black base.
6. Do not subtract floating bottom-player height from this calculation.

Rules:

- The black base and native video layer must resize together. Users must not
  see the black container and video frame drift out of sync.
- The video frame should preserve rounded-corner clipping only where the
  accepted prototype requires the visible frame to be rounded.
- Static prototype text such as `16:9 video area` is not implemented in the
  App.

### 10.3 Floating Bottom-Player Geometry

Rules:

- On the video page, the black video base fills the window, so the bottom
  player is positioned from the full-window black base.
- The bottom player uses fixed left and right margins inside the black base.
- The bottom player's horizontal position and width update immediately during
  resize and window geometry changes. The overlay panel does not squeeze the
  video, so toggling it does not move or resize the bottom player.
- Horizontal position and width changes must not animate.
- Player UI visibility changes must not animate. The bottom-player chrome
  appears and disappears as a discrete visible/not-visible state.
- The bottom-player chrome overlays the video base and does not reserve layout
  space.

### 10.4 Floating Chrome Visibility

This is the Player-UI / pointer visibility model (v5), the mirror of
`docs/human/requirements/20260912-UI-Player UI And Pointer Visibility
Rules.md`; that requirement decides. v5 supersedes v4: the idle hide is a
condition instead of an event, clickable controls and dragging block it,
same-window layers freeze it and show the pointer, and a lost focus or a
pointer outside the window hides the Player UI and shows the pointer.

Definitions:

1. Player UI: the video-page top bar, the bottom control bar, and the menus
   they open. A hidden Player UI closes its menus.
2. Clickable control: a control of the Player UI that can be clicked or that
   keyboard focus could reach, disabled ones included: the window controls,
   the return button, the Task and Settings entries, the progress scrubber's
   hit area, every bottom-bar button, the volume control and the speed menu's
   items. The title, the time display, the bars' empty space and the video
   are not clickable controls.
3. Focus in the playback window: the App is active and the main window is the
   key window. The Playback Overlay, the Command Panel and in-window dialogs
   keep it; the Settings window, other independent windows, system dialogs
   and other Apps take it.
4. Pointer movement: a real change of the pointer's position, dragging with a
   mouse button held included. Clicks, mouse button down/up without a
   position change, the wheel and the keyboard are not movement.

Invariants:

5. A hidden pointer always means a hidden Player UI. A shown pointer allows
   either Player UI state.
6. Nothing here depends on whether the video is playing or paused.

Showing:

7. Entering the playback page shows the pointer and the Player UI and starts
   the idle countdown.
8. A hidden Player UI is shown again only by pointer movement inside the
   window while the window has focus.

Idle hide:

9. The pointer and the Player UI hide together when all of these hold and the
   pointer has not moved for `--duration-player-ui-idle-hide` (3 s): focus is
   in the playback window; the pointer is inside the window and on no
   clickable control; no drag of the progress bar or the volume slider is in
   progress; keyboard focus is on no Player UI control.
10. When any condition breaks, the countdown is cleared; when all hold again,
    it starts over. Clicks do not restart it. The keyboard-focus condition has
    no trigger today, since buttons take no focus and the Player UI has no
    text field; it is recorded, not implemented.

Immediate hide:

11. The pointer leaves the window: the Player UI hides, the pointer stays
    shown.
12. Focus leaves the playback window: the Player UI hides, the pointer is
    shown.
13. Entering fullscreen hides both.

Same-window layers:

14. While the Playback Overlay, the Command Panel or an in-window dialog is
    open, the pointer is shown and the Player UI's state and countdown are
    frozen.
15. When it closes, the conditions are read again: if they all hold the
    countdown starts over; if the pointer is outside the window or focus is
    gone the Player UI hides.

Mapping notes (App implementation):

- One model owns both states and the system cursor. It hides the cursor only
  while it governs the pointer — the window has focus, no same-window layer is
  open, and the live pointer position is inside the player area — and shows
  it whenever governance is lost.
- Clickable controls report their frames through a SwiftUI anchor preference
  collected by the video stage; the window controls' frames are read from
  AppKit. The pointer's live position is compared with them when the
  countdown is started and again when it ends. A hidden Player UI's controls
  do not count.
- Player-area movement comes from an `NSTrackingArea` on a hit-test-
  transparent full-bleed overlay view; dragged movement comes from a local
  event monitor. Enter and exit events only refresh the live picture: layout
  and fullscreen changes emit them without physical motion.
- Player UI and pointer transitions do not animate. Hiding the Player UI
  closes the speed menu and changes nothing else: not playback, not
  selection.
- A game controller has no pointer, so its input hides both at once while the
  pointer is governed. The keyboard hides nothing.
- Playback media-card Hover may update the session-local Selected Item only
  while the pointer is shown.

### 10.5 Playback Close UX

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| Close is the red traffic-light control in the video-page top bar. | `.vt-close` in `.video-topbar` | `LiquidGlassWindowControlButton.Kind.close`, `LiquidGlassVideoTopBar` | Playback session lifecycle |
| Close ends the active playback session and restores the current Playback Return Context. | `.playback-closed` / no active session marker | `PlaybackExpandedLayout`, `BottomPlaybackBar` | `AppCoordinator.stopPlayback` or successor close command |
| Close hides the bottom player after playback ends. | `.player-dock` hidden when no active playback | `BottomPlaybackBar` | Derived active playback session state |
| Close clears playback-derived selection highlights. | `ui-is-selected` removed from overlay-panel rows | Overlay-panel views | Current playback source and selection state |

Rules:

- Close should stop native media playback, clear the active playback source, and
  leave the reusable playback player/render infrastructure available for the
  next open command.
- If the current source is Library, close must save Library playback history
  using the same rule as any other Library playback stop or switch.
- If the current source is Search or Shiori, close must not read, write, or
  overwrite Library playback resume history.
- Close must clear the selected overlay-panel row because there is no longer an
  active playback identity. Native Search/Shiori tables have no
  playback-derived card selection visual; Library's documented playing
  indicator is a separate source-specific state.
- Close must not clear the active Workbench Search query, Search result list, database
  search cache, Shiori records, Library rows, Library disclosure state,
  Cue-table presentation, or unrelated workbench state.
- Close from playback fullscreen exits fullscreen and ends playback. It must not
  leave the user in a video-only fullscreen surface without playback.
- Closing playback is not the same as hiding the overlay panel, hiding chrome,
  or exiting fullscreen. Those actions preserve playback; close ends playback,
  restores the current Return Context, and then destroys that context.

## 11. Video Page Overlay Panel UX

The former right side panel is now a centered overlay that floats over the
video. Its internal content (tabs, count, rows) is unchanged; only its
container and placement changed.

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| The overlay panel is a right-aligned floating panel over the video and does not squeeze the video. | `.sidebar` | Overlay-panel view, `LiquidGlassSurface` | None |
| Panel contains `Search Results` and `Subtitles` tabs. | `ui-segmented-control` | `LiquidGlassSegmentedControl` | Active drawer state |
| Tabs sit at the top. | `.sidebar-top` | Overlay-panel view | None |
| Active count label sits below tabs on the left. | `.sidebar-summary` | Overlay-panel summary | Search/subtitle counts |
| No video title or `Search playback` label appears above tabs. | absence rule | Overlay-panel view | None |
| Rows use compact selectable row cards. | `ui-selectable-row` | `LiquidGlassSelectableRow` | Search/subtitle row data |
| The panel can be hidden or restored only from the bottom-player panel toggle; it never auto-hides. | `#sidePanelToggle` | Bottom-player panel button | `isPlaybackSidePanelVisible` |

Rules:

- The `Search Results` tab uses the complete active Search result order.
- Search Results rows may highlight query matches.
- The selected Search result row uses selected state and should scroll into
  view when practical.
- The Search Results tab does not show `Collapse All`.
- The project custom-drawn overlay scrollbar shows its fixed-width thumb while
  overflow exists and omits it otherwise. Its track is transparent and it
  reserves no native gutter; automatic visibility behavior remains deferred.
- The `Subtitles` tab lists the current subtitle file in timestamp order.
- Subtitles rows do not apply keyword highlighting.
- The current playback subtitle row uses selected state for context and should
  scroll into view when practical.
- Clicking a Subtitles row seeks playback to that subtitle entry's start time.
  The seek dispatches through the existing shared playback command model; the
  overlay-panel view must not implement seek itself or touch the native render
  path.
- Clicking a row during playback seeks to or opens that result; this is the
  intended baseline interaction.
- Selecting another Search result from the overlay panel preserves the panel
  list while playback opens or seeks.
- Opening playback from Search, Library, or Shiori must not force the overlay
  panel visible. Previous-result and next-result navigation also must not force
  it visible. Overlay-panel visibility is changed only by the bottom-player
  panel toggle and is independent of player-UI visibility.
- The overlay panel must not briefly clear to `0 results` or a loading panel
  during result-to-result jumps when the current Search result list is still
  valid.
- Hiding or restoring the overlay panel must not pause playback, clear
  selection, resize the video, or resize the bottom-player controls.
- Showing or hiding the overlay panel animates a brief transition that mirrors
  the v6 prototype: on hide, an opacity fade to zero plus a small downward
  translate and slight scale-down; on show, the reverse. Target timing is
  approximately 180 ms. The overlay panel is not Player UI, so this is a
  deliberate exception to the §10.3 / §10.4 rule that Player-UI and cursor
  transitions do not animate; the panel's own show/hide does animate. The
  transition must not move or resize the video stage or the bottom-player
  controls, and the panel still never auto-hides.
- The overlay panel floats above the video, never auto-hides, and is not part
  of player UI for the §10.4 visibility state machine.
- The feedback overlay renders above the overlay panel so command feedback is
  not occluded by it.

## 12. Playback Fullscreen UX

Fullscreen playback uses the native fullscreen lifecycle but the Liquid Glass
bottom-player visual language.

Rules:

- The dedicated full-window video page (S1–S4, ADR-0013) is the structural
  resolution of the playback fullscreen jank: with no co-resident workbench or
  squeezing sidebar, entering fullscreen is "hide the top-bar overlay, let the
  video fill". S5 (complete 2026-05-19) confirmed ADR-0011 acceptance now
  holds by structure (no video freeze, no workbench relayout flash on
  enter/exit; `D`/`X` and seek shortcuts unchanged and smooth; overlay-panel
  and §10.4 Player-UI/pointer state independent of fullscreen enter/exit) and
  removed the `69861f2` render-sync band-aid entirely (all four layers);
  fullscreen layout correctness now relies solely on this structural video
  page, with no compensating render-sync machinery. Verification was the
  user's real-machine functional check after each removal (no obvious
  regression); per-step memory measurement was deferred by project-owner
  decision. Any future regression here defaults to revert + documented result,
  never silent reinterpretation. See ADR-0011 "S5 Convergence Outcome" and the
  proposal's S5 measurement protocol.
- Fullscreen playback continues to use AppKit native fullscreen behavior and
  the existing playback fullscreen manager.
- The HTML prototype represents App fullscreen with a local prototype state,
  not with the browser Fullscreen API. This avoids browser-level fullscreen
  behavior being mistaken for the native App fullscreen contract.
- In the HTML prototype, the fullscreen state marker must not redefine player
  layout rules. It may promote the existing `.main` playback surface to a
  fixed viewport-covering overlay so it visually covers the toolbar and
  prototype test controls. It must not change body padding, window size,
  toolbar height, video-stage sizing rules, video-frame aspect-fit
  calculation, overlay-panel participation, or bottom-player anchoring rules.
- The prototype may disable ancestor-only visual effects that prevent fixed
  viewport positioning, such as the window backdrop filter, as long as the
  fullscreen playback surface fully covers the affected shell.
- The overlay panel keeps the same appearance whether fullscreen is active or
  not. Black fullscreen backing belongs only to the video stage; the overlay
  panel floats over the video unchanged in fullscreen.
- The playback render container must not be duplicated or moved into a second
  backend render state.
- The normal workbench shell is hidden during playback fullscreen without
  losing Library, Search, Shiori, scroll, selection, or focus state.
- The fullscreen chrome uses the same non-fullscreen bottom-player visual
  family. The old dark gradient fullscreen control bar is not the target UI.
- Fullscreen chrome includes the playback controls needed for video review:
  progress, volume, transport, subtitle visibility, speed, and exit fullscreen.
- Fullscreen state and overlay-panel visibility are independent. Entering or
  exiting fullscreen must not hide, show, reset, or otherwise mutate the
  overlay-panel visibility state.
- If the overlay panel is visible before entering fullscreen, it remains visible
  in fullscreen. If it is hidden before entering fullscreen, it remains hidden
  in fullscreen.
- The fullscreen button uses the enter-fullscreen glyph outside fullscreen and
  the two inward-touching arrows exit-fullscreen glyph while fullscreen is
  active.
- Entering and exiting fullscreen show text-only feedback: `Enter Fullscreen`
  and `Exit Fullscreen`.
- Text-only fullscreen feedback uses the independent small capsule HUD
  specification, not the larger icon-centered feedback HUD dimensions.
- The text-only capsule is a single-line, content-width pill centered over the
  active video stage. The HTML target size is 42 px high with 18 px horizontal
  padding, full capsule radius, 13 px bold label text, no icon slot, and no
  reserved icon gap.
- Player UI and pointer visibility in fullscreen follow the §10.4 model.
  Entering fullscreen hides both; pointer movement inside the window while it
  has focus shows both again, and the idle countdown then applies as
  everywhere else. Clicks, the wheel and the keyboard reveal nothing. Exiting
  fullscreen does not by itself change either state.
- Clicking the video surface toggles play/pause unless the click targets a
  chrome control.
- The fullscreen exit control exits playback fullscreen through the existing
  fullscreen manager.
- `Esc` exits fullscreen when playback fullscreen is active.
- In fullscreen the custom video-page top bar is NOT shown. The macOS native
  fullscreen titlebar (auto-shown when the pointer reaches the top edge) is the
  only top chrome: native close, native green/exit-fullscreen, and the centered
  video alias. There is no minimize control in fullscreen.
- So the native fullscreen titlebar shows the alias, the app sets
  `window.title` to the current playback display title while the video page is
  shown and restores `"CueSeeker"` when returning to the info page;
  `titleVisibility` stays `.visible` only in fullscreen.
- Clicking the native fullscreen close button is intercepted (via
  `windowShouldClose`) and performs the playback-close command: it exits
  playback fullscreen, ends playback, and restores the current Playback Return
  Context. It must NOT quit the app or close the window, even though
  `applicationShouldTerminateAfterLastWindowClosed` is true.
- The native fullscreen green button exits playback fullscreen through the
  existing fullscreen manager.
- Minimize is windowed-only. There is no minimize affordance in fullscreen and
  the app must not exit fullscreen merely to miniaturize.
- Fullscreen subtitle overlay bottom padding adapts to chrome visibility so
  subtitles do not collide with visible controls.

## 13. Playback Input, Keyboard, And Feedback UX

### 13.1 Input Eligibility

Rules:

- Playback shortcuts are active only when playback exists, the playback
  interface is visible, and editable text input is not focused.
- Text editing in the Search field must keep standard macOS editing behavior.
- `Command`, `Control`, and `Option` modified key events are ignored by
  playback shortcuts.
- `Shift` is accepted only for the speed shortcuts defined below.
- While a menu is open and nothing covers it, the keyboard is the menu's: the
  arrows, Enter, Esc and the key that opened it go to the menu, and every other
  playback, Playback Overlay and Command Panel shortcut, and Tab, is spent.
  `Command` shortcuts are unaffected. The speed menu follows the same rule as
  every other menu.
- Playback shortcuts dispatch through the same command model as playback
  buttons, mouse video clicks, menu selections, and slider gestures.
- While the Playback Multi-Module Overlay is visible, its module-specific
  keyboard routing takes precedence over normal playback shortcuts. Current,
  Playlist, and Shiori use `S`, `C`, and Enter; Search uses Enter only; Space is
  consumed without action.
- Commands that are unavailable for the current playback state must not mutate
  selection, playback, Search data, or Shiori data.

### 13.2 Shortcut And Mouse Command Mapping

| Input | Command | Prototype anchor | SwiftUI owner | Behavior owner | Feedback HUD | Chrome visibility effect |
| --- | --- | --- | --- | --- | --- | --- |
| `Space` | Toggle play/pause | `#playBtn`, `ui-feedback-hud` | Bottom-player transport button, `LiquidGlassFeedbackOverlay` | `PlaybackViewModel.togglePlayback` | `Play` or `Pause` | Keyboard/click: none. Mouse movement follows player UI rules. |
| Left click on visible video surface | Toggle play/pause | `.video-stage`, `.video-frame`, `ui-feedback-hud` | Video stage input layer | Playback command model | `Play` or `Pause` | Does not reveal player UI. |
| `Q` | Toggle subtitle visibility | `#subtitleToggle`, `.subtitle-overlay`, `ui-feedback-hud` | Subtitle toggle button, feedback overlay | Playback subtitle visibility state | `Subtitles On` or `Subtitles Off` | Keyboard/click: none. Mouse movement follows player UI rules. |
| `R` | Repeat the current Cue Playlist subtitle when available | `ui-icon-button--circle`, `ui-feedback-hud` | Repeat button, feedback overlay | Cue Repeat command | Centered `Repeat`, or no feedback when unavailable | Keyboard does not reveal player UI. |
| `P` | Copy the current video frame Screenshot | `ui-icon-button--circle`, `ui-feedback-hud` | Screenshot button, feedback overlay | Current-frame Screenshot command | Centered `Screenshot Copied` after success | Keyboard does not reveal player UI. |
| `F` | Enter or exit playback fullscreen | `#fullscreenButton`, prototype fullscreen class, `ui-feedback-hud` | Fullscreen button, fullscreen player UI | Existing fullscreen manager | Text-only `Enter Fullscreen` or `Exit Fullscreen` | Keyboard does not reveal player UI; fullscreen entry follows fullscreen rules. |
| `Esc` | Exit playback fullscreen when active | Prototype fullscreen class, `ui-feedback-hud` | Fullscreen lifecycle handler | Existing fullscreen manager | Text-only `Exit Fullscreen` | Keyboard does not reveal player UI. No-op outside fullscreen. |
| `A` | Previous Search result | `#previousResultButton`, `.sidebar-row`, `ui-feedback-hud` | Transport previous-result button | Search navigation snapshot | `Previous Result` on the leading side, or `No Result` | Keyboard/click: none. Mouse movement follows player UI rules. |
| `D` | Next Search result | `#nextResultButton`, `.sidebar-row`, `ui-feedback-hud` | Transport next-result button | Search navigation snapshot | `Next Result` on the trailing side, or `No Result` | Keyboard/click: none. Mouse movement follows player UI rules. |
| `Left Arrow` | Seek backward 5 seconds | Progress slider, `ui-feedback-hud` | Progress slider and feedback overlay | Playback seek command | Accumulated rewind total, such as `- 15s` | Keyboard: none. |
| `Right Arrow` | Seek forward 5 seconds | Progress slider, `ui-feedback-hud` | Progress slider and feedback overlay | Playback seek command | Accumulated forward total, such as `+ 15s` | Keyboard: none. |
| `Up Arrow` | Increase volume by 5 | Volume control, `ui-feedback-hud` | Volume button/slider and feedback overlay | Playback volume state | `Volume NN%` | Keyboard: none. |
| `Down Arrow` | Decrease volume by 5 | Volume control, `ui-feedback-hud` | Volume button/slider and feedback overlay | Playback volume state | `Volume NN%` or `Muted` | Keyboard: none. |
| `Shift+,` | Decrease speed by 0.25x | `#speedButton`, `ui-feedback-hud` | Speed value capsule and feedback overlay | Playback speed state | Current speed, such as `0.75×` | Keyboard: none. |
| `Shift+.` | Increase speed by 0.25x | `#speedButton`, `ui-feedback-hud` | Speed value capsule and feedback overlay | Playback speed state | Current speed, such as `1.25×` | Keyboard: none. |

Playback Multi-Module Overlay Cue-action mapping:

| Input | Command | Target | Feedback HUD | Overlay result |
| --- | --- | --- | --- | --- |
| `S` in Current/Playlist/Shiori | Save Shiori idempotently | Exact settled Primary Cue | `Shiori Saved` or `Shiori Already Saved` | Remains visible; playback remains paused. |
| `C` in Current/Playlist/Shiori | Copy Cue text | Exact Primary Cue's complete retained text | `Subtitle Copied` | Remains visible; playback remains paused. |
| `Enter` in Current/Playlist/Search/Shiori | Play from Cue | Exact selected Primary Cue start time | `Play` | Session is synchronously destroyed before continuous playback begins. |
| `Enter` in Recent | Existing primary media action | Selected available Watching Card | Existing playback feedback | Session is synchronously destroyed before the media target opens. |
| `Enter` in Library Folder level | Enter Folder | Selected available Folder card | None | Detail opens inside the same Session. |
| `Enter` in Library Detail | Existing Episode media action | Selected available Episode card | Existing playback feedback | Session is synchronously destroyed before the Episode opens. |
| `Space` in every module | Consume without action | None | None | Remains visible; playback remains paused. |

If an eligible `S`, `C`, or Enter action is accepted while a Cue reel is
settling, the command is executed once against the final settled Primary Cue.
Cue hover and click have no cue-specific response; Up, Down, wheel, and
scrollbar navigation are unchanged.

Playback Multi-Module Overlay Cue geometry and selection are native-only:

- One item is one exact Cue. At opening, choose the physically bottommost Cue
  in the active Cue Group; with no active Cue, fall back to the nearest
  preceding Cue, then the first Cue.
- Nominal Current content height is `52L`, where source line breaks and
  automatic wrapping both contribute to `L`. Natural height is
  `max(nominal content height, visual-line stack height) + 24`; resolved height
  is clamped to the reel viewport. Visual-line placement uses measured font-run
  typographic bounds and the internal-line-gap token, not fixed Line Slots.
- A fitting Cue displays every line and centers its complete bounds on the fixed
  Focus Anchor. An oversized Cue aligns its top to the reel viewport and always
  settles with the first visual line visible; only trailing display content may
  be clipped.
- Up, Down, wheel, and scrollbar navigation use Cue ordinals and content-driven
  accepted placements. Width reflow preserves stable selected Cue identity and
  restores the fitting-center or oversized-head-first placement.
- Playlist, Search, and Shiori use the same virtual rendering, dynamic
  measurement, accepted placement, scrolling, and recycling infrastructure as
  Current. Their complete text collections remain resident in their shared
  Feature or Playlist source; virtualization applies only to view work.
- Playlist shows its one-based internal Sequence Number. `Show Cue Group` adds
  muted Additional Cues to Playlist, Search, and Shiori without changing count,
  order, Result identity, selection, or Primary Cue actions.
- Playback Search keeps editor focus while Results update after the latest
  edit's `100ms` debounce. Enter does not submit the query; it plays only an
  already settled selected Result.
- Every open creates a new temporary Session. Its initial View is Current for a
  video Playlist or no available Playlist, and Playlist for a Cue Playlist.
  Escape, playback, Playback Page close, and source replacement destroy
  Overlay-local module state and cancel unfinished presentation work; module
  switching itself stays inside the Session. Shared Search query/results,
  Shiori, Recent, and Library Feature state are not destroyed with the Session.
- Layout and drawing are limited to visible Cues plus overscan and an explicit
  navigation target. Focus selection, motion, measurement, and deferred action
  state remain overlay-local and must not invalidate Search, Shiori,
  Library, or the playback render host.

Command Panel focused-Cue prefill follows these rules:

- Settings > Search owns the persisted `Prefill with Focused Cue` switch. It
  defaults to Off.
- With the switch On, opening Command Panel while Playback Overlay Current or
  Cue Playlist is active copies the module's focused Primary Cue into the root
  Search field. Source line breaks become spaces through the shared Search
  input normalization rule.
- The field receives focus with a zero-length insertion point after the complete
  text so subsequent typing appends. Prefill alone does not start Search or
  modify shared Search query state.
- Collage remains exclusive and cannot open Command Panel through normal input.
  Search, Library, Shiori, and the absence of an Overlay Session do not provide
  focused-Cue prefill.

### 13.3 Video Surface Mouse Rules

Rules:

- A primary-button click on the video surface toggles play/pause.
- The video-surface click handler must ignore clicks that target bottom-player
  controls, overlay-panel controls, top-bar controls, popup menus, sliders,
  text inputs, or any other interactive control.
- Clicking controls must run only that control's command, not the video
  play/pause command.
- Mouse movement inside the black video base follows the player UI visibility
  rules in sections 10.4 and 12. Mouse clicks do not reveal player UI.
- Mouse activity outside the black video base must not toggle playback.
- Secondary click behavior is not defined by the Liquid Glass rewrite and must
  preserve existing platform behavior until separately specified.

### 13.4 Feedback Overlay Rules

Rules:

- Playback command feedback is rendered by `ui-feedback-overlay` and
  `ui-feedback-hud` over the active video stage.
- The feedback overlay is non-interactive and must never intercept mouse,
  keyboard, slider, menu, or video clicks.
- The feedback HUD is centered within the full-window black video base. The
  overlay panel does not squeeze the video, and the feedback overlay renders
  above the overlay panel so feedback is never occluded by it.
- The feedback HUD may temporarily sit above subtitles because it is transient,
  but it must not permanently reserve space or change subtitle layout.
- The same feedback component is used in expanded playback and playback
  fullscreen.
- If the video surface is not visible, the command may still update playback
  state, but video-stage feedback is shown only when there is a visible video
  stage to host it.
- Repeated feedback commands while the HUD is already visible update the
  existing HUD content in place. They may run a small update pulse, but must not
  remove and recreate the HUD or replay a full fade/scale entry animation.
- Repeated relative seek commands in the same direction accumulate inside the
  feedback timeout, matching the App behavior. For example, three repeated
  forward seeks display `+ 15s`, and three repeated rewind seeks display
  `- 15s`.
- Changing seek direction clears the opposite direction's accumulated total.
- Relative seek feedback uses the trailing side of the video base for forward
  seeks and the leading side of the video base for rewind seeks.
- Search-result navigation feedback uses the same side placement and inline
  icon/text ordering as relative seek feedback: leading feedback displays icon
  before text, while trailing feedback displays text before icon.
- Fullscreen enter and exit feedback is text-only and must not render a
  feedback icon.
- Recommended timing: fade and scale in within 120-180 ms, hold for 450-700
  ms, then fade out within 180-240 ms.
- Repeated keypresses, repeated mouse clicks, and repeated button commands
  refresh the existing HUD and timer.
- Feedback animation must not reveal expanded-playback or fullscreen chrome
  for keyboard-only commands.

## 14. State Lifetime And Invalidation Boundaries

Rules:

- Library rows remain cached until Library data or Library ordering inputs
  change. Manual disclosure, playback, Search, and Shiori interactions must not
  rebuild Library rows.
- Search row identities remain cached until the query, loaded Cue page, Search
  ordering, or indexed Cue data changes. Width and `Show Cue Group` update only
  visible-plus-overscan measurement and the stable scroll anchor.
- Shiori row identities remain cached until Shiori records, tags, ordering, or
  submitted Shiori filters change. Width and `Show Cue Group` are
  presentation-only and must not rebuild that snapshot.
- Playback state changes must not rebuild Library, Search, or Shiori rows
  unless a product-specific state indicator requires a targeted update.
- Switching modes changes visible surfaces, not the underlying data model.
- Collapsing, expanding, hiding, or restoring panels changes layout state, not
  data state.
- Search and Shiori use the native virtual Cue table so row view,
  measurement, and drawing work stays proportional to the visible range plus
  overscan rather than total Cue count.
- Playback Multi-Module Overlay uses native virtual Cue documents. Current and
  the shared Playlist/Search/Shiori Cue Result reel must not create one view or
  text-layout object per retained Cue; accepted placement reflow stays local to
  the Overlay.

## 15. Native Differences Allowed

The App may differ from HTML when platform behavior, accepted Swift
implementation, product behavior, or performance constraints require it. During
the active native UI restructure, SwiftUI/AppKit behavior is authoritative and
HTML prototypes are reference artifacts.

Allowed differences:

- Native traffic lights and titlebar mechanics on the info page. On the video
  page the real NSWindow traffic lights are suppressed and the custom video-page
  top-bar controls (close = return to info page, minimize = native NSWindow
  miniaturize to the Dock, zoom = fullscreen) own those interactions. The
  minimize control is realized by native `NSWindow.miniaturize`, a
  native-mechanics behavior intentionally outside the HTML prototype; the
  prototype's `.vt-min` shows only a local "Minimize" stub. In fullscreen the
  custom top bar is not shown at all: the macOS native fullscreen titlebar
  provides close and exit-fullscreen, the app sets `window.title` to the video
  alias so that titlebar shows it centered, and the native fullscreen close is
  intercepted (`windowShouldClose`) to run the app close semantic instead of
  quitting. This native fullscreen titlebar behavior is intentionally outside
  the HTML prototype.
- The windowed video-page top bar behaves as a standard window titlebar for
  native window management: dragging an empty area of the bar moves the window
  (`NSWindow.performDrag`), and double-clicking an empty area performs the
  user's "double-click a window's title bar to" System Settings action
  (`AppleActionOnDoubleClick`: Zoom via the serialized titlebar-zoom path, or
  Minimize). These titlebar mechanics are native and intentionally outside the
  HTML prototype.
- Native AppKit fullscreen transitions and Space behavior.
- Native material and vibrancy implementations that preserve the accepted
  visual hierarchy.
- Native font rendering and accessibility focus behavior.
- Native media rendering, file access, Finder reveal commands, sandbox
  behavior, and persisted state.
- SwiftUI virtualization and layout implementation details that preserve the
  visible UX rules above.
- Swift-first refinements accepted in the native App before the matching HTML
  reference artifact has been synchronized.

Not allowed:

- Changing Search lazy loading or first-screen rendering to match static HTML.
- Treating prototype mock data as product data.
- Implementing prototype-only test controls in the production App.
- Regressing accepted Swift behavior solely to match static HTML prototype
  shortcuts or stale reference artifacts.
- Letting floating bottom-player layout affect video aspect-fit sizing.
- Letting horizontal bottom-player geometry animate during resize.
- Losing Search, Library, Shiori, playback, or fullscreen state as a side
  effect of visual layout changes.

## 16. Open Review Questions

Open questions before this mapping becomes accepted:

- Resolved (owner, 2026-05-20): Library episode labels use the HTML `EP01`
  format (rank still derived from Finder-like natural sorting); the native App
  does not keep number-only labels. See §7.2 and proposal finding H.
- Should fullscreen chrome need any future now-playing identity label after the
  bottom-left source/title capsule removal, or should it remain transport and
  operation controls only?
- Should the floating bottom-player margin inside the black base be a fixed
  token shared by windowed expanded playback and fullscreen playback?
