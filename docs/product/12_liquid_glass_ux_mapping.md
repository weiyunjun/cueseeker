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
ui/prototypes/cueseeker-liquid-glass-v5/
```

Surfaces covered by this UX mapping:

- Main workbench shell.
- Topbar Library, Shiori, and Search controls.
- Search results.
- Library grouped episode grid.
- Shiori grouped cards.
- Persistent bottom player.
- Expanded playback video surface.
- Playback input feedback overlay.
- Expanded playback side panel.
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
| The App opens into one persistent workbench surface. | `.window`, `.main` | `ContentView`, `LiquidGlassSurface` | `AppDelegate`, `AppState` |
| The topbar contains Library and Shiori icon controls immediately left of the Search field. | `.toolbar`, `ui-icon-button--topbar` | `AppTopBar`, `LiquidGlassIconButton.Kind.topbar` | `WorkbenchLayoutState` |
| The Library/Shiori icon cluster and Search field are visually centered as a group. | `.toolbar-center` | `AppTopBar` layout | Native window sizing |
| The topbar has no heavy divider and uses the Liquid Glass surface treatment. | `.toolbar` | `LiquidGlassSurface.toolbar` | None |
| The Search field is the only Search entry point in the current workbench. | `ui-input-capsule` | `LiquidGlassSearchField` | `TopbarSearchInputState` |
| A duplicate Search field must not be rendered inside the Search results page. | `.search-state` | Search page view | `AppState.searchQuery` |
| Settings is not a topbar or main-window panel in this rewrite. | None | Existing `SettingsView` unchanged | Existing app menu action |

### 4.2 Required Behavior

- Typing in the topbar Search field edits a draft query only.
- Pressing Return submits the draft query as the active Search query.
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

Expanded playback is an overlay state entered from an active playback
selection. It replaces the main content area with the video stage and optional
side panel while preserving the bottom-player control model.

Rules:

- The persistent bottom player remains available across Search, Library, and
  Shiori when playback exists.
- Switching between Library, Search, and Shiori preserves inactive mode state
  where practical, including scroll position, disclosure state, selected item,
  draft Search text, and loaded result state.
- Switching modes must not rebuild large lists unless the underlying data or
  query inputs changed.
- Expanded playback may be entered from Search, Library, or Shiori playback
  state when a playable selection exists.
- Leaving expanded playback returns to the previous workbench surface without
  clearing Search results, Library grouping, Shiori grouping, or playback state.

## 6. Search UX

### 6.1 Search Submission And Page States

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| Search submits only on Return. | `#searchInput` | `LiquidGlassSearchField` | `TopbarSearchInputState.submit` |
| Submitted results appear in the main content area. | `.search-state` | Search page view | `AppState.submitTopbarSearch` |
| Empty, loading, failed, and no-results states remain explicit. | `.search-state` | Search page state views | `SearchStatus` |
| Search page shows a compact summary row above results. | `.results-header` | Search summary view | Search result counts |
| `Collapse All` uses a fixed label and does not become Expand All. | `ui-capsule--command` | `LiquidGlassCapsuleButton.Kind.command` | Search group collapse state |

Rules:

- Search results must not flicker or clear unnecessarily while a submitted
  query is still valid.
- Repeating the same query should not trigger expensive work without reason.
- Search focus changes are UI state and must not invalidate Library, Shiori, or
  playback content.
- The `Collapse All` control collapses all visible result groups and keeps the
  same label.
- Collapsing all groups keeps group headers visible and reduces visible result
  cards or rows to zero.
- Collapse actions must not re-run Search, fetch another page, change the lazy
  loading cursor, or mutate result counts.

### 6.2 Search Result Lazy Loading

The Liquid Glass card rewrite must preserve existing lazy-loading semantics.

Rules:

- Search result lazy loading remains based on matched cue groups, not subtitle
  file groups.
- The initial visible budget remains 100 cue-group results.
- Each incremental global load remains 100 cue-group results.
- Lazy loading may trigger only from user-visible actions: scrolling to the
  bottom when more global rows can be shown, expanding all groups from the
  all-collapsed state, or expanding an individual subtitle-file group.
- Expanding all groups reveals at most one global 100-result batch. It must not
  reveal 100 rows per subtitle file.
- Expanding one subtitle-file group reveals at most the first 100 matching rows
  for that subtitle file.
- UI card layout changes must not make first-screen rendering wait for all
  groups, all counts, thumbnails, or playback metadata.
- Search thumbnails remain controlled by the existing experimental setting.
  If the accepted Liquid Glass card design does not include thumbnails, the
  App must not reserve thumbnail slots or start thumbnail work from the card
  surface.

### 6.3 Search Group Headers

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

### 6.4 Search Result Cards

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| Results render as grouped cards. | `.result-card`, `ui-selectable-card` | `LiquidGlassSelectableCard` | Search result data |
| Cards show rank and timestamp metadata. | `.card-meta` | Search result card view | Result rank/time |
| Cards show complete cue text without truncating subtitle lines. | card body | Search result card view | Cue display lines |
| Query matches may be highlighted. | highlight spans | Highlight renderer | Search query terms |
| Selection updates immediately on user activation. | `ui-is-selected` | `LiquidGlassSelectableCard` | Selected result state |

Rules:

- Cards in the same visual row should share the tallest card height for that
  row when practical.
- Subtitle content should remain readable and must not be clipped by card
  height constraints.
- Card metadata should not infer or display episode labels unless a reliable
  source exists.
- Selected-card feedback is an input response. It must not wait for video open,
  seek, subtitle loading, or ASS render preparation.
- Hover must not override selected state.
- Search match highlights must stay readable in default, hover, and selected
  states.
- Clicking a Search result opens or updates playback and clears Search focus.
- If the same video is already open, selecting another result in that video
  should seek instead of reopening when practical.

## 7. Library UX

### 7.1 Library Surface

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| Library is entered from the topbar Library icon. | `#libraryToggle` | `AppTopBar` | `activateWorkbenchPanelMode(.library)` |
| Library groups videos by immediate parent folder. | `.library-group` | Library page view | Library grouping |
| Folder groups are collapsed on app startup or Library data refresh. | `.library-group.collapsed` | Library group view | Library presentation revision |
| Folder row is a full click target for disclosure. | `.library-group-header` | Disclosure row component | Local collapse state |
| Episode buttons flow in an adaptive grid. | `.library-episode-grid` | Library episode grid | Library video rows |

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

### 7.2 Library Episode Grid

Rules:

- Expanded folders show compact episode-rank buttons.
- The HTML prototype uses `EP01` style labels. Native implementation should use
  the same compact episode-rank label if this draft is accepted; it must still
  derive the rank from Finder-like natural sorting.
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
| Shiori uses grouped card presentation aligned with Search. | `.shiori-state`, `.shiori-card` | Shiori page view, `LiquidGlassSelectableCard` | Shiori groups |
| Shiori summary shows total shiori and file counts. | `.results-header` | Shiori summary view | Shiori counts |
| `Collapse All` keeps a fixed label. | `ui-capsule--command` | `LiquidGlassCapsuleButton.Kind.command` | Shiori group collapse state |
| Selecting a Shiori opens or seeks playback. | `ui-selectable-card` | Shiori card view | `openShiori` |

Rules:

- Shiori cards should show complete cue text without truncating subtitle lines.
- Shiori card selection updates immediately when activated.
- Saving or removing a Shiori must not pause playback, reset Search state, or
  rebuild Library rows.
- Shiori group collapse state is presentation state and must not rebuild Search
  or Library rows.
- Shiori playback control feedback uses the same transient playback feedback
  system as other playback commands.

## 9. Bottom Player UX

### 9.1 Layout

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| Bottom player uses three zones: source/title, transport, operations. | `.player-hud` | `LiquidGlassBottomPlayer` | Playback state |
| Left zone contains source/title capsule and volume. | `.source-toggle`, volume control | Bottom player left cluster | Current playback identity and volume |
| Center zone contains five transport controls. | `.transport-controls` | Bottom player transport cluster | Playback navigation |
| Right zone contains Shiori, copy, subtitles, side panel, speed, fullscreen. | `.right-controls` | Bottom player operations cluster | Playback and App commands |
| Progress scrubber spans the bottom-player width above the control row. | `ui-slider--progress` | `LiquidGlassSlider.Kind.progress` | `PlaybackViewModel` |

Rules:

- The bottom player stays visually stable when control values change.
- Text/value controls use capsule components. Icon-only controls use circular
  icon buttons.
- The source/title capsule shows the ASS file alias or accepted concise source
  title only. It must not show selected Search result rank or timestamp.
- The source/title capsule toggles expanded playback when playback exists. Its
  chevron rotates between `0°` collapsed and `-90°` expanded over `160ms` with
  an ease curve instead of swapping to a different chevron symbol.
- The speed capsule has fixed width and tabular text so preset changes do not
  shift neighboring controls.
- The speed capsule displays the existing App playback speed presets. If the
  HTML prototype omits a currently supported preset, the existing App preset
  range remains the behavior source until a product rule explicitly changes it.
- The bottom-player controls must not move vertically when the volume popover,
  speed menu, scrubber hover, or scrubber drag state appears.
- Disabled buttons remain visible but clearly inactive when the command is not
  available.
- Toggle icon controls use stable semantic glyphs with selected-state material
  and foreground contrast. Where the prototype defines matching outline and
  filled glyphs, the App should switch glyphs as part of the selected state.

### 9.2 Transport And Commands

Rules:

- Center transport order is previous episode, previous Search result, play or
  pause, next Search result, next episode.
- Previous and next episode commands are active only when a Library navigation
  target exists.
- Previous and next Search result commands use the complete active Search
  result order and are active only when that navigation target exists.
- Play or pause toggles current playback and must not be blocked by unavailable
  navigation commands.
- The Shiori control sits immediately before the copy-current-subtitle control
  in the right operation cluster.
- Subtitle visibility toggles the current player's subtitle overlay without
  resizing the bottom player.
- Side-panel visibility toggles the expanded playback side panel without
  moving the bottom-player controls.
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
- The volume popover must not move the playback controls vertically.
- The progress scrubber supports hover, drag, and seek.
- Scrubber hover and drag states may reveal a thumb or strengthen the track,
  but they must not change the bottom-player row height.

## 10. Expanded Playback UX

### 10.1 Layout Structure

Expanded playback uses this conceptual layout:

```text
Topbar
Expanded playback area
  Left black video base
    Aspect-fit video frame
    Floating bottom-player chrome
  Optional right side panel
```

Rules:

- Expanded playback replaces the main content area with a black playback base
  and optional right side panel.
- The right side panel occupies the full right column height.
- The video stage and floating bottom player occupy the left column.
- When the side panel is visible, it squeezes the left black video base. It
  does not cover the video base.
- Hiding the side panel restores that width to the black video base.
- The side panel keeps a usable minimum width. The video frame scales down
  before side-panel hiding is considered.
- The expanded playback surface must not show an extra video-title/avatar block
  inside the video stage or above the side-panel tabs.

### 10.2 Video Frame Sizing

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| The black left column is the sizing container. | `.video-stage` | `PlaybackExpandedLayout` | Window geometry |
| The video frame uses the active video's real aspect ratio. | `.video-frame[data-video-aspect]` | Video stage layout | `PlaybackViewModel.videoAspectRatio` |
| The frame maximizes inside the black base. | JS frame layout logic | Video stage layout | GeometryReader |
| Either width or height reaches the available limit. | JS frame layout logic | Video stage layout | GeometryReader |
| The frame is centered after aspect-fit sizing. | JS frame layout logic | Video stage layout | GeometryReader |
| The bottom player is floating chrome and does not participate in video frame sizing. | `.player-dock` | Bottom-player overlay | Chrome state |

Sizing algorithm:

1. Measure the left black video base after the side panel and topbar have been
   laid out.
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

- In expanded playback, the bottom player is positioned from the active left
  black video base, not from the full window width.
- The bottom player uses fixed left and right margins inside the black base.
- The bottom player's horizontal position and width update immediately during
  resize, side-panel show/hide, and window geometry changes.
- Horizontal position and width changes must not animate.
- Show and hide animations may slide vertically and fade opacity.
- The bottom-player chrome overlays the video base and does not reserve layout
  space.

### 10.4 Floating Chrome Visibility

Rules:

- Entering the black video base shows the floating bottom-player chrome.
- Leaving the black video base hides the floating bottom-player chrome.
- While the pointer remains inside the black video base, mouse movement or
  click activity shows the chrome and resets a 3-second idle timer.
- After 3 seconds without mouse or click activity inside the black base, the
  chrome hides.
- Keyboard playback shortcuts should not reveal the chrome.
- Hiding the chrome does not pause playback, change selection, or close menus
  except where a menu cannot remain visible without its anchor.
- The show/hide animation slides the chrome vertically while fading opacity.
- The chrome visibility animation must not animate horizontal geometry.

## 11. Expanded Playback Side Panel UX

| UX rule | Prototype anchor | SwiftUI owner | Behavior owner |
| --- | --- | --- | --- |
| Side panel contains `Search Results` and `Subtitles` tabs. | `ui-segmented-control` | `LiquidGlassSegmentedControl` | Active drawer state |
| Tabs sit at the top. | `.sidebar-top` | Side panel view | None |
| Active count label sits below tabs on the left. | `.sidebar-summary` | Side panel summary | Search/subtitle counts |
| No video title or `Search playback` label appears above tabs. | absence rule | Side panel view | None |
| Rows use compact selectable row cards. | `ui-selectable-row` | `LiquidGlassSelectableRow` | Search/subtitle row data |
| The panel can be hidden or restored from the bottom player. | `#sidePanelToggle` | Bottom-player side-panel button | `isPlaybackSidePanelVisible` |

Rules:

- The `Search Results` tab uses the complete active Search result order.
- Search Results rows may highlight query matches.
- The selected Search result row uses selected state and should scroll into
  view when practical.
- The Search Results tab does not show `Collapse All`.
- The `Subtitles` tab lists the current subtitle file in timestamp order.
- Subtitles rows do not apply keyword highlighting.
- The current playback subtitle row uses selected state for context and should
  scroll into view when practical.
- Selecting another Search result from the side panel preserves the side-panel
  list while playback opens or seeks.
- The side panel must not briefly clear to `0 results` or a loading panel
  during result-to-result jumps when the current Search result list is still
  valid.
- Hiding or restoring the side panel must not pause playback, clear selection,
  or resize the bottom-player controls.

## 12. Playback Fullscreen UX

Fullscreen playback uses the native fullscreen lifecycle but the Liquid Glass
bottom-player visual language.

Rules:

- Fullscreen playback continues to use AppKit native fullscreen behavior and
  the existing playback fullscreen manager.
- The HTML prototype represents App fullscreen with a local prototype state,
  not with the browser Fullscreen API. This avoids browser-level fullscreen
  behavior being mistaken for the native App fullscreen contract.
- In the HTML prototype, the fullscreen state marker must not redefine player
  layout geometry. It must not change window size, body padding, toolbar
  height, video-stage sizing, video-frame aspect-fit calculation, side-panel
  participation, or bottom-player positioning.
- The playback render container must not be duplicated or moved into a second
  backend render state.
- The normal workbench shell is hidden during playback fullscreen without
  losing Library, Search, Shiori, scroll, selection, or focus state.
- The fullscreen chrome uses the same non-fullscreen bottom-player visual
  family. The old dark gradient fullscreen control bar is not the target UI.
- Fullscreen chrome includes the playback controls needed for video review:
  progress, source/title when appropriate, volume, transport, Shiori, copy,
  subtitle visibility, speed, and exit fullscreen.
- Fullscreen state and expanded-playback side-panel visibility are independent.
  Entering or exiting fullscreen must not hide, show, reset, or otherwise
  mutate the side-panel visibility state.
- If the side panel is visible before entering fullscreen, it remains visible
  in fullscreen. If it is hidden before entering fullscreen, it remains hidden
  in fullscreen.
- The fullscreen button uses the enter-fullscreen glyph outside fullscreen and
  the two inward-touching arrows exit-fullscreen glyph while fullscreen is
  active.
- Entering and exiting fullscreen show text-only feedback: `Fullscreen` and
  `Exit Fullscreen`.
- Text-only fullscreen feedback uses the compact capsule HUD size, not the
  larger icon-centered feedback HUD dimensions.
- Entering fullscreen immediately hides the chrome and cursor once.
- Mouse movement or click activity reveals the chrome and cursor.
- Keyboard playback shortcuts do not reveal the chrome or cursor.
- After 3 seconds without mouse or click activity, fullscreen chrome and cursor
  hide again.
- Clicking the video surface toggles play/pause unless the click targets a
  chrome control.
- The fullscreen exit control exits playback fullscreen through the existing
  fullscreen manager.
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
- Playback shortcuts dispatch through the same command model as playback
  buttons, mouse video clicks, menu selections, and slider gestures.
- Commands that are unavailable for the current playback state must not mutate
  selection, playback, Search data, or Shiori data.

### 13.2 Shortcut And Mouse Command Mapping

| Input | Command | Prototype anchor | SwiftUI owner | Behavior owner | Feedback HUD | Chrome visibility effect |
| --- | --- | --- | --- | --- | --- | --- |
| `Space` | Toggle play/pause | `#playBtn`, `ui-feedback-hud` | Bottom-player transport button, `LiquidGlassFeedbackOverlay` | `PlaybackViewModel.togglePlayback` | `Play` or `Pause` | Keyboard: none. Mouse/button: normal pointer activity rules. |
| Left click on visible video surface | Toggle play/pause | `.video-stage`, `.video-frame`, `ui-feedback-hud` | Video stage input layer | Playback command model | `Play` or `Pause` | Shows chrome and resets the idle timer. |
| `C` | Toggle subtitle visibility | `#subtitleToggle`, `.subtitle-overlay`, `ui-feedback-hud` | Subtitle toggle button, feedback overlay | Playback subtitle visibility state | `Subtitles On` or `Subtitles Off` | Keyboard: none. Button: normal pointer activity rules. |
| `F` | Enter or exit playback fullscreen | `#fullscreenButton`, prototype fullscreen class, `ui-feedback-hud` | Fullscreen button, fullscreen chrome | Existing fullscreen manager | Text-only `Fullscreen` or `Exit Fullscreen` | Keyboard does not reveal chrome; fullscreen entry follows fullscreen rules. |
| `A` | Previous Search result | `#previousResultButton`, `.sidebar-row`, `ui-feedback-hud` | Transport previous-result button | Search navigation snapshot | `Previous Result` on the leading side, or `No Result` | Keyboard: none. Button: normal pointer activity rules. |
| `D` | Next Search result | `#nextResultButton`, `.sidebar-row`, `ui-feedback-hud` | Transport next-result button | Search navigation snapshot | `Next Result` on the trailing side, or `No Result` | Keyboard: none. Button: normal pointer activity rules. |
| `Q` | Copy current subtitle | Copy button, `ui-feedback-hud` | Copy subtitle button | Clipboard command | `Subtitle Copied` or `No Subtitle` | Keyboard: none. Button: normal pointer activity rules. |
| `S` | Save or remove Shiori | `#shioriButton`, `ui-feedback-hud` | Shiori toggle button | Shiori command model | `Shiori Saved` or `Shiori Removed` after final state | Keyboard: none. Button: normal pointer activity rules. |
| `Left Arrow` | Seek backward 5 seconds | Progress slider, `ui-feedback-hud` | Progress slider and feedback overlay | Playback seek command | Accumulated rewind total, such as `- 15s` | Keyboard: none. |
| `Right Arrow` | Seek forward 5 seconds | Progress slider, `ui-feedback-hud` | Progress slider and feedback overlay | Playback seek command | Accumulated forward total, such as `+ 15s` | Keyboard: none. |
| `Up Arrow` | Increase volume by 5 | Volume control, `ui-feedback-hud` | Volume button/slider and feedback overlay | Playback volume state | `Volume NN%` | Keyboard: none. |
| `Down Arrow` | Decrease volume by 5 | Volume control, `ui-feedback-hud` | Volume button/slider and feedback overlay | Playback volume state | `Volume NN%` or `Muted` | Keyboard: none. |
| `Shift+,` | Decrease speed by 0.25x | `#speedButton`, `ui-feedback-hud` | Speed value capsule and feedback overlay | Playback speed state | Current speed, such as `0.75×` | Keyboard: none. |
| `Shift+.` | Increase speed by 0.25x | `#speedButton`, `ui-feedback-hud` | Speed value capsule and feedback overlay | Playback speed state | Current speed, such as `1.25×` | Keyboard: none. |

### 13.3 Video Surface Mouse Rules

Rules:

- A primary-button click on the video surface toggles play/pause.
- The video-surface click handler must ignore clicks that target bottom-player
  controls, side-panel controls, popup menus, sliders, text inputs, or any
  other interactive control.
- Clicking controls must run only that control's command, not the video
  play/pause command.
- Mouse movement or click activity inside the black video base follows the
  chrome visibility rules in sections 10.4 and 12.
- Mouse activity outside the black video base must not toggle playback.
- Secondary click behavior is not defined by the Liquid Glass rewrite and must
  preserve existing platform behavior until separately specified.

### 13.4 Feedback Overlay Rules

Rules:

- Playback command feedback is rendered by `ui-feedback-overlay` and
  `ui-feedback-hud` over the active video stage.
- The feedback overlay is non-interactive and must never intercept mouse,
  keyboard, slider, menu, or video clicks.
- The feedback HUD is centered within the active black video base, not within
  the full window when a side panel is visible.
- The feedback HUD may temporarily sit above subtitles because it is transient,
  but it must not permanently reserve space or change subtitle layout.
- The same feedback component is used in expanded playback and playback
  fullscreen.
- If the video surface is not visible, the command may still update playback
  state, but video-stage feedback is shown only when there is a visible video
  stage to host it.
- Each accepted command restarts the current feedback HUD instead of stacking
  multiple HUDs.
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
- Search rows remain cached until the query, loaded result page, Search group
  collapse state, or Search ordering inputs change.
- Shiori rows remain cached until Shiori records or Shiori group collapse state
  change.
- Playback state changes must not rebuild Library, Search, or Shiori rows
  unless a product-specific state indicator requires a targeted update.
- Switching modes changes visible surfaces, not the underlying data model.
- Collapsing, expanding, hiding, or restoring panels changes layout state, not
  data state.
- Search result card rendering may use SwiftUI lazy containers, custom layout,
  or flattened row structures as needed to preserve first-screen rendering and
  scroll performance.
- Large grouped content should avoid wrapping all rows of a group inside one
  eagerly measured view when that would defeat laziness.

## 15. Native Differences Allowed

The App may differ from HTML when platform behavior requires it.

Allowed differences:

- Native traffic lights and titlebar mechanics.
- Native AppKit fullscreen transitions and Space behavior.
- Native material and vibrancy implementations that preserve the accepted
  visual hierarchy.
- Native font rendering and accessibility focus behavior.
- Native media rendering, file access, Finder reveal commands, sandbox
  behavior, and persisted state.
- SwiftUI virtualization and layout implementation details that preserve the
  visible UX rules above.

Not allowed:

- Changing Search lazy loading or first-screen rendering to match static HTML.
- Treating prototype mock data as product data.
- Implementing prototype-only test controls in the production App.
- Letting floating bottom-player layout affect video aspect-fit sizing.
- Letting horizontal bottom-player geometry animate during resize.
- Losing Search, Library, Shiori, playback, or fullscreen state as a side
  effect of visual layout changes.

## 16. Open Review Questions

Open questions before this mapping becomes accepted:

- Should Library episode labels use the HTML `EP01` format, or should the
  native App keep number-only rank labels while preserving the same grid
  geometry?
- Should fullscreen chrome include the source/title capsule, or only transport
  and operation controls when screen width is constrained?
- Should the floating bottom-player margin inside the black base be a fixed
  token shared by windowed expanded playback and fullscreen playback?
