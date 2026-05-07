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
Sidebar navigation
Main Workspace (Search workspace and future workspace panels)
```

The main window should support:

- Resizing.
- Reasonable minimum size.
- Restoring previous size if practical.
- Native toolbar or sidebar behavior where appropriate.

Current shell direction:

- Traffic lights, sidebar toggle, and the current section title belong to the titlebar.
- The sidebar toggle should stay in a fixed titlebar position near the traffic lights.
- The Search Panel Toggle should stay in a fixed titlebar position on the right side when Search is active.
- The current section title should remain centered in the titlebar.
- Traffic lights are shifted 12pt to the right and vertically centered within the custom titlebar. To achieve this without fighting AppKit's native layout engine during window resizing, the standard window buttons (`.closeButton`, `.miniaturizeButton`, `.zoomButton`) are reparented (extracted from their system container and placed into a custom transparent `NSView` proxy). This preserves native hover effects and accurate hit testing.
- The native `NSWindow` title visibility is hidden in windowed mode but temporarily restored during full-screen transitions, ensuring the system drop-down title bar is fully functional.
- The `NSWindow` title dynamically tracks the active main workspace section to ensure correct contextual labeling in the full-screen drop-down title bar.
- To prevent UI artifacts when exiting full-screen mode, the native title visibility is hidden in the `windowWillExitFullScreen` delegate callback before the transition animation begins.
- The titlebar should use a slightly darker gray than the main content background.
- A thin gray divider should separate the titlebar from the content below.
- The titlebar should visually sit above the sidebar.
- The sidebar should use a quiet background and a right-side divider, not a heavy shadow.
- The window automatically maximizes to the screen's visible frame upon launch.
- The current titlebar/sidebar implementation is an M1 iteration, not final polish.

## 3. Sidebar

The sidebar should provide high-level main-window navigation.

Current sections:

- Search.

Future main-window sections should be added only when they are true workspace
destinations. Favorites should primarily belong to the Left Content Panel as
durable saved content unless a later product rule promotes it to main-window
navigation.

Settings should not be a main-window sidebar section. The formal Settings entry
belongs in the macOS app menu and opens an independent Settings window.

The sidebar should remain visually quiet and should not compete with search results or playback.

Current M1 behavior:

- The sidebar can be expanded or collapsed through the titlebar toggle.
- When expanded, the sidebar is a single visual navigation region under the titlebar.
- When collapsed, the main content receives a left inset so content does not start underneath the traffic lights and titlebar toggle.
- Sidebar edge treatment should remain subtle. A gray divider is preferred over a drop shadow for the current M1 shell.
- Selected sidebar items use a solid accent background with white text. Sidebar items do not respond to hover.

## 4. Main Workspace Panel Model

The long-term main workspace should be organized around playback as the central
experience.

Conceptual structure:

```text
Leftmost AppShell sidebar
Left Content Panel
Playback Area
Right Learning Panel
```

The leftmost AppShell sidebar is main-window navigation. It is separate from
the Left Content Panel and should continue to own main-window app sections such
as `Search`. Settings is app-level configuration and belongs in the macOS app
menu and independent Settings window, not in this sidebar.

The Left Content Panel is for known content and precise location:

- Library.
- Current video subtitle Timeline.
- Favorites.

The Right Learning Panel is for active learning workflows:

- Search.
- Queue.
- Learning Session.

The two side panels should not become generic tool drawers. The left side is for
content structure and precise navigation. The right side is for search,
collection, aggregation, queue building, and learning-session configuration.

This panel model does not change the accepted player-first Search layout. The
immediate Search workspace still places the Playback Area on the left and the
Search Panel on the right.

Accepted first Library panel direction:

- Library is the first concrete Left Content Panel for known video navigation.
- Library is separate from the leftmost AppShell sidebar and from the Settings
  `Library` category.
- Library keeps the left-side gray background treatment.
- Library uses a fixed first-implementation width that is 100 pt wider than
  the current left-panel baseline. Resizing can be designed later.
- Library uses a dense grouped-list structure comparable to Search results.
- Library shows only one folder grouping level.
- Folder groups and video rows use Finder-like natural ordering.
- Folder groups are expanded by default and can be collapsed independently.
- A top action toggles all folder groups with `Collapse All` and `Expand All`.
- Video rows display `Parent Folder Name - NN  extension`, such as
  `葬送的芙莉莲 - 01  mkv`.
- Video duration appears on the right side of each video row.
- Clicking a video row opens or updates playback from `0` for this version.

## 5. Search View

The search view is the primary screen.

Required elements:

- Left-side Playback Area.
- Right-side Search Panel.
- Search input.
- Indexing status when relevant.
- Search result list.
- Empty state when no query or no results exist.
- Error state when search or database access fails.

The search input should stay easy to access when the Search Panel is expanded.
The Search Panel must have a clear restore path when collapsed.

Accepted player-first Search presentation:

- The leftmost app sidebar remains outside the Search workspace layout swap and
  continues to own main-window navigation such as `Search`.
- The embedded Playback Area appears on the left side of the Search workspace.
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
- Selecting a search result opens or updates the left-side Playback Area without leaving Search.
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

The Search workspace uses a player-first layout.

The Playback Area is the left-side playback and result-detail surface in the
Search workspace. The Search Panel is the right-side search and result-selection
surface.

As future left-side navigation features arrive, the Playback Area remains the
central experience. A Left Content Panel may appear to its left for Library,
Timeline, or Favorites navigation, but that does not move Search back to the
left side.

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

Future Search Panel actions may include hover buttons and contextual menus on
result rows. A result-level `Add to Queue` action is an accepted future
direction for building playback queues from Search.

Behavior:

- Selecting a result opens or updates the Playback Area.
- Selecting a result should preserve the Search Panel when it is expanded.
- Clicking the embedded video toggles play/pause.
- Clicking the playback operation controls should not toggle play/pause unless the play/pause control is targeted.
- Collapsing the Search Panel hides search controls and result rows.
- Collapsing the Search Panel expands the available width for the Playback
  Area.
- Collapsing the Search Panel does not pause playback.
- Collapsing the Search Panel does not clear the current selected result.
- Reopening the Search Panel should restore the current Search context when
  practical and should not automatically change playback state.
- Opening Settings from the app menu does not switch the main workspace away
  from Search, pause playback, collapse the Search Panel, or clear the selected
  result.
- Switching from Search to another future main-window workspace section may
  pause playback without stopping it when that section is documented.
- Clicking `Video Folder` reveals the matched video file in Finder.
- Clicking `Subtitle Folder` reveals the source subtitle file in Finder.
- Playback fullscreen presents the video in a black Theater Mode window rather than fullscreening the app shell.
- Theater Mode must not visually cover system app-switching UI; Cmd-Tab and other system overlays should appear above playback fullscreen.
- When the app resigns active during Theater Mode, playback fullscreen hides and then restores when the app becomes active again.
- Transient playback feedback overlays appear above the video for play/pause, subtitle visibility, seek, volume, and speed changes.
- The playback speed selector is an app-drawn menu that opens upward from the speed control.
- The speed control must display fractional presets such as `1.25x` and `1.75x` without truncation.
- The speed control should show only the current speed value; the preset menu appears on hover rather than through a visible arrow affordance.
- The speed control hover area, click area, and preset menu width should match.
- The speed menu should remain open only while the pointer is inside the rectangular hover region spanning from the menu top edge to the speed button bottom edge.
- When the volume control is hovered, the volume slider and numeric percentage appear together without moving the playback controls vertically.
- The timeline hover and drag states must not move the playback controls vertically.

Layout:

- The leftmost app sidebar remains separate from this Search workspace layout
  and keeps its existing main-window navigation behavior.
- The Playback Area appears on the left side of the Search workspace.
- The Search Panel appears on the right side of the Search workspace.
- The Search Panel is resizable by dragging its left edge.
- The sidebar width remains fixed according to the current shell behavior.
- The Playback Area width changes dynamically as the Search Panel width changes.
- The Playback Area should receive priority when the window cannot comfortably
  show both panes.
- The Search Panel must keep a usable minimum width when expanded.

Initial sizing guidance:

- Playback Area minimum width: `520pt`.
- Search Panel default width: `480pt`.
- Search Panel minimum width: `420pt`.
- Search Panel maximum width: available content width minus the Playback Area
  minimum width.

The Search Panel Toggle belongs in the titlebar at a fixed right-side position
when Search is active. It should conceptually match the sidebar toggle pattern
while controlling the right-side Search Panel.

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
main workspace away from Search, collapse the Search Panel, or clear the
selected Search result.

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
