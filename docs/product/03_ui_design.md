# UI Design

Status: Draft

## 1. Design Direction

CueSeeker should feel like a focused native macOS desktop tool.

The interface should prioritize:

- Fast search.
- Dense but readable result lists.
- Clear local folder management.
- Immediate video context after selecting a result.
- Native macOS interaction patterns.

The app should avoid marketing-style layouts, decorative hero sections, and unnecessary visual complexity.

## 1.1 Accepted Search-First Topbar Transition

The accepted next UI direction is a Search-first transition toward a
topbar-driven single-page work surface.

This transition supersedes the Mode Rail and Shared Content Panel requirements
for the Search workflow only. Library, Shiori, Settings, and other unmigrated
surfaces may remain in their current locations until later documented migration
steps replace them.

First implementation requirements:

- Add a fixed-width Search field to the topbar.
- Treat text editing in the topbar Search field as a draft query.
- Submit Search only when the user presses Return.
- Show submitted Search results in the main content area.
- Keep Search result grouping, result rows, selection behavior, and the global
  `Collapse All` control consistent with the current Search result list.
- Do not render a second Search field inside the Search results page.
- Clicking a Search result opens a Search-launched playback page.
- The playback page keeps the video at the source aspect ratio with fit
  behavior and leaves command space below the video.
- First-pass visual polish is explicitly secondary to complete functionality.

The related accepted proposal is
`docs/proposals/2026-05-topbar-search-single-page-workflow.md`.

## 2. Main Window

The main window should be a persistent work surface.

Accepted M1 structure:

```text
Native titlebar
CueSeeker workbench
Fixed Mode Rail
Shared Content Panel
Playback Area
```

The main window should support:

- Resizing.
- Reasonable minimum size.
- Restoring previous size if practical.
- Native toolbar or sidebar behavior where appropriate.

Current shell direction:

- Traffic lights and the centered workbench title belong to the titlebar.
- Library, Search, and Shiori mode controls belong to a fixed-width vertical
  Mode Rail at the far left of the workbench, below the titlebar.
- The Mode Rail is not horizontally resizable.
- The Mode Rail should initially expose Library, Search, and Shiori icons only.
- The Mode Rail may expose a bottom Settings button. Settings is an action that
  opens or focuses the independent Settings window; it is not a panel mode and
  must not change the Shared Content Panel's selected mode, width, or
  visibility.
- The Mode Rail and Shared Content Panel side is user-configurable in Settings.
  The default position is `Left`, rendering `Mode Rail - Shared Content Panel -
  Playback Area`. The `Right` position renders `Playback Area - Shared Content
  Panel - Mode Rail`.
- The Shared Content Panel sits immediately to the right of the Mode Rail.
  Library, Search, and Shiori render inside this same panel, so switching modes
  must not change the panel width.
- The Shared Content Panel is horizontally resizable. Its default width should
  use the previous Search Panel minimum width, `420pt`, and user resizing should
  persist.
- Clicking the selected Mode Rail icon collapses the Shared Content Panel using
  the existing side-panel drawer animation.
- Clicking an unselected Mode Rail icon switches the panel mode. If the Shared
  Content Panel is collapsed, the same action expands it and shows the selected
  mode.
- The previous titlebar Library toggle, right-side Search Panel toggle, and
  titlebar Search/Shiori mode buttons are no longer part of the current
  workbench shell.
- The centered title should read `CueSeeker`. It should not read `Search`
  because Search is a panel mode, not the main-window
  workspace identity.
- Traffic lights are shifted 12pt to the right and vertically centered within the custom titlebar. To achieve this without fighting AppKit's native layout engine during window resizing, the standard window buttons (`.closeButton`, `.miniaturizeButton`, `.zoomButton`) are reparented (extracted from their system container and placed into a custom transparent `NSView` proxy). This preserves native hover effects and accurate hit testing.
- The native `NSWindow` title visibility is hidden in windowed mode but temporarily restored during full-screen transitions, ensuring the system drop-down title bar is fully functional.
- The `NSWindow` title should use the main workbench identity, `CueSeeker`, for
  correct contextual labeling in the full-screen drop-down title bar.
- To prevent UI artifacts when exiting full-screen mode, the native title visibility is hidden in the `windowWillExitFullScreen` delegate callback before the transition animation begins.
- The titlebar should use a slightly darker gray than the main content background.
- A thin gray divider should separate the titlebar from the content below.
- The titlebar should visually sit above the workbench panels.
- The window automatically maximizes to the screen's visible frame upon launch.
- The current titlebar and workbench panel implementation is an M1 iteration,
  not final polish.

## 3. Main-Window Navigation

The previous standalone `Search` sidebar item should be removed. The main
window's current top-level destination is the CueSeeker workbench itself.

Current workbench panel modes:

- Library.
- Search.
- Shiori.

These modes are not separate main-window destinations. They are content-panel
surfaces inside the persistent workbench and are selected through the fixed
Mode Rail.

Settings should not be a main-window sidebar section. The formal Settings entry
belongs in the macOS app menu and may also be mirrored by the Mode Rail bottom
Settings button. Both entry points open or focus the same independent Settings
window.

If top-level navigation returns later, it should remain visually quiet and
should not compete with Library, Search results, Shiori records, or playback.

## 4. Main Workspace Panel Model

The main workspace should be organized around playback as the central
experience, with all current navigation and learning modes using one shared
left-side content panel.

Conceptual structure:

```text
Fixed Mode Rail
Shared Content Panel
Playback Area
```

The main window is the CueSeeker workbench. The old standalone `Search`
AppShell destination should not appear in the current single-workbench design.
Settings is app-level configuration and belongs in the macOS app menu and
independent Settings window, not in main-window navigation.

The Fixed Mode Rail selects the Shared Content Panel mode:

- Library.
- Search.
- Shiori.

The Shared Content Panel should not become a generic tool drawer. It is the
workspace's current source, search, and saved-content surface. Playback remains
central and should not be displaced by mode switching.

This panel model keeps playback central. Search and Shiori are panel modes
beside the Playback Area, not top-level workspace identities.

Accepted first Library panel direction:

- Library is the first concrete Shared Content Panel mode for known video
  navigation.
- Library is separate from the Settings `Library` category.
- Library keeps the left-side gray background treatment.
- Library can collapse or expand by clicking the selected Library icon in the
  fixed Mode Rail.
- Library can be resized horizontally. Its default width should equal its
  minimum width.
- The Shared Content Panel's first default and minimum width should be `420pt`,
  matching the previous Search Panel minimum width.
- Shared Content Panel width should persist when the user changes it.
- Library uses a dense grouped layout with folder rows on top and an
  expand-on-demand episode-button grid underneath.
- Library shows only one folder grouping level.
- Folder groups and the playable videos inside each folder use Finder-like
  natural ordering.
- Folder groups are collapsed on app startup.
- Folder group collapse or expand state is session-only. It should not persist
  across launches.
- Reindexing or refreshing Library data should rebuild Library rows and reset
  folder groups to collapsed, because the indexed resource set may have changed.
- Folder rows are two-line: the folder display name on the first line, and a
  subtitle on the second line. The subtitle reads `N episodes` by default and
  `N episodes · Playing M` while a Library-launched playback session is active
  for a video in this folder, where `M` is that video's one-based sibling rank.
- Folder rows must not display a leading first-letter or first-character avatar
  block. The folder display name is the leftmost element, hugging the panel's
  normal left padding.
- A single chevron on the left of the folder row indicates expand or
  collapse state. The chevron rotates between `0°` (collapsed) and `90°`
  (expanded) over `160ms` with an ease curve when toggled. This animation
  and left-side position are shared with Search and Shiori group disclosure
  rails.
  The full folder row is the click target that toggles expand or collapse.
- Expanded folders show a numbered button grid using each video's one-based
  natural-sort sibling rank. The grid does not display file names, durations,
  or language tags. Per-video metadata stays available for tooltips, future
  hover information, and accessibility, but is not part of the visible grid
  rendering.
- The episode grid uses minimum-button-width auto-flow columns; the column
  count adapts to the current Shared Content Panel width.
- The episode grid is indented slightly to the right of the folder row's left
  edge to express hierarchy. The indent should remain small.
- Episode buttons use three visual states only: default, hover, and playing.
  Hover should match the existing collapse-toggle hover treatment. The playing
  state highlights only when playback was launched through Library.
- Expanding a folder that contains the currently Library-launched playing video
  should auto-scroll that video's button into view as part of the expand
  transition. Auto-scroll must not fire for already-expanded folders.
- Library does not expose a panel-wide `Collapse All` or `Expand All` control.
  Folder disclosure remains per-folder.
- Clicking an episode button opens or updates playback from the persisted
  Library-only resume position, falling back to `0` when no history exists.
- The Library `Playing M` indicator and the playing-state button highlight are
  driven exclusively by Library-launched playback. Playback opened through
  Search results, Shiori, or any other surface must not toggle these Library
  indicators.

## 5. CueSeeker Workbench And Search Mode

The CueSeeker workbench is the primary screen. Search is a mode inside the
shared left-side content panel.

Search mode is being migrated first to the topbar Search workflow described in
section 1.1. Requirements in this section that place Search inside the Shared
Content Panel apply only to the pre-migration workbench and to any unmigrated
surfaces that still use the panel model.

Required elements:

- Fixed Mode Rail.
- Shared Content Panel when expanded.
- Central Playback Area.
- Search input.
- Indexing status when relevant.
- Search result list.
- Empty state when no query or no results exist.
- Error state when search or database access fails.

The search input should stay easy to access when Search mode is active and the
Shared Content Panel is expanded. Search must have a clear restore path when
the Shared Content Panel is collapsed.

Accepted player-first Search presentation:

- In the topbar Search transition, the topbar Search field is the only Search
  entry point. The Search result page must not duplicate the Search field below
  the topbar.
- Search results keep the existing grouped result presentation and global
  `Collapse All` behavior for the first implementation.
- Selecting a Search result opens the Search-launched playback page instead of
  keeping Search playback constrained to a side-panel workbench layout.

- The main titlebar identifies the workbench as `CueSeeker`.
- The embedded Playback Area remains central.
- Search controls and grouped Search results appear in the Shared Content Panel
  when Search mode is selected.
- The Shared Content Panel may be collapsed so the Playback Area can expand.
- Collapsing the Shared Content Panel must not pause playback or clear the
  selected result.
- The Playback Area is the primary review surface after a result is selected;
  Search is the functional navigation and result-selection surface.

Accepted M1 search presentation:

- The search field is a custom `NSTextView` wrapper (`SearchTextView`)
  allowing zero baseline jitter, a leading magnifying-glass icon, and an
  inline clear button. The field uses a `6pt` corner radius pill with a
  `1pt` separator border by default. On focus it switches to a `1.5pt`
  accent-color stroke plus a `3pt` accent-color outer ring at `18%`
  opacity for the focus indicator. The pill maintains a constant `3pt`
  outer padding so the focused outer ring does not introduce layout
  jitter. Internal padding is `8pt` horizontal and `6pt` vertical, with
  `6pt` gap between the search glyph, input, and clear glyph; both
  glyphs render at `13pt`.
- The area below the search field shows muted result-count text for the current
  query, such as `Found 42 results`.
- During grouped lazy-loading validation, the result-count row may temporarily
  show muted diagnostic text such as `Rendered 100 results` for the currently
  rendered result-row count.
- The result-count row should include a native rounded bordered button aligned
  to the right of the count text. The button should use the same general visual
  style as the Settings `Index Now` button.
- The collapse or expand-all button label should reflect the next global action,
  using English labels such as `Collapse All Results` or `Expand All Results`.
- Search results are shown as a grouped list with rounded selection backgrounds.
- Search result scrolling loads additional matches lazily in 100-result pages.
- Expanding all result groups from the all-collapsed state reveals at most one
  global 100-result batch.
- Search results are grouped under flat subtitle-file headers.
- Selecting a search result opens or updates the central Playback Area without
  leaving the CueSeeker workbench.
- Search results use refined macOS-native typography and highlight query
  matches with a yellow background that remains readable on selected rows.
- Search result visual polish is still incomplete and subject to further iteration.

## 6. Search Result Group

Each subtitle-file group should be compact and scannable. Search mode groups
search results by subtitle file in a single flat level — there is no
parent-folder Show layer above subtitle files (the rejected Show / Episode /
Hit proposal is preserved in `docs/proposals/` for context).

The group header should display:

- A disclosure chevron on the left as a rail. The chevron rotates between
  `0°` (collapsed) and `90°` (expanded) over `160ms` with an ease curve
  when toggled. When the group is expanded, a vertical rail line extends
  below the chevron alongside the group's matched rows.
- A friendly subtitle group title followed by two spaces and the per-file
  result count as plain text, for example `葬送的芙莉莲 - 05  3 results` or
  `葬送的芙莉莲 - 05  1 result`.

The group header should be clickable as a single target and should toggle
collapse or expansion. The chevron in the rail indicates state; it does not
need to be the only clickable control.

Groups should be expanded by default.

The grouped Search header should not render a per-file count badge or a
separate right-aligned count component. Per-file match totals should appear
as plain text appended to the display title, while also remaining available
in search state for loading and future sorting behavior.

Friendly group titles should use the immediate parent folder name plus the
subtitle file's one-based natural-sort rank among visible regular sibling
subtitle files with the same final subtitle extension. The rank should use
Finder-like localized standard comparison so numeric filename runs sort by
numeric value.

The display title format is `Parent Folder Name - NN`, with the numeric
suffix zero-padded to at least two digits. If the friendly title cannot be
derived, the header should fall back to the raw subtitle filename. Fallback
filenames may wrap across multiple lines and may include invisible soft
wrap opportunities after common filename delimiters such as `]`, `.`, `_`,
and `-` so long bracketed names use available width more naturally without
changing the visible filename.

Group title text and result-row subtitle text should align on the same
left edge. The disclosure rail lives in the left-side control space so it
does not add extra indentation to result-row subtitle text. The exact
spacing may be refined during implementation.

Expanding a collapsed group should display at most the first 100 matching
rows for that subtitle file.

Group ordering should be stable and based on the friendly display title
when it is available. If two groups have the same display title, or if a
group falls back to the source subtitle filename, the full subtitle path
should be used as the secondary stable ordering key.

## 7. Search Result Row

Each result row should be compact and scannable.

Result row content:

- Subtitle text as the primary content. All cue lines in the matched cue
  group are rendered in row order.
- Inline highlighting of query matches.
- Result rows do not render a cue start timestamp. Within a subtitle-file
  group rows are ordered by ascending cue start time, so spatial order
  conveys time order without a dedicated column.

Result row color behavior:

- Selected rows use the macOS system accent color
  (`NSColor.controlAccentColor`, surfaced through `Color.accentColor` in
  SwiftUI). When the user changes their system accent color, the selected
  background reflects that color. A future settings option may expose a
  custom accent override; the first implementation does not include that.
- Selected row text is white. Unselected row text uses a slightly muted
  primary label color so rows remain readable without competing with the
  selected row.
- Hover row background uses a soft gray fill consistent with native macOS
  list rows.

Keyword highlight tokens (light mode):

| Row state | Highlight background | Highlight foreground | Weight |
|---|---|---|---|
| Default | `#FFE066` | label primary | 500 |
| Hover | `#FFCB1F` | label primary | 500 |
| Selected | `rgba(255,255,255,0.30)` | white | 600 |

The keyword highlight inverts to a translucent-white fill with bolder white
text on a selected row so the matched substring stays the most prominent
token in the line while staying inside the accent-color envelope.
Dark-mode equivalents are deferred to a later iteration.

Grouped cue result rows should display every cue line in the matched group,
ordered by derived display order when available. Grouped rows may use
dynamic height and must not deduplicate same-looking cue lines or impose a
fixed product-level line count cap.

Rows inside the same subtitle-file group should be ordered by subtitle
timestamp ascending.

Rows should have stable height or predictable dynamic height. Long subtitle
text should not break the layout.

The row should remain fully clickable. The video file name is not currently
shown in the result row.

Layout and Selection Behavior:

- The selected-row background starts on the same left edge as the group
  disclosure rail. Result-row subtitle text starts on the same left edge
  as the subtitle file name in the header.
- The selected-row background and group header text area keep their right
  edges aligned.
- Rows do not use horizontal dividers. Row separation should come from
  internal padding, group headers, and readable text spacing.
- Internal wrapped subtitle lines, including SRT line breaks and ASS `\N`
  line breaks rendered inside a single cue line, should use 4pt line
  spacing so bilingual subtitle text does not appear cramped.
- Selection feedback is an input response, not a playback completion response.
  Workbench mode selection, Library episode selection, Search result
  selection, and Shiori row selection must update their visible selected state
  immediately when the user activates the item. Video opening, seeking, subtitle
  loading, and ASS rendering preparation may continue afterward but must not
  delay the selected visual state.

## 8. Playback Area And Shared Content Panel

The CueSeeker workbench uses a player-first layout.

For the Search-first topbar transition, Search-launched playback uses a
dedicated main-content playback page. This playback page may hide or bypass the
old Mode Rail and Shared Content Panel when convenient, while Library, Shiori,
and Settings remain available through their current surfaces until they are
migrated.

The Playback Area is the central playback and result-detail surface. The Shared
Content Panel is the left-side Library, Search, and Shiori surface selected by
the fixed Mode Rail.

As future navigation or learning features arrive, the Playback Area remains the
central experience. New panel modes must be documented before implementation
instead of recreating a separate right-side panel by default.

Playback Area required content:

- Embedded video.
- A `Video Folder` button.
- A `Subtitle Folder` button.
- For Search-launched playback, `Previous Result`, `Next Result`, `Results`,
  and `Subtitles` buttons.

Search-launched playback result navigation:

- `Previous Result` and `Next Result` use the complete active Search result
  order, exactly matching the Search results page order.
- Result navigation is not scoped to the current video path or subtitle path.
- Current playback time is used to identify the current Search-result anchor
  before moving backward or forward in the complete result order.
- The `Results` button opens upward and displays at least the previous,
  current, and next Search results. It does not show `Collapse All`.
- The `Subtitles` button opens upward and displays the current playback subtitle
  file in timestamp order. It does not use keyword highlighting. The current
  playback subtitle row uses selected-state context only.

The Playback Area should not show read-only `Start Time`, `Video Path`, or
`Subtitle Path` metadata labels and values under the video. The previous
metadata area should instead provide the two file-location buttons.

The `Video Folder` and `Subtitle Folder` buttons should visually match the
ordinary Settings action buttons. Each button should use a folder icon to the
left of the text label.

Search mode required content:

- Search input.
- Indexing status when relevant.
- Result count.
- Collapse or expand-all result control.
- Grouped Search results.
- Empty, loading, and error states.

Shiori mode required content:

- Shiori summary text in the form `<count> shioris in <count> files`.
- A fixed `Collapse All` control that does not change into an expand-all control.
- Grouped Shiori rows, expanded by default.
- Empty and error states.

Future Search mode actions may include hover buttons and contextual menus on
result rows. A result-level `Add to Queue` action is an accepted future
direction for building playback queues from Search.

Behavior:

- Selecting a result opens or updates the Playback Area.
- Selecting a result should preserve the Shared Content Panel when it is
  expanded in Search mode.
- Clicking the embedded video toggles play/pause.
- Clicking the playback operation controls should not toggle play/pause unless the play/pause control is targeted.
- The playback Shiori control should sit immediately to the left of the
  pencil-tip copy-current-subtitle control.
- Saving a Shiori should show transient playback feedback with the Shiori icon
  and `Shiori Saved`.
- Removing a Shiori should show transient playback feedback with the Shiori icon
  and `Shiori Removed`.
- Collapsing the Shared Content Panel hides the active mode content.
- Collapsing the Shared Content Panel expands the available width for the
  Playback Area.
- Collapsing the Shared Content Panel does not pause playback.
- Collapsing the Shared Content Panel does not clear the current selected
  result.
- Reopening the Shared Content Panel should restore the current mode context
  when practical and should not automatically change playback state.
- Opening Settings from the app menu does not pause playback, collapse either
  workbench panel, or clear the selected result.
- Switching to another future main-window workspace section may
  pause playback without stopping it when that section is documented.
- Clicking `Video Folder` reveals the matched video file in Finder.
- Clicking `Subtitle Folder` reveals the source subtitle file in Finder.
- Playback fullscreen uses the main CueSeeker window's AppKit native fullscreen
  behavior, then presents a video-only playback surface instead of the normal
  workbench shell.
- Playback fullscreen should follow standard macOS Space, Dock, menu bar, app
  switching, and system overlay behavior.
- Transient playback feedback overlays appear above the video for play/pause, subtitle visibility, seek, volume, and speed changes.
- The playback speed selector is an app-drawn menu that opens upward from the speed control.
- The speed control must display fractional presets such as `1.25x` and `1.75x` without truncation.
- The speed control should show only the current speed value; the preset menu appears on hover rather than through a visible arrow affordance.
- The speed control hover area, click area, and preset menu width should match.
- The speed menu should remain open only while the pointer is inside the rectangular hover region spanning from the menu top edge to the speed button bottom edge.
- When the volume control is hovered, the volume slider and numeric percentage appear together without moving the playback controls vertically.
- The timeline hover and drag states must not move the playback controls vertically.

Layout:

- The fixed Mode Rail appears on the far left of the CueSeeker workbench below
  the titlebar.
- The Shared Content Panel appears immediately to the right of the Mode Rail
  when expanded.
- The Playback Area appears in the central workbench region.
- The Shared Content Panel is resizable by dragging its right edge.
- The Playback Area width changes dynamically as the Shared Content Panel width
  or visibility changes.
- The Shared Content Panel should feel like a fixed-width drawer. Collapsing it
  slides its full-width content out of view while the Playback Area receives or
  releases the corresponding space; panel contents should not visibly compress
  during the animation.
- The embedded Playback Area is a fixed top-aligned playback surface with
  command buttons below it, not a document-style scroll page in normal
  workbench playback.
- The Playback Area should receive priority when the window cannot comfortably
  show both panes.
- The Shared Content Panel must keep a usable minimum width when expanded.

Initial sizing guidance:

- Mode Rail width: fixed and not user-resizable.
- Shared Content Panel default width: `420pt`.
- Shared Content Panel minimum width: `420pt`.
- Playback Area minimum width: `520pt`.
- Shared Content Panel maximum width: available content width minus the Mode
  Rail width and Playback Area minimum width.

The Mode Rail owns Library, Search, and Shiori mode selection. The old titlebar
side-panel toggles and right-side mode buttons are not part of the current
layout.

Panel visibility and list lifetime:

- The workbench panel shells should remain stable when their visibility
  changes. A collapse action should change layout visibility or width, not
  discard the panel's large list state.
- Library rows are static indexed-resource presentation loaded from a persisted
  Library snapshot. They should remain cached until Library data or Library
  ordering inputs change. Session-only Library collapse state is a view state
  overlay and must not regenerate Library rows.
- Search rows are active query presentation. They should remain cached until
  the query, loaded result page, Search-group collapse state, or Search ordering
  inputs change.
- Shiori rows are saved-content presentation. They should remain cached until
  the Shiori record set or Shiori-group collapse state changes.
- Future panel modes such as Timeline, Queue, and Learning Session should keep
  their own presentation state separate from Library, Search, and Shiori rows.
- Switching panel modes should feel like changing tools in a stable panel, not
  like reopening the workbench. Library, Timeline, Shiori, Search, Queue, and
  Learning Session should preserve local scroll, collapse, selection, and draft
  state where practical.
- The first SwiftUI implementation may use lazy list rendering, but grouped
  rows should be flattened when necessary so laziness applies to individual
  visible rows rather than to one large group view containing many child rows.
- Dense row lists should prefer lightweight row interactions. Hover buttons,
  plus actions, Shiori actions, context menus, and full-row click targets should not
  make the list feel like a column of heavy native buttons.

M1 does not require advanced visual effects.

Current M2 playback control terminology:

- `Timeline Zone`: the progress bar and its enlarged seek hit area.
- `Transport Controls Zone`: the button row below the progress bar.
- `Playback Operation Zone`: the combined `Timeline Zone` and `Transport Controls Zone`.

## 9. Settings Window

Settings should be an independent macOS settings window, not a main-window
sidebar section.

Formal entry:

- `CueSeeker > Settings...` in the macOS app menu.
- Bottom Settings button in the Mode Rail.
- The standard `Command-,` shortcut may also be exposed if practical.

Window structure:

```text
Settings Window
Left Settings Category List
Right Settings Content
```

The left Settings category list should use the current quiet gray background
treatment. The right Settings content area should use the current white content
background treatment.

Current Settings categories:

- `Library`.
- `Decode`.
- `Layout`.

The `Library` category should allow local folder management.

Required `Library` elements:

- List of indexed folders.
- Add folder action.
- Global `Index Now` action next to the add-folder action. This action should
  reindex all selected folders.
- Per-folder remove action.
- Remove confirmation dialog explaining that local files will not be deleted.
- Indexing status.

The `Decode` category should expose an app-drawn segmented control for
`hardware`, `software`, and `auto`, avoiding native menu services during the
normal Settings window lifecycle.

The `Layout` category should expose the `Sidebar Position` setting with `Left`
and `Right` choices. Changing this setting should immediately move the Mode
Rail and Shared Content Panel to the selected side while preserving panel mode,
panel visibility, panel width, playback state, and current Search/Shiori/Library
state.

Settings should be functional and clear before they are visually refined.
Opening, focusing, or closing Settings should not pause playback, switch the
main workspace away from the CueSeeker workbench, collapse the Shared Content
Panel, or clear the selected Search result.

The Add Folder action should continue to use the native macOS folder selection
experience. It may temporarily create Open and Save Panel or QuickLook helper
services while the panel is open. The UI should avoid unnecessary helper
creation during normal Settings window navigation, but it should not replace the
native folder picker only to minimize process count.

## 10. Visual Style

Initial visual style should be restrained.

Preferred characteristics:

- Native macOS controls where practical.
- Clear spacing.
- Good text hierarchy.
- Minimal color dependence.
- Accessible contrast.
- No decorative gradients or unnecessary cards.
