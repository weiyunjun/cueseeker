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

UI collaboration and prototype acceptance rules are defined in
`docs/product/10_ui_collaboration_workflow.md`. App interface changes should
use local HTML prototypes under `ui/prototypes/` as the visual alignment
baseline before native implementation.

## 1.1 Accepted Topbar Card Workbench Transition

The accepted current UI direction is a topbar-driven single-page work surface
with an active-playback bottom player.

This transition supersedes the Mode Rail and Shared Content Panel requirements
for Search and Shiori. Library is also entered from the topbar, but detailed
Library visual adaptation remains a later pass.

First implementation requirements:

- Add a fixed-width Search field to the topbar.
- Place Library and Shiori icon buttons immediately to the left of the topbar
  Search field.
- The topbar follows the HTML prototype direction: it shares the content area's
  background, has no bottom divider, and visually centers the Library/Shiori
  icon cluster with the Search field.
- Library and Shiori topbar buttons use outline icons in both normal and
  selected states. Hover uses a light gray background. Selected state uses a
  darker gray background with a darker icon, not a filled icon or accent-color
  treatment.
- The topbar Search field uses a neutral white rounded rectangle with a
  `44pt` height, `14pt` corner radius, and gray border. Focus must not add a
  strong accent-color ring.
- Treat text editing in the topbar Search field as the active query. Apply the
  latest edit automatically after a `100ms` debounce; Return is not a Search
  submission command.
- Show live Search results in the main content area.
- Render Search results as individual Cue rows in the shared native virtual
  table described in section 4.1.
- Render Shiori and Context with the same Cue-row table geometry and interaction
  model as Search, with Shiori-only Tags and Date Added columns.
- Search, Shiori, and Context rows must show the complete Cue text without
  clipping, truncation, ellipsis, or a line-count cap.
- Row height is content-driven rather than equalized across neighboring rows.
- Table metadata uses Display Title, Time, and the surface-specific columns
  defined in section 4.1; it must not infer episode labels without a reliable
  source.
- Remove the visible Mode Rail, resizable content-panel sidebar, and sidebar
  position setting from the active workbench.
- Do not render a second Search field inside the Search results page.
- Clicking a Search result opens the playback surface and creates an active
  playback session.
- The playback surface exposes a top-left `Close` capsule button. Closing
  playback ends the current playback session and returns to the workbench.
- The expanded playback overlay uses a rectangular black background that covers
  the full work area between the topbar and the bottom player, preserves a
  rounded video surface, and shows a right-side panel for `Search Results` and
  `Subtitles`.
- The overlay side panel places the `Search Results` / `Subtitles` switcher at
  the top and the active count label below on the left. It must not repeat the
  current video title or a `Search playback` label above the tabs.
- The overlay side panel uses a light glass surface with compact row cards.
  Selected rows use a white glass card with accent emphasis instead of a
  full-width accent fill.
- The bottom-player right controls include a standalone circular subtitle
  visibility toggle, playback speed, and fullscreen. Shiori and copy commands
  are not present in normal playback chrome.
- Compact operation buttons use circular icon buttons. Active toggle state is
  shown by a white circular button background and pressed state, while the
  semantic glyph remains stable across selected and unselected states.
- Text, command, and value controls use capsules. The playback `Close` command
  uses the compact capsule form, and the playback-speed capsule keeps a fixed
  width that fits the longest current preset label.
- Search Results rows may highlight query matches. Subtitles rows represent the
  full subtitle file and must not apply keyword highlighting.
- Show the bottom player only while the video playback page is visible.
  Non-video Search, Library, and Shiori pages must not show the bottom player.
- The old bottom-player left source/title expand-collapse capsule is removed
  from the active target UI. The volume button becomes the leftmost bottom-player
  control; other bottom-player controls keep their relative positions.
- First-pass visual polish is explicitly secondary to complete functionality.

The related accepted proposal is
`docs/proposals/2026-05-topbar-search-single-page-workflow.md`.

## 1.2 Current Liquid Glass Prototype Baseline

Current prototype:

```text
ui/prototypes/cueseeker-liquid-glass-standalone.html
```

Current review fork for Liquid Glass control states and prototype-only review
controls:

```text
ui/prototypes/cueseeker-liquid-glass-v5/
```

The standalone prototype remains a visual baseline for the main workbench,
Search-launched playback overlay, playback side panel, and video-page bottom
player. Its grouped Search/Shiori card presentation is superseded and is not a
normative reference for the current Cue table. The v5 directory is the
current split-source review fork for control taxonomy, disabled states,
prototype theme switching, bottom-player control sizing, and expanded playback
video geometry. Earlier versioned forks remain available for visual comparison.
App implementation still requires a separate explicit approval after the HTML
has been accepted.

Stable design snapshot:

- The main surface uses a restrained light Liquid Glass treatment: translucent
  silver-gray window material, soft internal highlights, subtle hairlines, and
  low-contrast shadows.
- The prototype has grouped workbench states and an expanded playback state.
  The expanded playback state shows the video-page bottom player while
  replacing the main results area with a video surface and optional right side
  panel.
- Search, Shiori, and Context use an ungrouped native virtual table whose row
  identity and default action target are one primary Cue. They have no
  subtitle-file disclosure header or `Collapse All` action.
- Search query matches may remain highlighted inside the primary Cue text.
  Library can continue to use its accepted card and disclosure presentation;
  that Library pattern does not define Search, Shiori, or Context.
- Export actions operate on selected Cue rows rather than on subtitle-file
  group headers.
- The expanded video surface is a black playback frame with a subtitle overlay.
  The overlay can be shown or hidden from the bottom player without resizing
  the bottom player controls.
- The expanded video surface owns a `Close` capsule anchored to the active
  video frame's top-left corner. It is a command button over the actual video
  image area, not the black base's top-left corner and not a replacement for
  fullscreen exit.
- The playback side panel contains a two-tab segmented control for Search
  Results and Subtitles, a compact summary, and scrollable row cards. The side
  panel can be hidden or restored from the bottom player.
- In the native App, the expanded playback side panel occupies the full right
  column height. The video stage and bottom player occupy the left column and
  are squeezed by that column instead of being covered by the side panel.
- The bottom player uses a three-zone layout: volume on the left, transport
  controls in the center, and playback operations on the right.
- In expanded playback, the bottom player is positioned from the active left
  black video column, not from the full window. It uses fixed left and right
  margins inside that black base, and its horizontal geometry must update
  immediately during resize without animating `left` or `width`.
- The HTML prototype represents video with a gray frame labeled as the video
  area. The review default uses `16:9`, but App implementation must use the
  active video's real aspect ratio.
- In expanded playback, the left column's black base is the positioning
  container. The video frame should keep its aspect ratio and maximize within
  that black base, so either width or height reaches the available limit.
- The video frame is centered within the black base after aspect-fit sizing.
  The bottom player is a floating chrome overlay and does not participate in
  video-frame layout.
- In expanded playback, player UI means the bottom player plus the video-frame
  `Close` capsule. They share one visible/not-visible state. Entering the
  playback page initializes player UI as visible. Mouse movement is the primary
  visibility input: movement inside the player area reveals player UI, movement
  out of the player area hides it, and three seconds of no movement inside the
  frozen display-check area hides player UI and the cursor. Player UI show and
  hide state changes do not animate.
- Bottom-player buttons use two primary button forms: circular icon buttons and
  capsule buttons. Circular buttons are used for single-action icon controls.
  Capsule buttons are used for text, values, titles, and controls that require
  a wider label.
- Circular icon buttons have no visible container in the normal state. Their
  hover state introduces a circular glass background, and their pressed state
  uses a brief scale-down response.
- Capsule buttons have a visible glass background in the normal state. Hover
  may subtly strengthen the material but must not introduce a new button form
  or a strong additional container. Their pressed state also uses a brief
  scale-down response.
- Controls with selected and unselected states use circular icon buttons. In
  light mode, selected state uses a soft gray circular background with inverted
  icon color. In dark mode, selected state uses a light circular background
  with dark icon color. Toggle icon buttons also switch their semantic glyph:
  unselected state uses the outline glyph, and selected state uses the matching
  filled glyph. The glyph switch, selected material, and foreground contrast
  together define the complete toggle state.
- The Close capsule uses the video-close capsule treatment inside the video
  frame. It is part of player UI for visibility and cursor rules, but remains
  a close command rather than a bottom-player control. The speed capsule uses
  fixed width and tabular text so preset changes do not shift neighboring
  controls.
- Transport icon buttons are a larger bottom-player subtype used only for the
  five centered transport controls. They are intentionally distinct from the
  smaller right-side operation icon buttons.
- Pop-up controls use rounded-rectangle menu containers rather than circular
  or capsule button forms. The speed menu is an app-style popover above the
  bottom player; it lists fixed speed presets, keeps row height compact, and
  marks the current preset with a check indicator.
- The HTML review fork may include prototype-only controls outside the App
  window, such as a theme mode switcher and a disable-all control-state
  switcher. These controls exist only to inspect visual states in the HTML
  prototype and are not part of the native App layout.
- Prototype interactions include historical group disclosure and global group
  collapse controls for visual comparison only; those two interactions are
  superseded for Search, Shiori, and Context. Subtitle overlay toggling,
  side-panel visibility toggling, Shiori stateful command feedback, transport
  feedback, playback close, fullscreen feedback, and speed-menu selection
  remain useful prototype references.

Current component classification:

| Element | Component class |
| --- | --- |
| Main workbench background | Liquid Glass work surface |
| Prototype theme mode switcher | Prototype-only test capsule button |
| Prototype disable-all switcher | Prototype-only test capsule button |
| Topbar Library button | Circular icon toggle button |
| Topbar Shiori button | Circular icon toggle button |
| Topbar Search input | Search field capsule |
| Topbar Search clear action | Embedded circular icon button |
| Search results summary row | Status summary row |
| Search / Shiori / Context results | Native virtual table |
| Search / Context row | Individual primary Cue table row |
| Shiori row | Individual saved-Cue table row |
| Legacy `Collapse All`, result group, and result card | Superseded prototype-only components |
| Search match highlight | Inline text highlight |
| Expanded playback frame | Video stage surface |
| Subtitle overlay | Subtitle overlay |
| Playback side panel surface | Side panel surface |
| `Search Results` / `Subtitles` switcher | Segmented control |
| Side panel count and summary | Sidebar summary |
| Side panel scroll area | Sidebar list container |
| Side panel result or subtitle row | Sidebar row |
| Selected side panel row | Selected sidebar row |
| Bottom player container | Bottom player surface |
| Volume button | Circular icon button with volume popover |
| Volume slider panel | Volume popover |
| Progress scrubber | Playback progress slider |
| Playback time labels | Time labels |
| Previous, skip, play, and next controls | Transport icon buttons |
| Primary play/pause control | Primary transport icon button |
| Subtitle visibility control | Circular icon toggle button |
| Side panel visibility control | Circular icon toggle button |
| Fullscreen control | Circular icon button |
| Video Close control | Video close capsule command |
| Playback speed control | Fixed-width value capsule button |
| Playback speed menu | Rounded-rectangle popup menu |
| Playback speed option | Popup menu item |

Current prototype implementation class anchors:

| Component concept | Prototype class anchor |
| --- | --- |
| Capsule button | `ui-capsule` |
| Prototype-only test control | `ui-prototype-control` |
| Prototype-only test capsule button | `ui-capsule--test` |
| Capsule command button | `ui-capsule--command` |
| Video close capsule command | `ui-capsule--video-close` |
| Fixed-width value capsule | `ui-capsule--value` |
| Search field capsule | `ui-input-capsule` |
| Circular icon button | `ui-icon-button` |
| Circular icon toggle button | `ui-icon-button--toggle` |
| Topbar circular icon button | `ui-icon-button--topbar` |
| Embedded circular icon button | `ui-icon-button--embedded` |
| Transport icon button | `ui-icon-button--transport` |
| Primary transport icon button | `ui-icon-button--transport-primary` |
| Segmented control | `ui-segmented-control` |
| Segmented control option | `ui-segmented-control__option` |
| Result card | `ui-selectable-card` |
| Sidebar row | `ui-selectable-row` |
| Rounded-rectangle popup menu | `ui-popup-menu` |
| Popup menu item | `ui-popup-menu__item` |
| Playback progress slider | `ui-slider--progress` |
| Volume slider | `ui-slider--volume` |
| Selected state mirror | `ui-is-selected` |
| Active state mirror | `ui-is-active` |
| On/off state mirror | `ui-is-on` |

Known HTML/App difference categories for this baseline:

- Native macOS window chrome, traffic-light placement, full-screen transitions,
  system materials, accessibility focus behavior, and font rendering may differ
  from the HTML prototype while preserving the accepted visual hierarchy.
- The HTML uses mock Search data, mock subtitle data, and simulated playback.
  The App must connect these surfaces to real indexed subtitle data, media
  playback, file access, and persisted Shiori state.
- Prototype-only test controls, including theme switching and disable-all state
  switching, may sit outside the prototype window. They are review fixtures and
  must not be implemented as App controls in that location.
- Native implementation may use AppKit or SwiftUI controls, virtualization,
  lazy loading, and platform-specific rendering as long as visible layout,
  state, wording, and interaction intent remain aligned with the accepted
  prototype.

## 2. Main Window

The main window should be a persistent work surface.

Current structure:

```text
Native titlebar
Topbar Library/Shiori icons and Search field
Single content area
Bottom playback bar
```

The main window should support:

- Resizing.
- Reasonable minimum size.
- Restoring previous size if practical.
- Native toolbar or sidebar behavior where appropriate.

Current shell direction:

- Traffic lights and the centered workbench title belong to the titlebar.
- Library and Shiori mode controls are icon buttons immediately to the left of
  the topbar Search field.
- Search is selected by focusing or editing the topbar Search field.
- The visible Mode Rail, Shared Content Panel, right-side Search Panel, and
  sidebar-position setting are not part of the current workbench shell.
- The fixed-width Search field is centered together with the Library and
  Shiori icon cluster in the custom topbar.
- Traffic lights are shifted 12pt to the right and vertically centered within the custom titlebar. To achieve this without fighting AppKit's native layout engine during window resizing, the standard window buttons (`.closeButton`, `.miniaturizeButton`, `.zoomButton`) are reparented (extracted from their system container and placed into a custom transparent `NSView` proxy). This preserves native hover effects and accurate hit testing.
- The native `NSWindow` title visibility is hidden in windowed mode but temporarily restored during full-screen transitions, ensuring the system drop-down title bar is fully functional.
- The `NSWindow` title should use the main workbench identity, `CueSeeker`, for
  correct contextual labeling in the full-screen drop-down title bar.
- To prevent UI artifacts when exiting full-screen mode, the native title visibility is hidden in the `windowWillExitFullScreen` delegate callback before the transition animation begins.
- The titlebar should share the main content background.
- The titlebar should not draw a divider between the titlebar and content.
- The titlebar should visually sit above the workbench panels.
- The window automatically maximizes to the screen's visible frame upon launch.
- The current titlebar and workbench panel implementation is an M1 iteration,
  not final polish.

## 3. Main-Window Navigation

The previous standalone `Search` sidebar item should be removed. The main
window's current top-level destination is the CueSeeker workbench itself.

Current workbench surfaces:

- Library.
- Search.
- Shiori.

These surfaces are not separate main-window destinations. In the current
topbar-driven direction, Search is entered through the topbar Search field, and
Library and Shiori are entered through the topbar controls. Any remaining
Mode Rail references in this document describe pre-migration surfaces that do
not yet have an accepted Liquid Glass prototype.

Settings should not be a main-window sidebar section. The formal Settings entry
belongs in the macOS app menu. It opens or focuses the same independent
Settings window whenever mirrored by another App control.

If top-level navigation returns later, it should remain visually quiet and
should not compete with Library, Search results, Shiori records, or playback.

## 4. Main Workspace Panel Model

The current accepted direction is the topbar-driven Liquid Glass workbench in
section 1.2. The older shared-panel model below is retained as pre-migration
context for Library and other surfaces that do not yet have a dedicated
accepted Liquid Glass prototype.

Pre-migration conceptual structure:

```text
Fixed Mode Rail
Shared Content Panel
Playback Area
```

The main window is the CueSeeker workbench. The old standalone `Search`
AppShell destination should not appear in the current single-workbench design.
Settings is app-level configuration and belongs in the macOS app menu and
independent Settings window, not in main-window navigation.

In the pre-migration panel model, the Fixed Mode Rail selects the Shared
Content Panel mode:

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
- Library can collapse or expand by clicking its selected navigation control.
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
  (expanded) over `160ms` with an ease curve when toggled. Search, Shiori, and
  Context no longer share this disclosure pattern because their current
  presentation is an ungrouped Cue table.
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

## 4.1 Cue-Centric Search, Shiori, And Context Table

This section is the current normative presentation for Search, Shiori, and
Search-hosted Context. It supersedes every grouped-card, subtitle-file group,
disclosure-rail, and `Collapse All` description elsewhere in this document for
those three surfaces. Library's own card and folder-disclosure design is not
affected.

The three surfaces share one native AppKit virtual table model:

- Every row represents one primary Cue. Pagination, result counts, sorting,
  selection identity, default actions, Shiori identity, and export identity are
  all Cue-based.
- Search and Context columns are Selection, Display Title, Cues, and Time.
- Shiori columns are Selection, Display Title, Cues, Tags, Time, and Date Added.
- Display Title uses the subtitle file's immediate parent folder plus its
  one-based Finder-like natural-sort rank among same-extension siblings, with a
  source-filename fallback. Stable row/source identity remains subtitle-path
  and primary-Cue based, never display-title based.
- Rows have no full-row hover or selected fill. Interactive cell content owns
  its local hover and pointer region; noninteractive row space can toggle the
  selection checkbox.
- The row height is content-driven. Its subtitle height is
  `16 + 24P + 20S` points, where `P` is the primary Cue's visual line count and
  `S` is the total visual line count of displayed additional Cues. Source line
  breaks and automatic wrapping both count. The complete text is always shown;
  there is no clipping, truncation, ellipsis, character cap, or line cap.
- Width-dependent reflow remeasures only visible rows plus overscan and
  preserves the primary Cue identity and the anchored primary Cue first line's
  screen-space position.
- Search pagination loads 100 individual Cues per page. It does not page,
  count, or expand subtitle-file groups.

Settings > Search places the native `Show Cue Group` switch immediately below
Search Scope. It defaults to Off and persists across launches:

- Off shows only the primary Cue.
- On adds every other Cue from that Cue Group above the primary Cue using the
  smaller, more muted secondary style and `20pt` line height.
- This setting is presentation-only. It must not rerun Search, rebuild Context,
  alter Shiori data, change result count, reorder rows, change selection, or
  retarget actions.
- When On, all displayed Cue text shares one hover, click, and context-menu
  region, but the primary Cue remains the only default action target.
- `Copy Cue Text` always copies only the exact primary Cue. `Copy Cue Group
  Text` appears only when the setting is On and copies the complete displayed
  group in stable source display order.

## 5. CueSeeker Workbench And Search Mode

The CueSeeker workbench is the primary screen. Current Search result
presentation is the Cue-centric native table in section 4.1; section 1.2 still
provides shell and playback visual context but not grouped result geometry.

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
- Search results use the individual-Cue native table in section 4.1 and do not
  expose subtitle-file grouping, disclosure, or `Collapse All`.
- Selecting a Search result opens the Search-launched playback page instead of
  keeping Search playback constrained to a side-panel workbench layout.

- The native window identity remains `CueSeeker`, but the visible custom
  topbar centers the Search field instead of rendering a `CueSeeker` title.
- The embedded Playback Area remains central.
- Search controls and the Cue table appear in the Shared Content Panel
  when Search mode is selected.
- The Shared Content Panel may be collapsed so the Playback Area can expand.
- Collapsing the Shared Content Panel must not pause playback or clear the
  selected result.
- The Playback Area is the primary review surface after a result is selected;
  Search is the functional navigation and result-selection surface.

Legacy M1 search presentation (superseded and non-normative for result layout):

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
- The global Search group action uses the fixed label `Collapse All`. Activating
  it collapses all visible result groups and does not change the control into
  an expand-all action.
- Search results are shown as a grouped list with rounded selection backgrounds.
- Search result scrolling loads additional matches lazily in 100-result pages.
- Expanding all result groups from the all-collapsed state reveals at most one
  global 100-result batch.
- When the experimental `Search Result Thumbnails` setting is enabled, Search
  result rows should show a left-side preview thumbnail generated from the
  midpoint between the cue group's start and end timestamps. The thumbnail
  format is a persistent-cache AVIF image at `160x90` source pixels.
  The thumbnail's visible row box must stay fixed before and after image load so
  row layout does not jump. The container size is designed to match the height of two subtitle lines.
- When the experimental thumbnail setting is disabled, Search result rows should
  use the plain text layout with no thumbnail slot or placeholder.
- While an enabled thumbnail is loading or generating, a skeleton or loading pattern
  must be displayed instead of a solid black or gray background.
- If enabled thumbnail generation fails, a clear but non-intrusive fallback state must be shown.
- Search results are grouped under flat subtitle-file headers.
- Selecting a search result opens or updates the central Playback Area without
  leaving the CueSeeker workbench.
- Search results use refined macOS-native typography and highlight query
  matches with a yellow background that remains readable on selected rows.
- Search result visual polish is still incomplete and subject to further iteration.

## 6. Legacy Search Result Group (Superseded, Non-Normative)

This section is retained only as historical context for the former grouped
Search design. It must not guide current Search, Shiori, or Context work; use
section 4.1 instead.

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

## 7. Legacy Grouped Search Result Row (Superseded, Non-Normative)

This section describes the row inside the former grouped-card presentation. It
is non-normative for the current Cue table in section 4.1.

Each result row should be compact and scannable.

Result row content:

- A fixed-size left thumbnail preview. The preview uses a generated AVIF frame
  from the matched cue group's midpoint. While the image is not available, the
  row should show a lightweight skeleton illustration rather than a black or
  gray empty block. If generation fails, it should display a clear fallback.
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

- In the current Liquid Glass target, Search, Library, and Shiori main-page
  cards do not retain selected-card visuals after activation. The playback side
  panel remains the place where the current playback row is visibly selected.
- Result-row subtitle text starts on the same left edge as the subtitle file
  name in the header.
- Rows do not use horizontal dividers. Row separation should come from
  internal padding, group headers, and readable text spacing.
- Internal wrapped subtitle lines, including SRT line breaks and ASS `\N`
  line breaks rendered inside a single cue line, should use 4pt line
  spacing so bilingual subtitle text does not appear cramped.
- Selection feedback for the current playback context belongs to the playback
  side panel. Workbench mode selection may still show navigation state, but
  Library episode cards, Search result cards, and Shiori cards should return to
  their ordinary card styling after activation.

## 8. Playback Area And Shared Content Panel

The CueSeeker workbench uses a player-first layout. In the current Liquid Glass
baseline, Search-launched playback uses the main content area, an optional right
playback side panel, and the active-playback bottom player.

The older Mode Rail and Shared Content Panel model in this section is retained
only for unmigrated Library, Shiori, and Settings surfaces until dedicated
accepted prototypes supersede it.

As future navigation or learning features arrive, the Playback Area remains the
central experience. New panel modes must be documented before implementation
instead of recreating a separate right-side panel by default.

Playback Area required content:

- Embedded video.
- A `Video Folder` button.
- A `Subtitle Folder` button.
- For Search-launched playback, previous and next result navigation plus a
  right side panel containing `Search Results` and `Subtitles` tabs.
- The bottom-player right-side control group includes subtitle visibility,
  playback speed, and fullscreen. Subtitle visibility is a standalone circular
  button rather than part of a multi-action capsule.

Search-launched playback result navigation:

- `Previous Result` and `Next Result` use the complete active Search result
  order, exactly matching the Search results page order.
- Result navigation is not scoped to the current video path or subtitle path.
- Current playback time is used to identify the current Search-result anchor
  before moving backward or forward in the complete result order.
- The `Search Results` side-panel tab displays the active Search result order
  and keeps the current result selected and scrolled into view when practical.
  It does not show `Collapse All`.
- The `Subtitles` side-panel tab displays the current playback subtitle file in
  timestamp order. It does not use keyword highlighting. The current playback
  subtitle row uses selected-state context only and is scrolled into view when
  practical.
- Hiding or restoring the playback side panel must not pause playback, clear
  the selected result, or resize the bottom-player controls.

The Playback Area should not show read-only `Start Time`, `Video Path`, or
`Subtitle Path` metadata labels and values under the video. The previous
metadata area should instead provide the two file-location buttons.

The `Video Folder` and `Subtitle Folder` buttons should visually match the
ordinary Settings action buttons. Each button should use a folder icon to the
left of the text label.

Search mode required content:

- Search input.
- Indexing status when relevant.
- Total matching Cue count.
- Individual-Cue native virtual table using section 4.1.
- Empty, loading, and error states.

Shiori mode required content:

- Shiori summary based on saved Cue count.
- Individual saved-Cue native virtual table using section 4.1.
- Empty and error states.

Context mode required content:

- The Search-hosted Context scope for the requested primary Cue.
- Individual-Cue native virtual table using the Search columns and section 4.1
  geometry.
- Complete Cue text and the same default action identity as Search.

Future Search mode actions may include hover buttons and contextual menus on
result rows. A result-level `Add to Queue` action is an accepted future
direction for building playback queues from Search.

Behavior:

- Selecting a result opens or updates the Playback Area.
- Selecting a result should preserve the Shared Content Panel when it is
  expanded in Search mode.
- Clicking the embedded video toggles play/pause.
- Clicking the playback operation controls should not toggle play/pause unless the play/pause control is targeted.
- The Playback Multi-Module Overlay has a fixed, non-collapsible left Sidebar
  ordered Current, optional Playlist, Search, Recent, Library, and Shiori.
  Unmodified Tab is the only keyboard module-cycle command; Sidebar items also
  accept pointer selection.
- The Overlay has no Cue hover state, Cue click action, or Cue action menu. Up,
  Down, wheel, and scrollbar navigation remain available for Cue reels.
- Current, Playlist, and Shiori use `S` to save the exact selected Primary Cue,
  `C` to copy it, and Enter to play it. Search keeps keyboard focus in its live
  query field and exposes only Enter as a Cue action. Space is consumed without
  action in every Overlay module.
- Overlay feedback renders above the Overlay. `S` and `C` keep it visible and
  playback paused; Enter synchronously destroys its temporary Session before
  playback opens or resumes.
- Current renders one exact Cue per virtual reel item. Its nominal content
  height is `52L`, where `L` includes source line breaks and automatic wrapping.
  Natural height is
  `max(nominal content height, visual-line stack height) + 24pt`; resolved
  height is the lesser of natural height and the reel viewport height. Visual
  lines use measured font-run typographic bounds and the internal-line-gap
  token rather than fixed Line Slots.
- A fitting selected Cue shows every line and centers its complete bounds on
  the fixed screen-space Focus Anchor. An oversized selected Cue aligns its top
  edge with the reel viewport top, begins at its first visual line, and clips
  only trailing content below the viewport while retaining its complete action
  value.
- Overlay opening starts a new temporary Session on Current and selects the
  physically bottommost Cue in the Cue Group that
  contains the captured playback timestamp, otherwise the nearest preceding
  Cue, otherwise the first Cue. Width reflow preserves that stable Cue identity
  and restores its accepted fitting-center or oversized-top placement.
- Playlist, Search, and Shiori reuse Current's virtual rendering, dynamic
  measurement, accepted placement, scrolling, and recycling while rendering
  Playback Cue Results. Their complete text collections remain resident in the
  shared Feature or Playlist source. Closing the Overlay clears Overlay-local
  selection, scroll, measurement, and unfinished presentation work; it does not
  clear the shared Search query or Feature collections.
- Playlist renders its one-based internal Sequence Number to the left of each
  Result. With `Show Cue Group` On, Playlist, Search, and Shiori add muted,
  smaller Additional Cues while the Primary Cue retains normal Cue styling.
  Every adjacent Visual Line inside one Result uses the same strict 5-pixel
  internal gap, including Additional-to-Primary boundaries. Only two separate
  Results use the 8-pixel Cue gap. Presentation never changes Result identity
  or action targets.
- Recent reuses the Watching Card layout. Library reuses Folder cards, its fixed
  Detail Header, and Episode cards. Playback Selected state reuses each card's
  existing Hover region and visual: full card for Recent/Folder and Cover only
  for Episode. It adds no Focus Ring, border, or independent selected fill.
- When a Library video cover is unavailable, every Library, Recent, and
  playback surface that uses the shared cover view should show the existing
  `16:9` Library Cover Placeholder background with a centered muted `film`
  symbol. The fallback must not use red error styling and must not remove Cue
  counts, playback progress, duration, or manual cover replacement actions.
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
- Transient playback feedback overlays appear above the video for play/pause,
  subtitle visibility, seek, volume, speed, and Overlay actions. The feedback
  layer remains above the Playback Multi-Module Overlay.
- The playback speed selector is an app-drawn menu that opens upward from the
  speed control.
- The speed control must display fractional presets without truncation and must
  keep a stable width when the selected preset changes.
- The speed control should show only the current speed value; it should not add
  a separate visible arrow affordance.
- The speed menu uses compact preset rows and marks the current preset with a
  check indicator.
- When the volume control is hovered, the volume slider and numeric percentage appear together without moving the playback controls vertically.
- The timeline hover and drag states must not move the playback controls vertically.

Pre-migration panel layout:

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

In the pre-migration panel model, the Mode Rail owns Library, Search, and
Shiori mode selection. This does not supersede the current Liquid Glass
prototype baseline for Search-launched playback.

Panel visibility and list lifetime:

- The workbench panel shells should remain stable when their visibility
  changes. A collapse action should change layout visibility or width, not
  discard the panel's large list state.
- Library rows are static indexed-resource presentation loaded from a persisted
  Library snapshot. They should remain cached until Library data or Library
  ordering inputs change. Session-only Library collapse state is a view state
  overlay and must not regenerate Library rows.
- Search rows are active query presentation. They should remain cached until
  the query, loaded Cue page, filter, or Search ordering inputs change. Width
  reflow and `Show Cue Group` must not rebuild the row identity snapshot.
- Shiori rows are saved-content presentation. They should remain cached until
  the saved-Cue record set, tag data, or Shiori ordering inputs change. Width
  reflow and `Show Cue Group` must not rebuild the row identity snapshot.
- Future panel modes such as Timeline, Queue, and Learning Session should keep
  their own presentation state separate from Library, Search, and Shiori rows.
- Switching panel modes should feel like changing tools in a stable panel, not
  like reopening the workbench. Library, Timeline, Shiori, Search, Queue, and
  Learning Session should preserve local scroll, collapse, selection, and draft
  state where practical.
- Search, Shiori, and Context use a native virtual table that lays out visible
  rows plus overscan rather than constructing the complete result set as
  SwiftUI row views.
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
- `Search`.
- `Appearance`.
- `Decode`.
- `Experimental Features`.

The `Library` category should allow local folder management.

Required `Library` elements:

- List of indexed folders.
- Add folder action.
- Global `Index Now` action next to the add-folder action. This action should
  reindex all selected folders.
- Per-folder remove action.
- Remove confirmation dialog explaining that local files will not be deleted.
- Indexing status.

The `Search` category exposes Search Scope and places a native macOS
`Show Cue Group` switch immediately below it. The switch defaults to Off,
persists across launches, and applies to Workbench Search, Shiori, and Context
and to Playback Playlist, Search, and Shiori. Changing it updates only Cue
presentation and visible-plus-overscan measurement; it must not rerun Search,
rebuild Context, alter Shiori data, change result count or identity, or retarget
any row action away from the Primary Cue.

The `Appearance` category should expose `Appearance Mode` as its first setting.
The control uses the same app-drawn segmented-control pattern as `Decode >
Decoder`, with `Light`, `Dark`, and `Auto` choices. `Auto` is the default and
follows the current macOS system appearance.

The `Decode` category should expose an app-drawn segmented control for
`hardware`, `software`, and `auto`, avoiding native menu services during the
normal Settings window lifecycle.

The `Experimental Features` category should contain unstable or provisional
features that may change or be removed. It should expose a `Search Result
Thumbnails` toggle. The toggle is off by default. When it is off, Search rows
must not reserve thumbnail space or trigger thumbnail cache reads, extraction,
or generation.

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
