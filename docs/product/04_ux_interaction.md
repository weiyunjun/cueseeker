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
Collapse the right-side Search Panel when focusing on playback
```

Known-content review may also start from Library:

```text
Open app
Use left-side Library to choose a known video
Playback Area opens or updates from the Library resume position
Search remains available on the right for active learning and lookup
```

## 2. First Launch

On first launch, if no folders are configured:

- The app should make it obvious that a local subtitle folder must be added.
- The user should be able to add a folder without navigating through unnecessary screens.
- The app should explain indexing status only when needed.

## 3. Search Interaction

Search should feel immediate.

Expected behavior:

- Search controls and Search results live in the right-side Search Panel.
- The main window title should be `CueSeeker`; Search is a right-side panel
  workflow, not the main-window workspace label.
- The left titlebar control collapses or expands Library, while the right
  titlebar control collapses or expands the Search Panel.
- Settings opens from `CueSeeker > Settings...` in the macOS app menu and does
  not belong to the main-window sidebar.
- The Search Panel can be collapsed when the user wants to focus on playback.
- Collapsing the Search Panel should preserve the current query, result state,
  selected result, and playback context.
- Collapsing the Search Panel must not pause playback.
- Typing updates results after a short debounce.
- Empty search shows an empty or guidance state.
- Invalid search syntax should not crash the app.
- Search results should not flicker unnecessarily.
- Search should show a muted total result count below the search field when a
  query has results.
- Repeating the same query should not trigger expensive work without reason.

Grouped result behavior:

- Search results should be grouped by subtitle file.
- Groups should be expanded by default.
- Clicking a subtitle-file header should collapse or expand that group.
- Collapsing a group should only hide that group's loaded rows. It must not
  change result counts, search scope, or selection identity.
- Result lazy loading should remain based on matched cue groups, not subtitle
  file groups.
- Result lazy loading should use 100 cue-group results as the initial visible
  budget and 100 cue-group results for each incremental load.
- Lazy loading should trigger only from these user-visible actions: scrolling to
  the bottom when more global rows can be shown, clicking the expand-all control
  when all groups are collapsed, or expanding an individual subtitle-file
  header.
- Per-file match totals should remain available in search grouping state for
  lazy-loading and future sorting behavior. Header presentation should append
  the per-file total to the friendly subtitle group title as plain text and
  must not render a per-file count badge or separate count component.
- The friendly subtitle group title should use the immediate parent folder name
  plus the subtitle file's one-based Finder-like natural-sort rank among visible
  regular sibling subtitle files with the same final subtitle extension, such as
  `葬送的芙莉莲 - 05`.
- Users can change the displayed work title by renaming the parent folder
  without changing the subtitle or video filenames.
- The full subtitle path remains available through the Playback Area file
  actions and internal result state for source identity and diagnostics.
- The collapse or expand-all control should toggle all subtitle-file groups in
  the current query at once.
- The collapse or expand-all control should track only its own global action
  state. Manually collapsing or expanding a single subtitle-file header should
  not change that control's label.
- Collapsing all groups should reduce visible subtitle rows to zero while
  keeping subtitle-file headers visible.
- Expanding all groups should reveal at most one global 100-result batch. It
  should not reveal 100 rows per subtitle file, and it should not restore
  previously scrolled-in rows beyond the current 100-row budget solely because
  those rows were visible before collapse.
- Expanding an individual subtitle-file header should reveal at most the first
  100 matching rows for that subtitle file. If the file has fewer matches, all
  of its matches should be visible.
- Collapse actions should not trigger a search, fetch another lazy-loading page,
  change the lazy-loading cursor, or mutate result counts.

Search focus behavior:

- User-initiated app commands should clear Search field focus.
- Selecting a search result should clear Search field focus.
- Clicking App-owned expand or collapse buttons should clear Search field focus.
- Future App-owned feature buttons should clear Search field focus by default.
- Selecting another main-window sidebar section should clear Search field focus
  when such sections exist.
- Opening Settings may clear Search field focus, but it must not change Search
  workspace, selected result, Search Panel, or playback state.
- Clicking anywhere in the Playback Area should clear Search field focus.
- System-level app switching should not intentionally clear Search field focus.
- Returning to the app after backgrounding should preserve the Search field focus state when AppKit preserves the first responder.
- Double-clicking the titlebar to resize the window should not intentionally clear Search field focus.
- Clicking native traffic light controls should not intentionally clear Search field focus.

## 4. Panel Responsibility Model

CueSeeker's main workspace should preserve distinct side responsibilities around
the central playback experience.

The left side is for known-content navigation and precise location:

- Library browsing.
- Current video subtitle Timeline.
- Favorites browsing and management.

The right side is for active learning workflows:

- Search.
- Search result aggregation.
- Queue building.
- Learning Session configuration.

The left side should help the user quickly reach a known video or timestamp.
After the user selects a video or timeline cue, attention can return to
playback.

The right side should help the user discover, collect, and sequence learning
material. Search result rows may later expose hover actions or context menus,
including adding a subtitle moment or video to a Queue.

Responsiveness boundaries:

- Library is a static known-content resource area. It should change only when
  folders are added, removed, reindexed, manually collapsed or expanded, resized,
  or when the user selects a Library video.
- Search is an active query and aggregation area. Search input, result loading,
  Search-group collapse state, Queue actions, and future learning actions should
  not rebuild Library rows or mutate Library state.
- Playback is the central video review area. Opening media, seeking,
  play/pause, fullscreen, subtitle visibility, and playback-control state should
  not rebuild Library rows or Search result rows unless the user explicitly
  performs a Search or Library action.
- Collapsing or expanding a side panel should preserve the panel's current
  content state. It should not destroy and recreate large result lists as a side
  effect of a layout change.
- Search field focus is Search Panel interaction state. Changing focus should
  not invalidate Library content or playback content.
- The visible playback clock used by SwiftUI controls may update at a lower
  frequency than the native video playback clock. This must not affect native
  video playback smoothness or seek accuracy.
- ASS playback timing and render-source coordination is performance-sensitive
  and should not be refactored as part of the first UI invalidation cleanup.
  Any later ASS timing-source change must preserve immediate subtitle loading
  after Search result selection.

## 5. Result Selection

When the user selects a result:

- The selected row visually turns into a gray rounded rectangle while preserving
  normal primary text color and query highlighting, without relying on row
  divider lines.
- The selected row continues to show the result's start timestamp on the right
  side. Within a row, subtitle text and timestamp text should use the same
  color for that row's selection state.
- Unselected rows use a slightly muted primary text color for both subtitle text
  and timestamp text, preserving hierarchy without making the unselected
  results as faint as group headers.
- Search result subtitle text should keep internal SRT and ASS line breaks
  readable with extra wrapped-line spacing, especially for bilingual cue text.
- The app should remain in the CueSeeker workbench and open or update the
  central Playback Area.
- If the Search Panel is visible, selecting a result should keep it visible so
  result-to-result review remains available.
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

## 6. Visual Feedback and Hover

- **Titlebar Buttons**: Toolbar toggle buttons use a subtle gray background on hover to indicate interactivity.
- **Search Field**: The focused Search field uses a gray outline rather than the
  system accent color.
- **Search Results**: Interactive result rows emphasize the selection state over
  hover with a macOS unemphasized gray selected-row background, aligned group
  headers, no row divider lines, readable bilingual line spacing, and visible
  right-side start timestamps whose text color matches the subtitle text for
  the same row state.

## 7. Playback Interaction

M1 playback interaction should be minimal.

Required interactions:

- Auto-play after selecting a result.
- Toggle play/pause by clicking the embedded video.
- Seek.
- Jump from search result to timestamp.
- Continue playback when the Search Panel is collapsed.
- Opening Settings does not pause playback or switch away from the CueSeeker
  workbench.
- Pause playback when switching from the CueSeeker workbench to another future
  main-window workspace section if that section is documented to leave the
  playback review context.
- Preserve the current selected result when the Search Panel is collapsed.
- Reopening the Search Panel should not automatically change playback state.

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
- Playback fullscreen should fullscreen the video experience itself, not the full app shell.
- Playback fullscreen should use an independent theater-style fullscreen window
  and return the embedded video to the Playback Area when closed.
- Entering or exiting playback fullscreen must not create a second playback render container or duplicate backend render state.
- Entering playback fullscreen should immediately hide the playback operation controls and mouse cursor once, regardless of whether the controls were visible before fullscreen.
- In playback fullscreen, the playback operation controls and mouse cursor should hide after 3 seconds without mouse or click activity.
- In playback fullscreen, only mouse or click activity should reveal the playback operation controls and cursor; keyboard playback shortcuts should not reveal them.
- Theater Mode should hide while the app is inactive so the visible UI matches the active foreground app.
- Theater Mode should stay below system switchers and overlays such as Cmd-Tab.
- The progress bar and its enlarged hit area are named the `Timeline Zone`.
- The button row below the progress bar is named the `Transport Controls Zone`.
- Together, the `Timeline Zone` and `Transport Controls Zone` form the `Playback Operation Zone`.
- Mouse clicks in the `Playback Operation Zone` should control only the targeted playback control and must not fall through to video-surface play or pause toggling.
- Hovering or dragging the `Timeline Zone` should not change the vertical position of the `Playback Operation Zone`.
- Playback speed selection should use an app-drawn upward menu that stays within the playback controls surface.
- The speed menu should appear from hover over the speed control instead of requiring an arrow button.
- The speed menu should not have a separate show or hide animation.
- The speed button's hover area and click area should be identical and should match the speed menu width.
- The speed menu should appear only when hovering over the speed button area.
- The speed menu should disappear only after the pointer leaves the combined rectangular region whose top edge is the speed menu top edge and whose bottom edge is the speed button bottom edge.
- Keyboard shortcuts in fullscreen should not reveal the playback operation controls.
- A copy-current-subtitle button should appear immediately before the subtitle visibility button.
- The subtitle button should toggle the current player's subtitle visibility when the playback engine exposes a subtitle track or subtitle display state.
- Playback interaction design should remain focused on subtitle context review, not a full media-player feature set.

Current M2 implementation:

- Playback fullscreen uses a Theater Mode window and returns the same playback
  render container to the embedded Playback Area when closed.
- Fullscreen playback hides the controls and cursor immediately on entry and again after 3 seconds of inactivity.
- Fullscreen playback reveals controls and cursor from mouse or click activity, not from keyboard shortcuts.
- Theater Mode suspends during app deactivation and restores on app activation without recreating the playback render context.
- The Theater Mode window level allows Cmd-Tab and other system overlays to remain visible above playback fullscreen.
- Playback controls and keyboard shortcuts share the same playback command state through the playback view model.
- Shortcut and control actions show transient feedback overlays for copying the current subtitle, subtitle visibility, play/pause, relative seek, volume, and speed.
- The visible playback speed menu offers `0.5x`, `0.75x`, `1.0x`, `1.25x`, `1.5x`, `1.75x`, and `2.0x`.
- The speed button hover area, speed button click area, and speed menu width are aligned to the same horizontal bounds.
- Keyboard shortcuts adjust speed in `0.25x` steps and are clamped to the same `0.5x` through `2.0x` range as the playback controls.
- The previous Flutter shortcut model was used as a reference, but the native M2 map intentionally changes subtitles to `C`, removes the bottom-mask shortcut, and changes speed adjustment to `Shift+,` and `Shift+.`.

## 8. Library And Timeline Interaction

Library and Timeline are future left-side content-navigation modes.

Library behavior:

- Library should browse playable videos rather than raw subtitle files.
- Library should appear in the Left Content Panel with a gray background and a
  dense grouped layout comparable to Search results.
- Library should appear populated immediately after app restart when indexed
  video metadata already exists locally. A visible Loading or empty state during
  startup is only acceptable when no persisted Library rows exist or the
  database cannot be opened.
- Library should collapse or expand from the left titlebar control.
- Library should be horizontally resizable after launch.
- Library's default width should equal its minimum width.
- Library's first default and minimum width should be `310pt`, `50pt` narrower
  than the previous fixed `360pt` Library width.
- Changed Library width should persist across launches.
- Library should group videos by immediate parent folder only. It should not
  render nested folder trees in the first implementation.
- Folder groups should be sorted with Finder-like natural ordering.
- Folder groups should be expanded by default.
- Users can collapse or expand individual folder groups.
- Folder group collapse or expand state should persist across launches.
- A top `Collapse All` / `Expand All` control should collapse or expand all
  folder groups.
- Video rows inside a folder should be sorted with the same Finder-like natural
  ordering used to derive the row rank.
- Video rows should display `Parent Folder Name - NN  extension`, such as
  `葬送的芙莉莲 - 01  mkv`.
- Video rows should display the indexed duration on the right.
- Clicking a video through Library should open or update playback from that
  video's persisted Library resume position, falling back to `0` when no
  history exists.
- Playback progress should be recorded only while the current playback source
  is Library. Opening or seeking through Search results should not read, write,
  or overwrite Library resume history.
- Clicking a video should not require the user to continue attending to the
  Library after playback starts.
- Subtitle files should appear as video metadata or attached resources, not as
  duplicate top-level video entries when one playable video is available.
- Reindexing is the expected way to refresh Library video rows and duration
  metadata when older indexed data is missing that information.

Timeline behavior:

- Timeline should show the current video's subtitles in timestamp order.
- Clicking a Timeline row should seek playback precisely.
- Timeline navigation should remain on the left because it is a precise
  location tool for known content.

## 9. Queue And Learning Session Interaction

Queue and Learning Session are future right-side learning workflow modes.

Queue behavior:

- Search results, Library videos, Timeline rows, and Favorites may all become
  queue inputs.
- Search result rows may expose a hover `Add to Queue` action.
- The user should be able to collect multiple Search results quickly while
  scrolling.
- Queue belongs on the right because it is a user-authored learning plan, not
  the source content structure.

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
- Playback shortcuts should be active only when a playback result is selected, the playback interface is visible, and editable text input is not focused.
- Read-only selectable text in playback metadata should not suppress playback shortcuts.
- `Q` should copy the current subtitle to the clipboard.
- `C` should show or hide subtitles.
- `F` should enter or exit playback fullscreen.
- `Space` should toggle play or pause.
- `Left Arrow` and `Right Arrow` should seek backward or forward by 5 seconds.
- `Up Arrow` and `Down Arrow` should adjust volume by 5 percentage points.
- `Shift+,` and `Shift+.` should decrease or increase playback speed by 0.25x.
- Playback shortcut commands should show lightweight feedback overlays for subtitle copy, subtitle visibility, play or pause, relative seek, volume, and speed changes.

## 13. Settings Interaction

Settings should follow standard macOS app-settings expectations.

Expected behavior:

- The formal entry is `CueSeeker > Settings...` in the app menu.
- The app may expose the standard `Command-,` shortcut if practical.
- Opening Settings should create or focus a single independent Settings window.
- The Settings window should use a two-column structure: a left category list
  and right content area.
- The left category list uses the quiet gray settings/navigation background.
- The right content area uses the white settings content background.
- The only current categories are `Library` and `Decode`.
- `Library` contains current Subtitle Folders management: add folders, index
  selected folders, remove folders with confirmation, and show indexing status.
- `Decode` contains the playback decode mode selector for `hardware`,
  `software`, and `auto`.
- Opening, focusing, switching categories within, or closing Settings must not
  pause playback, switch away from the CueSeeker workbench, collapse either
  side panel, or clear the selected Search result.

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
- Library visibility, width, and folder collapse state.
- Left Content Panel mode when additional modes such as Timeline or Favorites
  are implemented.
- Search Panel width and visibility.
- Library playback resume history, limited to Library-opened playback.
- Queue or Learning Session state only after persistence rules are documented.
- Playback decode mode.

The app should not surprise the user by losing local configuration after restart.
The structural layout persistence should keep Left Content Panel state separate
from Search Panel state so Library, Timeline, Favorites, Search, Queue, and
Learning Session can evolve without inheriting unrelated panel behavior.
