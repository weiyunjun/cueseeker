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

## 2. Main Window

The main window should be a persistent work surface.

Accepted M1 structure:

```text
Native titlebar
CueSeeker workbench
Left Content Panel
Playback Area
Right Learning Panel
```

The main window should support:

- Resizing.
- Reasonable minimum size.
- Restoring previous size if practical.
- Native toolbar or sidebar behavior where appropriate.

Current shell direction:

- Traffic lights, the Library panel toggle, the centered workbench title, and
  the Search Panel Toggle belong to the titlebar.
- The Library panel toggle should stay in a fixed titlebar position near the
  traffic lights and should collapse or expand the Left Content Panel.
- The Search Panel Toggle should stay in a fixed titlebar position on the right
  side and should collapse or expand the right-side Search Panel.
- The centered title should read `CueSeeker`. It should not read `Search`
  because Search is now a right-side panel workflow, not the main-window
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

Current sections:

- None.

Future main-window sections should be added only when they are true workspace
destinations. Shiori should remain a panel mode unless a later product rule
promotes it to main-window navigation.

Settings should not be a main-window sidebar section. The formal Settings entry
belongs in the macOS app menu and opens an independent Settings window.

If top-level navigation returns later, it should remain visually quiet and
should not compete with Library, Search results, or playback. The titlebar's
left control is reserved for Library visibility in the current workbench, not
for toggling a standalone `Search` sidebar.

## 4. Main Workspace Panel Model

The long-term main workspace should be organized around playback as the central
experience.

Conceptual structure:

```text
Left Content Panel
Playback Area
Right Learning Panel
```

The main window is the CueSeeker workbench. The old standalone `Search`
AppShell destination should not appear in the current single-workbench design.
Settings is app-level configuration and belongs in the macOS app menu and
independent Settings window, not in main-window navigation.

The Left Content Panel is for known content and precise location:

- Library.
- Current video subtitle Timeline.

The Right Learning Panel is for active learning workflows:

- Search.
- Shiori.
- Queue.
- Learning Session.

The two side panels should not become generic tool drawers. The left side is for
content structure and precise navigation. The right side is for search,
collection, aggregation, queue building, and learning-session configuration.

This panel model keeps playback central. Search is a Right Learning Panel mode
beside the Playback Area, not the top-level workspace identity.

Accepted first Library panel direction:

- Library is the first concrete Left Content Panel for known video navigation.
- Library is separate from the Settings `Library` category.
- Library keeps the left-side gray background treatment.
- Library can collapse or expand through the fixed left titlebar control.
- Library can be resized horizontally. Its default width should equal its
  minimum width.
- Library's first default and minimum width should be `310pt`, `50pt` narrower
  than the previous fixed `360pt` Library width.
- Library width should persist when the user changes it.
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
- A chevron on the right of the folder row indicates expand or collapse state.
  The full folder row is the click target that toggles expand or collapse.
- Expanded folders show a numbered button grid using each video's one-based
  natural-sort sibling rank. The grid does not display file names, durations,
  or language tags. Per-video metadata stays available for tooltips, future
  hover information, and accessibility, but is not part of the visible grid
  rendering.
- The episode grid uses minimum-button-width auto-flow columns; the column
  count adapts to the current Library panel width.
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

## 5. CueSeeker Workbench And Search Panel

The CueSeeker workbench is the primary screen. Search is the right-side learning
panel inside that workbench.

Required elements:

- Left-side Library panel when expanded.
- Central Playback Area.
- Right-side Search Panel.
- Search input.
- Indexing status when relevant.
- Search result list.
- Empty state when no query or no results exist.
- Error state when search or database access fails.

The search input should stay easy to access when the Search Panel is expanded.
The Search Panel must have a clear restore path when collapsed.

Accepted player-first Search presentation:

- The main titlebar identifies the workbench as `CueSeeker`.
- The embedded Playback Area remains central.
- Search controls and grouped Search results appear in a right-side Search
  Panel.
- The right-side Search Panel may be collapsed so the Playback Area can expand.
- Collapsing the Search Panel must not pause playback or clear the selected
  result.
- The Playback Area is the primary review surface after a result is selected;
  Search is the functional navigation and result-selection surface.

Accepted M1 search presentation:

- The search field is a custom `NSTextView` wrapper (`SearchTextView`) allowing a 36pt high field, a 4pt gray focus outline, zero baseline jitter, a leading magnifying-glass icon, and an inline clear button.
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
- Search results are grouped under subtitle-file headers.
- Selecting a search result opens or updates the central Playback Area without
  leaving the CueSeeker workbench.
- Search results use refined macOS-native typography and highlight query
  matches with a yellow background that remains readable on selected rows.
- Search result visual polish is still incomplete and subject to further iteration.

## 6. Search Result Group

Each subtitle-file group should be compact and scannable.

The group header should display:

- A disclosure triangle on the left.
- A friendly subtitle group title followed by two spaces and the per-file
  result count as plain text, for example `葬送的芙莉莲 - 05  3 results` or
  `葬送的芙莉莲 - 05  1 result`.

The group header should be clickable as a single target and should toggle
collapse or expansion. The disclosure triangle indicates state; it does not need
to be the only clickable control.

Groups should be expanded by default.

The grouped Search header should not render a per-file count badge or a
separate right-aligned count component. Per-file match totals should appear as
plain text appended to the display title, while also remaining available in search
state for loading and future sorting behavior.

Friendly group titles should use the immediate parent folder name plus the
subtitle file's one-based natural-sort rank among visible regular sibling
subtitle files with the same final subtitle extension. The rank should use
Finder-like localized standard comparison so numeric filename runs sort by
numeric value.

The display title format is `Parent Folder Name - NN`, with the numeric suffix
zero-padded to at least two digits. If the friendly title cannot be derived, the
header should fall back to the raw subtitle filename. Fallback filenames may
wrap across multiple lines and may include invisible soft wrap opportunities
after common filename delimiters such as `]`, `.`, `_`, and `-` so long
bracketed names use available width more naturally without changing the visible
filename.

Group title text and result-row subtitle text should align on the same left
edge. The disclosure triangle should live in the left-side control space so it
does not add extra indentation to result-row subtitle text. The exact spacing
may be refined during implementation.

Expanding a collapsed group should display at most the first 100 matching rows
for that subtitle file.

Group ordering should be stable and based on the friendly display title when it
is available. If two groups have the same display title, or if a group falls
back to the source subtitle filename, the full subtitle path should be used as
the secondary stable ordering key.

## 7. Search Result Row

Each result row should be compact and scannable.

Current M1 row content:

- Subtitle text as the primary content.
- Query match highlighting.
- Start timestamp at the right side.

Current result-row color behavior:

- Selected rows use the macOS unemphasized selected-content background.
- Selected subtitle text and selected start timestamps use the same primary
  text color.
- Unselected subtitle text and unselected start timestamps use the same
  slightly muted primary text color so rows remain readable without competing
  with the selected row.

Grouped cue result rows should display every cue line in the matched group,
ordered by derived display order when available. Grouped rows may use dynamic
height and must not deduplicate same-looking cue lines or impose a fixed
product-level line count cap.

Rows inside the same subtitle-file group should be ordered by subtitle
timestamp ascending.

Rows should have stable height or predictable dynamic height. Long subtitle text should not break the layout.

The row should remain fully clickable. The video file name is not currently shown
in the search result row.

Layout and Selection Behavior:

- The selected-row background starts on the same left edge as the group
  disclosure triangle.
- Result-row subtitle text starts on the same left edge as the subtitle file
  name.
- The selected-row background and group header text area keep their right edges
  aligned.
- Rows do not use horizontal dividers. Row separation should come from internal
  padding, group headers, and readable text spacing.
- When a row is selected, it renders a macOS unemphasized gray rounded
  rectangle background while preserving the normal primary subtitle text color.
- Query-match highlighting should use a lighter yellow background on unselected
  rows and a stronger yellow background on selected rows.
- The right-side start timestamp should be visually secondary to subtitle text:
  tertiary on unselected rows and secondary on selected rows.
- Internal wrapped subtitle lines, including SRT line breaks and ASS `\N`
  line breaks rendered inside a single cue line, should use 4pt line spacing so
  bilingual subtitle text does not appear cramped.

## 8. Playback Area And Search Panel

The CueSeeker workbench uses a player-first layout.

The Playback Area is the central playback and result-detail surface. The Search
Panel is the right-side search and result-selection surface.

As future left-side navigation features arrive, the Playback Area remains the
central experience. A Left Content Panel may appear to its left for Library or
Timeline navigation, but that does not move Search or Shiori back to the left
side.

Playback Area required content:

- Embedded video.
- A `Video Folder` button.
- A `Subtitle Folder` button.

The Playback Area should not show read-only `Start Time`, `Video Path`, or
`Subtitle Path` metadata labels and values under the video. The previous
metadata area should instead provide the two file-location buttons.

The `Video Folder` and `Subtitle Folder` buttons should visually match the
ordinary Settings action buttons. Each button should use a folder icon to the
left of the text label.

Search Panel required content:

- Search input.
- Indexing status when relevant.
- Result count.
- Collapse or expand-all result control.
- Grouped Search results.
- Empty, loading, and error states.

Shiori Panel required content:

- Shiori summary text in the form `<count> shioris in <count> files`.
- A fixed `Collapse All` control that does not change into an expand-all control.
- Grouped Shiori rows, expanded by default.
- Empty and error states.

Future Search Panel actions may include hover buttons and contextual menus on
result rows. A result-level `Add to Queue` action is an accepted future
direction for building playback queues from Search.

Behavior:

- Selecting a result opens or updates the Playback Area.
- Selecting a result should preserve the Search Panel when it is expanded.
- Clicking the embedded video toggles play/pause.
- Clicking the playback operation controls should not toggle play/pause unless the play/pause control is targeted.
- The playback Shiori control should sit immediately to the left of the
  pencil-tip copy-current-subtitle control.
- Saving a Shiori should show transient playback feedback with the Shiori icon
  and `Shiori Saved`.
- Removing a Shiori should show transient playback feedback with the Shiori icon
  and `Shiori Removed`.
- Collapsing the Search Panel hides search controls and result rows.
- Collapsing the Search Panel expands the available width for the Playback
  Area.
- Collapsing the Search Panel does not pause playback.
- Collapsing the Search Panel does not clear the current selected result.
- Reopening the Search Panel should restore the current Search context when
  practical and should not automatically change playback state.
- Opening Settings from the app menu does not pause playback, collapse either
  side panel, or clear the selected result.
- Switching to another future main-window workspace section may
  pause playback without stopping it when that section is documented.
- Clicking `Video Folder` reveals the matched video file in Finder.
- Clicking `Subtitle Folder` reveals the source subtitle file in Finder.
- Playback fullscreen presents the video in a dedicated playback window that
  enters AppKit's native Full Screen Space rather than fullscreening the main
  CueSeeker workbench shell.
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

- The Library panel appears on the left side of the CueSeeker workbench when
  expanded.
- The Playback Area appears in the central workbench region.
- The Search Panel appears on the right side of the CueSeeker workbench.
- The Library panel is resizable by dragging its right edge.
- The Search Panel is resizable by dragging its left edge.
- The Playback Area width changes dynamically as the Library and Search Panel
  widths or visibility change.
- Side panels should feel like fixed-width drawers. Collapsing a panel slides
  its full-width content out of view while the Playback Area receives or
  releases the corresponding space; panel contents should not visibly compress
  during the animation.
- The embedded Playback Area is a fixed top-aligned playback surface with
  command buttons below it, not a document-style scroll page in normal
  workbench playback.
- The Playback Area should receive priority when the window cannot comfortably
  show both panes.
- The Library panel must keep a usable minimum width when expanded.
- The Search Panel must keep a usable minimum width when expanded.

Initial sizing guidance:

- Library panel default width: `310pt`.
- Library panel minimum width: `310pt`.
- Playback Area minimum width: `520pt`.
- Search Panel default width: `480pt`.
- Search Panel minimum width: `420pt`.
- Search Panel maximum width: available content width minus the Library panel
  width and Playback Area minimum width.

The Library panel toggle belongs in the titlebar at a fixed left-side position
near the traffic lights. The Search Panel Toggle belongs in the titlebar at a
fixed right-side position.

Panel visibility and list lifetime:

- The workbench side-panel shells should remain stable when their visibility
  changes. A collapse action should change layout visibility or width, not
  discard the panel's large list state.
- Library rows are static indexed-resource presentation loaded from a persisted
  Library snapshot. They should remain cached until Library data or Library
  ordering inputs change. Session-only Library collapse state is a view state
  overlay and must not regenerate Library rows.
- Search rows are active query presentation. They should remain cached until
  the query, loaded result page, Search-group collapse state, or Search ordering
  inputs change.
- Future Left Content Panel modes such as Timeline should keep their own
  presentation state separate from Library rows.
- Future Right Learning Panel modes such as Shiori, Queue, and Learning Session
  should keep their own presentation state separate from Search result rows.
- Switching future Left or Right panel modes should feel like changing tools in
  a stable panel, not like reopening the workbench. Library, Timeline,
  Shiori, Search, Queue, and Learning Session should preserve local scroll,
  collapse, selection, and draft state where practical.
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

Settings should be functional and clear before they are visually refined.
Opening, focusing, or closing Settings should not pause playback, switch the
main workspace away from the CueSeeker workbench, collapse either side panel,
or clear the selected Search result.

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
