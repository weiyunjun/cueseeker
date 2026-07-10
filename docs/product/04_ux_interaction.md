# UX Interaction

Status: Draft

## 1. Core Workflow

The primary workflow is:

```text
Open app
Add or confirm local subtitle folder
Index subtitles
Search text
Review results
Click result
Central Playback Area opens or updates
Video plays at matching timestamp
Collapse the shared content panel when focusing on playback
```

The accepted next Search workflow is:

```text
Open app
Type a query in the topbar Search field
Press Return
Review grouped Search results in the main content area
Click result
Search-launched playback opens in the main content area
Use the bottom player and the playback overlay side panel for result and
subtitle navigation
```

This Search workflow supersedes the old side-panel Search entry point. Library,
Shiori, and Settings may remain in their current surfaces until later migration
work changes them.

Info-page / video-page model (refactor; see
`docs/proposals/2026-05-ui-info-page-video-page-refactor.md`, ADR-0013, and the
authoritative behavior in `docs/product/12_liquid_glass_ux_mapping.md`):

- The info page is the workbench (Library / Search / Shiori). The video page is
  a dedicated full-window presentation layered above a still-alive info page,
  not a route swap, so info-page state, scroll, disclosure, and Search cache
  stay alive underneath.
- Selecting a playable result opens the video page. The originating info-page
  mode is remembered.
- Closing the video page (the top-bar close control) ends the session and
  returns to that originating info-page mode with its state intact.
- A search performed from the video page updates shared Search state, so the
  info page reflects it on return without a rebuild.
- Where older sections below describe a bottom-launched overlay, a squeezing
  right side panel, an expand/collapse video chevron, or a drawer that pauses
  playback, the video-page behavior in doc 12 (§5, §10.1, §10.4, §11)
  supersedes those descriptions.

Known-content review may also start from Library:

```text
Open app
Use the fixed Mode Rail to show Library
Choose a known video
Playback Area opens or updates from the Library resume position
Search and Shiori remain available from the Mode Rail without changing playback
```

## 2. First Launch

On first launch, if no folders are configured:

- The app should make it obvious that a local subtitle folder must be added.
- The user should be able to add a folder without navigating through unnecessary screens.
- The app should explain indexing status only when needed.

## 3. Search Interaction

Search should feel immediate.

Accepted topbar Search transition:

- A fixed-width Search field belongs in the topbar.
- Typing in the topbar Search field edits a draft query only.
- Pressing Return submits the draft query as the active Search query.
- Submitted Search results appear in the main content area.
- The Search results page should not render a duplicate Search field below the
  topbar.
- The old side-panel Search entry should no longer be the active Search entry
  point after this transition is implemented.
- Library, Shiori, and Settings remain in their current surfaces for the first
  Search UI pass.
- First-pass Search UI polish is less important than complete Search-to-playback
  functionality.
- Clicking a Search result opens the dedicated video page (full-window video
  with its own top bar). There is no bottom-launched squeezing overlay.
- There is no video expand/collapse chevron control; the video page is entered
  by selecting a playable result and left through the top-bar close control.
- The bottom player provides a panel toggle between the subtitle visibility and
  playback-speed controls. It shows or hides the centered overlay panel
  (`Search Results` / `Subtitles`) without moving the bottom-player controls.
- The overlay panel floats over the video and does not change video size, so
  toggling it is not a playback-size-changing command and is not subject to the
  rapid-repeat resize guard. The panel never auto-hides.
- The `Search Results` panel lists search matches and may highlight the active
  query. The `Subtitles` panel lists the full subtitle-file cues by source
  sequence number and timestamp without query highlighting.
- The side-panel tabs sit at the top of the panel. The active count label sits
  below them on the left. The panel must not show a separate video title or
  `Search playback` label above the tabs.
- Opening another Search result from the overlay side panel should preserve the
  existing side-panel list while playback seeks or opens the new result. The UI
  must not clear to an intermediate `0 results` or loading panel during that
  jump.

Expected behavior:

- Search controls and Search results live in Search mode inside the Shared
  Content Panel.
- The native window identity remains `CueSeeker`, but the visible custom
  topbar centers the Search field instead of rendering a `CueSeeker` title.
- The fixed Mode Rail contains Library, Search, and Shiori icons.
- A Settings button may sit at the bottom of the fixed Mode Rail.
- Clicking the selected Mode Rail icon collapses the Shared Content Panel with
  the existing drawer animation.
- Clicking an unselected Mode Rail icon switches modes. If the Shared Content
  Panel is collapsed, the same action expands it.
- Switching between Library, Search, and Shiori must not change the Shared
  Content Panel width.
- The Shared Content Panel side is configurable in Settings. The default is
  `Left`; choosing `Right` should immediately place the playback area first,
  followed by the Shared Content Panel and then the Mode Rail.
- Settings opens from `CueSeeker > Settings...` in the macOS app menu or from
  the Mode Rail bottom Settings button. The button opens or focuses the
  independent Settings window and must not act as a panel mode.
- The Shared Content Panel can be collapsed when the user wants to focus on
  playback.
- Collapsing the Shared Content Panel should preserve the current Search query,
  result state, selected result, current panel mode, Shiori state, Library
  disclosure state, and playback context.
- Collapsing the Shared Content Panel must not pause playback.
- Typing updates results after a short debounce.
- Empty search shows an empty or guidance state.
- Invalid search syntax should not crash the app.
- Search results should not flicker unnecessarily.
- Search should show a muted total result count below the search field when a
  query has results.
- Repeating the same query should not trigger expensive work without reason.

Grouped result behavior:

- Search results should be grouped by subtitle file in a single flat level.
  Search mode does not aggregate subtitle files under a parent-folder
  Show layer; the rejected Show / Episode / Hit proposal is preserved in
  `docs/proposals/` for context.
- Groups should be expanded by default.
- Clicking a subtitle-file header should collapse or expand that group. The
  group's disclosure chevron lives in the left rail and rotates between
  `0°` (collapsed) and `90°` (expanded) over `160ms` with an ease curve
  when toggled. The same chevron animation is shared with the Library
  folder row.
- Collapsing a group should only hide that group's loaded rows. It must
  not change result counts, search scope, or selection identity.
- Result lazy loading should remain based on matched cue groups, not
  subtitle file groups.
- Result lazy loading should use 100 cue-group results as the initial
  visible budget and 100 cue-group results for each incremental load.
- Search result thumbnail previews are controlled by the Settings
  `Experimental Features` category. The `Search Result Thumbnails` setting is
  disabled by default.
- When Search result thumbnail testing is disabled, Search rows should behave
  as plain text rows and must not request thumbnail cache entries, create
  thumbnail work, or start frame extraction processes.
- When Search result thumbnail testing is enabled, each loaded 100-result page
  should immediately schedule thumbnail generation for those 100 cue-group
  rows. Thumbnail scheduling is tied to loaded cue-group rows, not subtitle file
  groups.
- Thumbnail generation should use persistent disk cache first. Rows should reuse
  cached thumbnails across app sessions before invoking frame extraction again.
- The first thumbnail test uses `ffmpeg` to generate `160x90` AVIF images from
  the midpoint between each cue group's start and end timestamps. The initial
  generation worker budget is 20 concurrent `ffmpeg` tasks.
- Before a thumbnail loads, the row should show a lightweight skeleton-style
  picture placeholder. It should not show a black or flat gray block.
- Lazy loading should trigger only from these user-visible actions:
  scrolling to the bottom when more global rows can be shown, clicking the
  expand-all control when all groups are collapsed, or expanding an
  individual subtitle-file header.
- Per-file match totals should remain available in search grouping state
  for lazy-loading and future sorting behavior. Header presentation should
  append the per-file total to the friendly subtitle group title as plain
  text and must not render a per-file count badge or separate count
  component.
- The friendly subtitle group title should use the immediate parent folder
  name plus the subtitle file's one-based Finder-like natural-sort rank
  among visible regular sibling subtitle files with the same final
  subtitle extension, such as `葬送的芙莉莲 - 05`.
- Users can change the displayed work title by renaming the parent folder
  without changing the subtitle or video filenames.
- The full subtitle path remains available through the Playback Area file
  actions and internal result state for source identity and diagnostics.
- The collapse or expand-all control should toggle all subtitle-file
  groups in the current query at once.
- The collapse or expand-all control should track only its own global
  action state. Manually collapsing or expanding a single subtitle-file
  header should not change that control's label.
- Collapsing all groups should reduce visible subtitle rows to zero while
  keeping subtitle-file headers visible.
- Expanding all groups should reveal at most one global 100-result batch.
  It should not reveal 100 rows per subtitle file, and it should not
  restore previously scrolled-in rows beyond the current 100-row budget
  solely because those rows were visible before collapse.
- Expanding an individual subtitle-file header should reveal at most the
  first 100 matching rows for that subtitle file. If the file has fewer
  matches, all of its matches should be visible.
- Collapse actions should not trigger a search, fetch another lazy-loading
  page, change the lazy-loading cursor, or mutate result counts.

Result row visual rules:

- Selected result rows use the macOS system accent color
  (`NSColor.controlAccentColor`, surfaced through `Color.accentColor`),
  reflecting the user's system accent color choice. A future settings
  option may expose a custom accent override.
- Result rows do not render a cue start timestamp. Within a subtitle-file
  group rows are ordered by ascending cue start time, so spatial order
  conveys time order without a dedicated column.

Search focus behavior:

- User-initiated app commands should clear Search field focus.
- Selecting a search result should clear Search field focus.
- Clicking App-owned expand or collapse buttons should clear Search field focus.
- Future App-owned feature buttons should clear Search field focus by default.
- Selecting another Mode Rail item should clear Search field focus.
- Opening Settings may clear Search field focus, but it must not change the
  active workbench mode, selected result, Shared Content Panel visibility, or
  playback state.
- Clicking anywhere in the Playback Area should clear Search field focus.
- System-level app switching should not intentionally clear Search field focus.
- Returning to the app after backgrounding should preserve the Search field focus state when AppKit preserves the first responder.
- Double-clicking the titlebar to resize the window should not intentionally clear Search field focus.
- Clicking native traffic light controls should not intentionally clear Search field focus.

## 4. Workbench Mode Rail And Panel Responsibility Model

CueSeeker's main workspace should preserve distinct content responsibilities
around the central playback experience while using one shared left-side panel.

The Fixed Mode Rail is a stable, non-resizable selector for workbench panel
modes:

- Library.
- Search.
- Shiori.

The Shared Content Panel is the resizable surface for the selected mode:

- Library browsing for known-content navigation.
- Search and Search result aggregation for keyword discovery.
- Shiori browsing and management for saved subtitle moments.

The Shared Content Panel is not allowed to resize itself merely because the user
switches modes. Its default and minimum width should be `420pt`, matching the
previous Search Panel minimum width. User resizing should persist and apply to
all modes.

This model keeps playback central. After the user selects a Library video,
Search result, or Shiori row, attention can return to playback while the active
panel mode remains available.

Responsiveness boundaries:

- Library is a static known-content resource area. Its indexed row snapshot
  should change only when folders are added, removed, reindexed, or explicitly
  refreshed. Manual collapse or expand, resizing, Search interactions, and
  playback interactions are presentation changes over that snapshot, not reasons
  to rebuild Library rows.
- Search is an active query and aggregation area. Search input, result loading,
  Search-group collapse state, Queue actions, and future learning actions should
  not rebuild Library rows or mutate Library state.
- Shiori is a saved-content browsing area. Opening, grouping, or collapsing
  Shiori records should not rebuild Library rows or Search result rows.
- Playback is the central video review area. Opening media, seeking,
  play/pause, fullscreen, subtitle visibility, and playback-control state should
  not rebuild Library rows, Search result rows, or Shiori rows unless the user
  explicitly performs a mode-specific action.
- Closing playback is an explicit playback-session command. It should clear the
  current playback selection across Search, Library, Shiori, and playback side
  panel rows, but it must not clear Search results, database search caches,
  Shiori records, Library rows, group disclosure presentation state, or any
  unrelated workbench data.
- Switching Mode Rail modes should preserve inactive mode state where practical.
  It should not clear Search results, Shiori groups, Library disclosure state,
  selected rows, or playback context.
- Collapsing or expanding the Shared Content Panel should preserve the panel's
  current content state. It should not destroy and recreate large result lists
  as a side effect of a layout change.
- During Shared Content Panel collapse or expand animations, the Playback
  Area's black video background and actual video frame should resize together.
  Users should not see the black container and the native video layer drift out
  of sync.
- Commands that change the available playback size should not overlap. While a
  Shared Content Panel toggle, bottom-player video overlay expand/collapse,
  titlebar double-click zoom, playback fullscreen enter/exit, `F` fullscreen
  toggle, or Escape fullscreen exit animation is active, other command-style
  playback-size changes should be ignored until the current animation ends.
  Manual divider dragging remains a direct resize interaction.
- Search field focus is Search mode interaction state. Changing focus should not
  invalidate Library content, Shiori content, or playback content.
- Side-panel scrollable lists must reserve room for the macOS scrollbar
  on the trailing edge so that list content keeps equal visual left and
  right margins when the scrollbar appears. The reservation rule is
  applied uniformly to the Library list and to the Search and Shiori result
  lists: each scrollable container uses an additional
  `16pt` trailing inset on top of its own row padding, and each pane's
  header uses a matching `28pt` total trailing padding (`12pt` content
  margin plus the same `16pt` reserve) so headers align with the list
  rows below them.
- The visible playback clock used by SwiftUI controls may update at a lower
  frequency than the native video playback clock. This must not affect native
  video playback smoothness or seek accuracy.
- ASS playback timing and render-source coordination is performance-sensitive
  and should not be refactored as part of the first UI invalidation cleanup.
  Any later ASS timing-source change must preserve immediate subtitle loading
  after Search result selection.

## 5. Result Selection

When the user selects a result:

- In the current Liquid Glass target, Search, Library, and Shiori main-page
  cards do not retain selected-card visuals after activation.
- The visible selected-row treatment belongs to the playback side panel. Right
  playback side-panel rows should still show the current playback context with
  selected styling and should update immediately when the current playback row
  changes.
- The selected row does not show a cue start timestamp. Within a
  subtitle-file group rows are ordered by ascending cue start time, so
  spatial order conveys time order without a dedicated column.
- Unselected rows use a slightly muted primary label color for subtitle
  text, preserving hierarchy without making unselected results as faint as
  group headers.
- Search result subtitle text should keep internal SRT and ASS line breaks
  readable with extra wrapped-line spacing, especially for bilingual cue text.
- The app should remain in the CueSeeker workbench and open or update the
  central Playback Area.
- If the Shared Content Panel is visible in Search mode, selecting a result
  should keep it visible so result-to-result review remains available.
- Playback should start at or near the matching timestamp.
- If the same video is already open, the app should seek instead of reopening when practical.
- If the video file is missing, the app should show a clear error.
- Selecting a different result should switch video or seek within the current video and auto-play.
- Selecting a grouped ASS cue result should use the cue group's `start_ms` as
  the playback target and begin asynchronous source ASS rendering preparation.
- Result selection and Playback Area updates should remain responsive even when
  source ASS rendering is slow or unavailable.
- The Playback Area should expose `Video Folder` and `Subtitle Folder`
  buttons below the video instead of read-only path metadata.
- Clicking `Video Folder` should open Finder to the matched video's containing
  folder and select the video file.
- Clicking `Subtitle Folder` should open Finder to the source subtitle's
  containing folder and select the subtitle file.

Search-launched playback result navigation:

- `Previous Result` and `Next Result` navigate through the complete active
  Search result order.
- The order must match the Search results page order, including subtitle-file
  group order and row order inside each group.
- Navigation must not use a separate ordering scoped to the current video path
  or subtitle path.
- The current playback time identifies the current Search-result anchor. If
  playback has advanced to a later Search hit, that later hit becomes the
  current anchor before previous or next navigation is applied.
- Navigation may cross subtitle files and videos.
- The app should be able to show the current Search-result position and total
  result count from the same ordered result source.

The video-page `Results` tab shows the same grouped Search result content as the
Search results page. The current row uses selected state and should be scrolled
into view. It lives in the centered overlay panel, which floats over the video,
does not resize the video, does not pause playback, never auto-hides, and does
not include `Collapse All`. Clicking a row during playback seeks to or opens
that result.

The video-page `Subtitles` tab shows the current subtitle file in timestamp
order. It does not apply keyword highlighting because it is context navigation,
not query-match presentation. The row corresponding to the current playback
subtitle uses selected state only and should be scrolled into view. It lives in
the same centered overlay panel, does not resize the video, and does not pause
playback. Clicking a row seeks to that subtitle.

## 6. Visual Feedback and Hover

- **Mode Rail Buttons**: Library, Search, and Shiori icons in the fixed Mode
  Rail use a subtle hover treatment and a clear selected state.
- **Search Field**: The Search field is a `6pt` rounded pill with a
  `1pt` separator border by default. On focus it shows a `1.5pt` accent
  inner stroke plus a `3pt` accent outer ring at `18%` opacity; a
  constant `3pt` outer padding prevents layout jitter on focus state
  changes.
- **Search Results**: Interactive result rows emphasize the selection
  state over hover. The selected background uses the macOS system accent
  color and aligns with the group disclosure rail's left edge. Result rows
  use no divider lines, keep readable bilingual line spacing, and do not
  render a cue start timestamp.

## 7. Playback Interaction

M1 playback interaction should be minimal.

Required interactions:

- Auto-play after selecting a result.
- Toggle play/pause by clicking the embedded video.
- Seek.
- Jump from search result to timestamp.
- Continue playback when the Shared Content Panel is collapsed.
- Opening Settings does not pause playback or switch away from the CueSeeker
  workbench.
- Pause playback when switching from the CueSeeker workbench to another future
  main-window workspace section if that section is documented to leave the
  playback review context.
- Preserve the current selected result when the Shared Content Panel is
  collapsed.
- Reopening the Shared Content Panel should not automatically change playback
  state.

Topbar Search playback interaction:

- Selecting a Search result opens a Search-launched playback page in the main
  content area.
- The playback page keeps the video at the source aspect ratio with fit
  behavior and stable space below for command buttons.
- The first command row includes `Video Folder`, `Subtitle Folder`,
  `Previous Result`, `Next Result`, `Results`, and `Subtitles`.
- `A` triggers `Previous Result`; `D` triggers `Next Result`.
- `Results` and `Subtitles` are tabs in the centered overlay panel toggled from
  the bottom player. The panel floats over the video, does not resize the
  video, does not pause playback, and never auto-hides.
- `Results` is a nearby Search-result context tab.
- `Subtitles` is a current-subtitle-file context tab.

Keyboard interactions should not interfere with text input.

Accepted M1 behavior:

- Selecting a result calls playback immediately.
- Re-selecting a timestamp in the same video should use seek rather than reloading the file.
- The embedded video view is always inside the app window.
- Normal result preview should use the central Playback Area instead of
  dedicated playback-page navigation.
- External player windows are not acceptable for the core workflow.

M2 playback interaction model:

- Playback should expose explicit controls for the actions the user can perform from the video area.
- Playback should include progress and seek interaction suitable for reviewing subtitle context.
- Playback actions should provide clear visual feedback, such as a lightweight operation HUD or animation when the user plays, pauses, seeks, or triggers another command.
- Playback buttons, progress controls, click interactions, and keyboard shortcuts should dispatch through the same underlying playback command model.
- The video page exposes its close command as the red traffic-light control in
  the video-page top bar. Close ends the current playback session, exits
  playback fullscreen if necessary, clears playback-derived selection
  highlights, hides the bottom player and top bar, and returns to the
  originating info-page mode with its state intact. There is no video-frame
  Close capsule. Minimize (yellow) collapses playback; zoom (green) enters
  fullscreen.
- Playback fullscreen should fullscreen the video experience itself, not the full app shell.
- Playback fullscreen should use the main CueSeeker window's AppKit native
  fullscreen behavior, then switch that window into a video-only presentation
  until playback fullscreen exits.
- Entering and exiting playback fullscreen should feel like a standard macOS
  fullscreen transition, with the system managing Dock, menu bar, desktop,
  wallpaper, Space, app switching, and system overlay behavior.
- Entering or exiting playback fullscreen must not create a second playback render container or duplicate backend render state.
- Entering playback fullscreen should immediately put Player UI and the cursor
  into their hidden states, regardless of whether Player UI was visible before
  fullscreen.
- Player UI and cursor visibility are driven by mouse movement while the cursor
  is governed by the current player, not by mouse clicks or keyboard shortcuts.
- While Player UI is visible, three seconds without mouse movement while the
  cursor is governed by the current player hides Player UI and the cursor.
  There is no frozen display-check area. The full chrome-visibility contract
  is the Player-UI / cursor visibility state machine (v4) in
  `docs/product/12_liquid_glass_ux_mapping.md` §10.4.
- App switching while playback fullscreen is active should follow standard
  macOS Space behavior and should not reveal a separate CueSeeker workbench
  window that has lost its video surface.
- The progress bar and its enlarged hit area are named the `Timeline Zone`.
- The button row below the progress bar is named the `Transport Controls Zone`.
- Together, the `Timeline Zone` and `Transport Controls Zone` form the `Playback Operation Zone`.
- Mouse clicks in the `Playback Operation Zone` should control only the targeted playback control and must not fall through to video-surface play or pause toggling.
- Hovering or dragging the `Timeline Zone` should not change the vertical position of the `Playback Operation Zone`.
- Pressing or dragging the `Timeline Zone` should enter a modal
  timeline-scrubbing interaction. During that interaction the scrubber, tooltip,
  and visible playback time follow the drag target immediately; playback is
  paused; and non-Timeline playback shortcuts, button hover states, button
  clicks, and menu interactions are disabled.
- During timeline scrubbing, the video surface should show the nearest keyframe
  at or before the current drag target. The video is not playing while this
  happens, and the keyframe frame is rendered into the video surface rather than
  shown as a separate preview overlay.
- Timeline scrubbing should hide the white hover-ahead track segment and update
  the video surface only when the drag target maps to a different previous
  keyframe. Mouse release commits a real seek to the final requested timestamp
  and restores playback only if it was playing before the drag began.
- Playback speed selection should use an app-drawn upward menu that opens from the speed control.
- The speed menu should appear when the speed control is clicked, without requiring a separate arrow button.
- The speed menu should not have a separate show or hide animation.
- The speed button's hover area and click area should be identical and should stay stable while the menu is open.
- Clicking outside an open speed or secondary-actions menu should close that menu.
- Keyboard shortcuts in fullscreen should not reveal the playback operation controls.
- The normal bottom player has no Shiori or copy-current-subtitle button.
- The subtitle button is a standalone circular control and toggles the current
  player's subtitle visibility when the playback engine exposes a subtitle
  track or subtitle display state.
- Playback interaction design should remain focused on subtitle context review, not a full media-player feature set.

Current M2 implementation and accepted fullscreen correction:

- Playback fullscreen uses main-window video-only presentation with AppKit
  native fullscreen behavior.
- Playback fullscreen keeps the same playback render container in the main
  window hierarchy and does not move it across windows.
- The normal workbench shell should be hidden during playback fullscreen without
  losing panel, selection, scroll, or focus state.
- Fullscreen playback hides player UI and cursor immediately on entry.
- Playback reveals player UI and cursor from mouse movement inside the player
  area, not from mouse clicks or keyboard shortcuts.
- AppKit fullscreen lifecycle replaces manual Theater Mode suspension and
  separate-window playback fullscreen handling for app switching and
  deactivation behavior.
- Playback controls and keyboard shortcuts share the same playback command state through the playback view model.
- The bottom player is visible only while the video playback page is visible.
  Search, Library, and Shiori workbench pages must not show the bottom player.
- In playback visibility rules, Player UI means the bottom player plus the
  video-page top bar. Player UI and cursor visibility follow the Player-UI /
  cursor visibility state machine (v4) in
  `docs/product/12_liquid_glass_ux_mapping.md` §10.4. There is no frozen
  display-check area and no dock/top-bar exemption; regaining App focus alone
  does not reveal Player UI.
- The bottom-player left source/title collapse control is no longer part of the
  target UX. The volume button is the leftmost bottom-player control; the other
  controls keep their relative order.
- Close playback should stop the current native playback session. It should
  preserve reusable playback infrastructure, persisted playback preferences,
  Search result cache, and Library playback history rules.
- Shortcut and control actions show transient feedback overlays for subtitle
  visibility, play/pause, relative seek, volume, speed, and cue-scoped Subtitle
  Focus actions.
- The visible playback speed menu offers `0.5x`, `0.75x`, `1.0x`, `1.25x`, `1.5x`, `1.75x`, and `2.0x`.
- The speed button hover area, speed button click area, and speed menu width are aligned to the same horizontal bounds.
- Keyboard shortcuts adjust speed in `0.25x` steps and are clamped to the same `0.5x` through `2.0x` range as the playback controls.
- The previous Flutter shortcut model was used as a reference, but the native
  M2 map uses `Q` for normal-playback subtitle visibility, reserves `S` and `C`
  for Playback Subtitle Focus, removes the bottom-mask shortcut, and changes
  speed adjustment to `Shift+,` and `Shift+.`.

## 8. Library And Timeline Interaction

Library and Timeline are content-navigation modes.

Library behavior:

- Library should browse playable videos rather than raw subtitle files.
- Library should appear in the Shared Content Panel with a gray background.
- Library should appear populated immediately after app restart when indexed
  video metadata already exists locally. A visible Loading or empty state during
  startup is only acceptable when no persisted Library rows exist or the
  database cannot be opened.
- Library should collapse or expand when the selected Library icon in the Mode
  Rail is clicked.
- Library should be horizontally resizable after launch.
- Library's default width should equal its minimum width.
- The Shared Content Panel's first default and minimum width should be `420pt`,
  matching the previous Search Panel minimum width.
- Changed Shared Content Panel width should persist across launches.
- Library should group videos by immediate parent folder only. It should not
  render nested folder trees in the first implementation.
- Folder groups should be sorted with Finder-like natural ordering.
- Folder groups should be collapsed on app startup.
- Users can collapse or expand individual folder groups during the current
  session.
- Folder group collapse or expand state should not persist across launches.
- Folder group collapse or expand should only update the current presentation
  state over the persisted Library snapshot. It should not regroup, resort, or
  regenerate Library rows.
- Reindexing or refreshing Library data should reload the Library list and
  reset all folder groups to collapsed.
- Library should not expose a panel-wide `Collapse All` or `Expand All`
  control. Folder disclosure remains per-folder.
- Folder rows should use a two-line layout: the folder display name on top and
  an episode-count subtitle below. The subtitle reads `N episodes` by default
  and `N episodes · Playing M` while a Library-launched playback session is
  active for a video in this folder, where `M` is that video's one-based
  sibling rank among playable sibling videos in the same folder.
- Folder rows must not display a leading first-letter or first-character avatar
  block.
- The full folder row should be the click target that toggles expand or
  collapse. The chevron sits on the left of the folder row as a visual
  indicator and rotates between `0°` (collapsed) and `90°` (expanded) over
  `160ms` with an ease curve when toggled. The same chevron animation and
  left-side position are shared with Search and Shiori group disclosure rails.
- Videos inside a folder should be sorted with the same Finder-like natural
  ordering used to derive the row rank.
- Expanded folders should show a numbered episode-button grid where each
  button's label is that video's one-based sibling rank. File names, durations,
  and language tags should not be drawn inside the grid.
- The episode grid should use minimum-button-width auto-flow columns so the
  column count adapts as the user resizes the Shared Content Panel.
- The episode grid should be indented slightly to the right of the folder
  row's left edge so the hierarchy is visible. The indent should remain small.
- Episode buttons should use only three visual states: default, hover, and
  playing. The playing state highlights only when the current playback was
  launched through Library.
- When the user expands a folder that contains the currently Library-launched
  playing video, the panel should auto-scroll that video's episode button into
  view as part of the expand transition. Auto-scroll should not fire for
  already-expanded folders or for data refresh.
- Clicking an episode button should open or update playback from that video's
  persisted Library resume position, falling back to `0` when no history
  exists.
- Playback progress should be recorded only while the current playback source
  is Library. Opening or seeking through Search results should not read, write,
  or overwrite Library resume history.
- The `Playing M` folder subtitle and the playing-state button highlight should
  be driven exclusively by Library-launched playback. Playback opened through
  Search results, Shiori, or any other surface must not toggle these Library
  indicators.
- Clicking an episode button should not require the user to continue attending
  to the Library after playback starts.
- Subtitle files should appear as video metadata or attached resources, not as
  duplicate top-level video entries when one playable video is available.
- Reindexing is the expected way to refresh Library video rows and duration
  metadata when older indexed data is missing that information. A completed
  reindex should refresh Library data, collapse all Library folder groups, and
  rerun the current Search query when one is active.

Timeline behavior:

- Timeline should show the current video's subtitles in timestamp order.
- Clicking a Timeline row should seek playback precisely.
- Timeline navigation should remain on the left because it is a precise
  location tool for known content.

## 9. Queue And Learning Session Interaction

Queue and Learning Session are future learning workflow modes.

Shiori behavior:

- Shiori belongs to the Shared Content Panel for the current implementation
  because it uses the same grouped result presentation and click-to-playback
  flow as Search.
- Shiori is selected from the fixed Mode Rail.
- Saving or removing a Shiori should not pause playback or reset Search state.
- Shiori panel collapse state is presentation state and should not rebuild
  Library rows or Search result rows.

Queue behavior:

- Search results, Library videos, Timeline rows, and Shiori records may all become
  queue inputs.
- Search result rows may expose a hover `Add to Queue` action.
- The user should be able to collect multiple Search results quickly while
  scrolling.
- Queue placement must be documented before implementation. It should not be
  assumed to require a separate right-side panel in the current workbench model.

Learning Session behavior:

- Learning Session should configure how queued or selected material plays.
- Future options may include how many subtitle lines or seconds around the
  target timestamp to play, repeat count, random order, loop behavior, and
  whether to play cue windows or broader context.
- Detailed Learning Session behavior must be documented before implementation
  because it affects playback commands, keyboard focus, queue identity, and
  persistence.

## 10. Indexing Interaction

Indexing should communicate progress without blocking the whole app unnecessarily.

Expected behavior:

- Show indexing state.
- Show completion state.
- Show errors for unreadable folders or files.
- Allow the user to continue using existing indexed data when possible.
- If the currently playing media is under a folder being reindexed, CueSeeker
  should stop or clear that playback before the rebuild starts. This prevents a
  complex playback session from continuing against resource identities that are
  being rebuilt.
- Reindexing may make existing Search results stale. CueSeeker should rerun the
  active Search query after reindexing instead of leaving old results in place.

## 11. Error Handling

Errors should be understandable and actionable.

Error messages should answer:

- What failed?
- What can the user do?
- Is the rest of the app still usable?

Technical details may be available in logs, but should not overwhelm the main UI.

## 12. Keyboard Behavior

Keyboard behavior should follow native macOS expectations.

Initial expectations:

- Standard text editing shortcuts work in search fields.
- Escape should dismiss transient UI or unfocus search when appropriate.
- Playback shortcuts should apply only when playback focus or context makes sense.
- Global shortcuts should be documented before implementation.

M2 keyboard shortcut model:

- The shortcut model should define commands, default key bindings, focus scope, and conflict rules before implementation.
- Search text editing must keep standard macOS editing behavior.
- Playback shortcuts should trigger the same playback commands used by visible playback controls.
- Shortcut handling should not duplicate playback state transitions separately from the playback interaction model.
- The native menu bar should expose relevant commands so keyboard shortcuts are discoverable through standard macOS menus where practical.
- Playback shortcuts should be active only when an active playback session
  exists, the playback interface is visible, and editable text input is not
  focused.
- Read-only selectable text in playback metadata should not suppress playback shortcuts.
- `Q` should show or hide subtitles during normal playback.
- `S` and `C` have no normal-playback command.
- `F` should enter or exit playback fullscreen.
- `Space` should toggle play or pause.
- `A` and `D` should trigger Previous Result and Next Result.
- `Left Arrow` and `Right Arrow` should seek backward or forward by 5 seconds.
- `Up Arrow` and `Down Arrow` should adjust volume by 5 percentage points.
- `Shift+,` and `Shift+.` should decrease or increase playback speed by 0.25x.
- While Playback Subtitle Focus is visible, it consumes `S`, `C`, `Space`, and
  `Enter` before normal playback shortcut routing. `S` saves the exact settled
  cue, `C` copies its complete text, `Space` plays continuously from its start,
  and `Enter` performs no action.
- `S` and `C` keep Playback Subtitle Focus visible and playback paused;
  `Space` closes it. Accepted actions during reel motion execute once against
  the final settled cue.
- Playback shortcut commands should show lightweight feedback overlays for
  subtitle visibility, play or pause, relative seek, volume, speed, and
  Subtitle Focus actions.

## 13. Settings Interaction

Settings should follow standard macOS app-settings expectations.

Expected behavior:

- The formal entry is `CueSeeker > Settings...` in the app menu.
- The app may expose the standard `Command-,` shortcut if practical.
- The Mode Rail bottom Settings button should open or focus the same Settings
  window as the app-menu command.
- Opening Settings should create or focus a single independent Settings window.
- The Settings window should use a two-column structure: a left category list
  and right content area.
- The left category list uses the quiet gray settings/navigation background.
- The right content area uses the white settings content background.
- The active native Settings categories are `Library`, `Decode`,
  `Maintenance`, `Developer`, and `Experimental Features`. `Layout` remains an
  accepted direction for the Sidebar Position preference when that setting is
  reintroduced.
- `Library` contains current Subtitle Folders management: add folders, index
  selected folders, remove folders with confirmation, and show indexing status.
- `Decode` contains the playback decode mode selector for `hardware`,
  `software`, and `auto`.
- `Maintenance` contains local database storage stats and the manual
  `Compact Database` action for reclaiming unused SQLite freelist space.
- `Developer` is reserved for diagnostics and instrumentation that help explain
  local behavior while developing the app. Search diagnostics are paused until
  the new ASS-file-first measurement model is implemented.
- `Experimental Features` contains unstable feature toggles, including `Search
  Result Thumbnails`, which is off by default.
- Refreshing database storage stats or switching into `Maintenance` should not
  pause playback or switch away from the CueSeeker workbench.
- Running `Compact Database` may temporarily block database search and indexing
  work while SQLite rebuilds the local database file.
- Changing `Sidebar Position` should not pause playback, reset Search results,
  clear Shiori state, collapse Library groups, or change the Shared Content
  Panel width.
- Opening, focusing, switching categories within, or closing Settings must not
  pause playback, switch away from the CueSeeker workbench, collapse the Shared
  Content Panel, or clear the selected Search result.

## 14. File And Finder Interaction

Native macOS file and Finder interactions are part of the expected product
experience.

Rules:

- Adding subtitle folders should use the native folder picker.
- File-location commands, such as revealing the current playback video or
  subtitle in Finder, may use native Finder or AppKit integration.
- These explicit interactions may temporarily create Open and Save Panel,
  QuickLook, Finder, or other system helper services.
- Helper services should not be triggered by ordinary launch, Search, opening
  or focusing Settings, or playback when no file-system interaction is being
  requested.
- The app should not weaken native file-access behavior or force-terminate
  system helper services only to reduce process count.

## 15. Persistence

The app should remember:

- Configured local folders.
- Window size and maximized state.
- Last selected main-window app section if future top-level sections are added.
- Last selected Settings category if practical.
- Shared Content Panel visibility and width.
- Current Workbench Mode Rail selection for modes such as Library, Search, and
  Shiori.
- Library playback resume history, limited to Library-opened playback.
- Shiori records, including their real-world save timestamp.
- Queue or Learning Session state only after persistence rules are documented.
- Playback decode mode.

Playback close must not be modeled as a persistence reset. Search results and
database search caches are Search state. Library resume history is Library
playback history and is saved according to Library playback rules. Group
collapse state and scroll position are presentation state unless a separate
document explicitly defines persistence for them.

The app should not surprise the user by losing local configuration after restart.
The structural layout persistence should keep each content mode's presentation
state separate while sharing one panel visibility and width. Library, Timeline,
Shiori, Search, Queue, and Learning Session should evolve without inheriting
unrelated mode-specific behavior.
