# Functional Requirements

Status: Draft

## 1. Local Folder Management

The app must allow the user to add local subtitle folders.

Requirements:

- The user can choose a local folder through a native macOS folder picker.
- The app stores selected folder entries.
- The user can remove a selected folder.
- Removing a folder must remove the app's derived index data for that folder,
  without deleting local subtitle or video files.
- The app can refresh indexes for all selected folders.
- The app should avoid duplicate folder entries when possible.

## 2. Subtitle Scanning

The app must scan selected local folders for supported external subtitle files.

Requirements:

- Recursive folder scanning.
- Support `.srt` files.
- Support `.ass` files.
- Ignore unsupported subtitle and media-adjacent files.
- Avoid following symlink loops.
- Report indexing progress.
- Skip files that cannot be read.
- Preserve enough error information for debugging.

## 3. Subtitle Parsing

The app must parse supported external subtitle files into a normalized searchable
cue model.

Requirements:

- Parse start and end timecodes.
- Convert start and end timecodes to milliseconds.
- Preserve clean, searchable subtitle text content.
- Support multi-line subtitle text.
- Ignore malformed blocks or events without stopping the entire indexing run.
- Preserve enough source identity to map each searchable cue back to the source
  subtitle file and matched video file.

SRT parsing requirements:

- Parse subtitle sequence number when present.
- Treat each valid SRT block as one cue group with one cue line.

ASS parsing requirements:

- Parse `[Events]` `Dialogue` events according to the active `[Events]`
  `Format:` field mapping.
- Do not parse `Comment` events as searchable subtitles.
- Treat every `Dialogue` style as searchable unless a later product rule
  explicitly excludes it.
- Clean ASS text for search by removing override tags such as `{...}` and by
  normalizing ASS line breaks such as `\N`.
- Preserve each `Dialogue` event's start and end time after conversion to
  milliseconds.
- Group `Dialogue` events with the same subtitle file, exact start time, and
  exact end time into one cue group.
- Do not group near-equal ASS timestamps by tolerance in the first
  implementation.
- Keep all lines inside a cue group. Do not deduplicate same-looking text during
  indexing.
- Derive a stable display order for cue lines from ASS layout information when
  possible, including style alignment, margins, inline alignment overrides,
  explicit positions, and source event order.

## 4. Video Matching

The app must match subtitle files to local video files in the same directory.

Initial matching rule:

- Match by basename.
- Support common video extensions.
- Match at most one video for each subtitle.
- Try the complete subtitle basename first. When that basename contains an
  additional dot-separated suffix, try the basename with its final suffix
  removed as the fallback.
- Prefer `Movie.commentary.mp4` over `Movie.mp4` for
  `Movie.commentary.ass`; use `Movie.mp4` only when the complete-basename video
  is absent. `Movie.ass` matches only the `Movie` basename.

Initial video extensions:

- `.mp4`
- `.mkv`
- `.webm`
- `.avi`
- `.mov`

## 5. Indexing

The app must write parsed subtitle cue groups and cue lines to a local SQLite
database with FTS5 search support.

Requirements:

- Treat each stored cue line as the stable product-level Cue. A Cue Group is a
  derived indexing and optional-presentation container, not the identity used
  by Search, Shiori, Context, playback actions, copy, or export.
- Store subtitle metadata.
- Store video path.
- Store subtitle path.
- Store start and end timestamps.
- Store searchable text content for each cue group.
- Store and search each Cue's own normalized content so query terms, results,
  counts, ordering, pagination, and action identity remain Cue-scoped.
- Store the ordered cue lines that belong to each cue group.
- Support incremental indexing based on file metadata.
- Remove stale entries when source subtitle files no longer exist.
- Remove derived index rows when a selected folder is removed.
- Reconcile indexed content with the currently selected folders when the app
  starts.
- If no folders are selected, previously derived index rows should be cleared or
  ignored so they cannot appear in search results.

## 6. Search

The app must search indexed subtitle content.

Requirements:

- Search should respond quickly for typical personal libraries.
- Empty queries should not return results.
- Search should support English text.
- Search should support CJK text at least at the level needed by the existing Flutter implementation.
- Results should be ordered predictably.
- Results should be limited to avoid rendering excessive rows.
- Search should load results incrementally in pages of 100 Cues so broad queries can
  continue revealing matches while avoiding an unbounded first render. Pagination must strictly follow
  the number of Cues rather than grouping by subtitle files.
- The Search view should show the total matching Cue count for the current
  query near the search field.
- Search results must be scoped to the currently selected subtitle folders.
- Stale index rows outside the currently selected folders must not appear in
  Search.
- Search returns individual Cues. Two matching sibling Cues in one Cue Group
  produce two independently identified, counted, ordered, selectable rows.
- A Cue must satisfy query semantics by its own indexed text. Cue Group
  aggregate text may be used only for recall and must not create a match from
  terms split across different Cues.
- Cue Group content is an optional presentation projection controlled by Show
  Cue Group. It must not change Search count, row identity, ordering,
  selection, or any action target.
- The current native search behavior should preserve the practical legacy Flutter semantics:
  single Latin-token searches use prefix matching, multi-token Latin searches use
  ordered whole-token filtering after FTS recall, Han and Japanese kana content
  is segmented for FTS phrase matching, and invalid FTS syntax returns no
  results instead of crashing the app.
- Search ranking, tokenization, query syntax, and CJK behavior remain expected
  iteration areas. Future search-quality changes should update this section and
  the database search tests before the implementation is treated as stable.

## 7. Search Results

Search results must show enough information for the user to choose the correct match.

### Current Cue-Centric Table Contract

The native Search surface is a flat, virtualized table. Each row represents
one primary Cue and retains its subtitle-file grouping metadata only as data;
the older disclosure-group/card presentation described later in this section
is superseded and non-normative.

- Search and Context use Selection, `Display Title`, `Cues`, and `Time`
  columns. Shiori uses the same Cue geometry and adds `Tags` and `Date Added`.
- The primary Cue is the only playback, Context, Copy Cue Text, selection, and
  export identity. Time is the primary Cue's own start time.
- With Show Cue Group Off, Cues renders the complete primary Cue only. With it
  On, every additional Cue is rendered above the primary Cue in smaller,
  secondary text; all text shares one hover/click/context-menu region and no
  additional Cue becomes an independent action target.
- Row height is content-driven: minimum 40pt and
  `16 + 24P + 20S`, where `P` is primary visual lines and `S` is additional
  visual lines after source breaks and wrapping. Complete text is never
  truncated, clipped, ellipsized, or line-capped.
- Width changes and Show Cue Group changes may remeasure only visible plus
  overscan rows. They preserve row count, result count, sorting, selection,
  primary Cue identity, and the anchored primary Cue's screen position.
- Search pagination remains 100 Cues. Snapshot identity and query execution do
  not depend on presentation height or Show Cue Group.

### Legacy Grouped Result Presentation (Superseded)

The grouped-card container, subtitle-file headers, disclosure/collapse actions,
group-level paging, and former fixed row visuals below are historical only.
They must not be used to implement or review the current native Search,
Context, or Shiori tables. Display-title derivation, thumbnail feature gating,
query highlighting, playback, and Finder reveal remain current only through
the Current Supporting Search Rules restated after this legacy block.

Search results should be grouped by subtitle file. Each subtitle-file group
is a single flat container of matched cue-group rows; Search mode does not
aggregate groups by parent folder. The previous proposal to introduce a
parent-folder Show layer above subtitle files was rejected during
implementation review (see
`docs/proposals/2026-05-right-sidebar-show-episode-grouping.md`): the parent
folder is redundant header chrome in a search context, and aggregating a
season's worth of matches under one heading creates render and attention
problems that the existing flat layout already handles via the global
`Collapse All` control.

Each subtitle-file group should display:

- A friendly display title derived from the subtitle file's immediate parent
  folder name and its one-based natural-sort rank among same-extension sibling
  subtitle files when that title can be derived.
- The total matching cue-group count for that subtitle file as plain text
  appended after the display title, separated by two spaces, using
  `1 result` for a single match and `N results` otherwise.
- A collapsed or expanded state indicator on the left side of the group as a
  disclosure rail. The chevron rotates between `0°` (collapsed) and `90°`
  (expanded) over `160ms` with an ease curve when toggled. When the group is
  expanded, a vertical rail line extends below the chevron alongside the
  group's matched rows.

Friendly subtitle-file group title rules:

- The display title format is `Parent Folder Name - NN`.
- `Parent Folder Name` is the immediate parent folder's last path component.
- `NN` is the subtitle file's one-based rank among visible regular sibling
  subtitle files with the same final subtitle extension.
- The sequence number is zero-padded to at least two digits, expanding to the
  sibling count's digit width when needed.
- Sibling ordering should use macOS Finder-like localized standard
  comparison, so numeric filename runs sort by numeric value, such as
  `aa2.ass` before `aa11.ass`.
- Rank derivation is scoped to the immediate parent directory and final
  subtitle extension. `.srt` and `.ass` files are ranked independently.
- If the friendly display title cannot be derived, the group should fall back
  to the source subtitle filename.
- Search grouping identity must remain based on subtitle path, not the
  friendly display title.

The visible group header should not render a separate per-file count badge or
additional count component. The per-file total should remain part of the
header text. The search layer should still retain per-file total counts for
lazy-loading rules, future sorting behavior, and internal consistency checks.

Subtitle-file groups should be expanded by default, but only the first 100
matching cue-group rows globally should be visible after the initial search. Scrolling
to the bottom of the visible rows should reveal the next 100 cue-group rows
when more results exist.

Search result thumbnails are an experimental feature controlled by Settings.
When the feature is disabled, Search result rows must behave as plain text
results and must not request cached images, generate thumbnails, or start
thumbnail extraction processes. When the feature is enabled and a batch of 100
cue-group rows is loaded and displayed, their corresponding search result
thumbnails should be generated for the loaded rows.

Collapsing a group should only affect row visibility and must not affect
search result counts, search scope, or playback identity. Expanding a
collapsed subtitle-file group is an explicit lazy-loading trigger: the group
should show matching cue-group rows, but still strictly bound by the global lazy-loading
limit of 100 cue lines per batch, even if a single subtitle file has hundreds of matches.

The Search view should provide a single control that collapses or expands
all subtitle-file groups for the current query. Collapsing all groups should
hide all subtitle rows while keeping headers visible. Expanding all groups
is an explicit lazy-loading trigger that reveals at most one global
100-result batch, not 100 rows per subtitle file. This control must not
change total result counts or per-file match totals.

The collapse or expand-all control should use English labels, currently
`Collapse All Results` and `Expand All Results`, and its label should be
based on the last global collapse or expand action rather than on manual
per-header toggle state.

Result row content:

- Left-side thumbnail preview generated at the cue group's mid-point timestamp
  only when the experimental Search result thumbnail setting is enabled.
- Subtitle text as the primary content.
- Inline highlighting of query matches.
- Result rows do not render a cue start timestamp. Within a subtitle-file group
  rows are already ordered by ascending cue start time, so spatial order
  conveys time order without a dedicated column.

Result row color behavior:

- Selected Result rows use the macOS system accent color
  (`NSColor.controlAccentColor`, surfaced through `Color.accentColor` in
  SwiftUI). When the user changes their system accent color, the selected
  background reflects that color. A future settings option may expose a
  custom accent override; the first implementation does not include that.
- Selected row text is white. Unselected row text uses a slightly muted
  primary label color so rows remain readable without competing with the
  selected row.
- Selected row keyword highlights use the on-selected highlight token (see
  §UI Design for token values).

For grouped subtitle results:

- Display all cue lines in the matched cue group.
- Order cue lines by their derived display order so the result approximates the
  subtitle's on-video vertical arrangement.
- Do not hide or deduplicate cue lines at result-render time unless a later
  product rule explicitly defines that behavior.
- Do not impose a fixed product-level line count cap on displayed cue lines.

Clicking a Result row must open or update the central Playback Area and trigger
playback for the matching video at the subtitle start timestamp.

The Playback Area displays additional context:

- Embedded video playback.
- A `Video Folder` button that reveals the matched video file in Finder.
- A `Subtitle Folder` button that reveals the source subtitle file in Finder.

The Playback Area should not show separate read-only `Start Time`,
`Video Path`, or `Subtitle Path` metadata fields under the video. Source file
identity remains available through the Finder reveal buttons and internal search
result state.

The Search controls and Search results belong in Search mode inside the shared
left-side content panel. The shared content panel can collapse independently
from playback. Collapsing it must not pause playback, clear the selected
result, or change search result identity.
The main window's top-level identity should be `CueSeeker`, not a `Search`
workspace label. Search is a workbench panel mode, not a main-window sidebar
destination for the current single-workbench design.

### Current Supporting Search Rules

- `Display Title` uses the subtitle file's immediate parent folder plus its
  one-based Finder-like natural-sort rank among regular sibling files with the
  same final extension. The rank is zero-padded to at least two digits; if the
  title cannot be derived, use the source subtitle filename. Stable identity
  remains the subtitle path, never the display title.
- Search Result Thumbnails remains an experimental Settings feature. When Off,
  Search must not render thumbnail placeholders, read the thumbnail cache,
  create requests, generate thumbnails, or launch extraction. When On, only
  loaded Cue rows may request the existing primary-Cue midpoint preview.
- Search may highlight the query match within the primary Cue text. Highlight
  styling must remain readable without introducing the superseded full-row
  selected-card fill.
- Clicking the Cues interaction region opens or seeks playback at the primary
  Cue's own start time. Playback retains `Video Folder` and `Subtitle Folder`
  actions that reveal the matched files in Finder; it does not need duplicate
  read-only path fields.

## 8. Library And Timeline

Library and Timeline are not required for M1.

When implemented, Library should support:

- Browse playable videos from indexed folders.
- Use video identity as the primary row identity when a playable video can be
  resolved.
- Hydrate the Library list from persisted indexed video metadata before the
  first visible main-window render after app launch. Restarting the app must
  not show an empty or loading Library panel when indexed Library rows already
  exist locally.
- Group videos by the immediate parent folder only. Library should be flat and
  should not render nested folder trees in the first implementation.
- Sort folder groups and the videos inside each folder with the same Finder-like
  natural ordering used by Search display titles, so ordinary text sorts like
  `a-z` and numeric filename runs sort naturally.
- Display each folder as a two-line row: the folder display name on the first
  line and an episode-count subtitle on the second line, with a single
  disclosure chevron on the left that rotates between `0°` (collapsed) and
  `90°` (expanded) over `160ms` with an ease curve when toggled. This is a
  Library-only disclosure pattern; Search, Shiori, and Context use the
  ungrouped native Cue table.
- Read `N episodes` as the folder subtitle when no Library-launched playback is
  active for any video in this folder, and read `N episodes · Playing M` when
  Library-launched playback is active for a video in this folder, where `M` is
  that video's one-based natural-sort rank among playable sibling videos in the
  same folder.
- Library folder rows must not display a leading first-letter or first-character
  avatar block.
- Treat the entire folder row as a single click target that toggles folder
  expand or collapse. The chevron is a visual indicator, not the only hit
  region.
- Render an expanded folder as a numbered button grid where each button shows
  the video's one-based natural-sort rank among playable sibling videos in the
  same folder. Per-video file names, durations, and language tags are not shown
  in the grid.
- Use minimum-button-width auto-flow columns for the episode grid so the column
  count adapts to the user's current Shared Content Panel width.
- Indent the episode grid slightly relative to the folder row's left edge to
  express hierarchy. The indent should remain small.
- Use only three episode-button visual states: default, hover, and playing.
  The playing state highlights the currently playing video only when that
  playback was launched from Library.
- Avoid showing duplicate top-level rows for multiple subtitle files that map
  to the same playable video unless a later product rule defines a manual
  subtitle-selection workflow.
- Let the selected Library icon in the fixed Mode Rail collapse or expand the
  Shared Content Panel.
- Let the Shared Content Panel be resized horizontally. Its default width should
  equal its minimum width, and the first minimum width should be `420pt`,
  matching the previous Search Panel minimum width.
- Persist the user's Shared Content Panel width when it differs from the
  default.
- Keep Library folder collapse or expand state only for the current session.
  App startup and Library data refresh should show all folder groups collapsed.
- When a user expands a folder that contains the currently Library-launched
  playing video, automatically scroll that video's episode button into view as
  part of the expand transition. Auto-scroll must not fire on already-expanded
  folders or on data refresh.
- Open or update playback from a persisted Library resume position when the
  user clicks a video through Library, falling back to `0` when no history
  exists.
- Record playback history only for videos opened through Library. Opening or
  seeking playback through Search results must not read, write, or overwrite
  Library resume history.
- Drive the Library `Playing M` folder subtitle and the corresponding episode
  button highlight only from playback sessions launched through Library.
  Playback launched through Search results, Shiori, or any other surface must
  not toggle these Library indicators.

When implemented, Timeline should support:

- Show the current video's subtitle cues in timestamp order.
- Jump playback to a selected subtitle cue.
- Keep Timeline navigation tied to the currently loaded video.
- Preserve source subtitle identity when multiple subtitle tracks or files are
  available.

Library and Timeline belong to content-navigation modes because they help the
user locate known content and precise timestamps.

## 9. Queue And Learning Session

Queue and Learning Session are not required for M1.

When implemented, Queue should support:

- Add items from Search results.
- Add items from Library videos.
- Add items from Timeline subtitle cues.
- Add items from Shiori.
- Preserve enough identity to open the correct video and timestamp later.
- Display queued items in a reviewable order.
- Remove or reorder queued items when that workflow is accepted.

Search result rows may later expose hover actions or context menus, including
an `Add to Queue` action.

When implemented, Learning Session should support configurable playback over
selected or queued items.

Future Learning Session options may include:

- Context size around the selected timestamp.
- Number of nearby subtitle cues to include.
- Repeat count.
- Random order.
- Loop behavior.
- Whether to play only cue windows or broader surrounding context.

Detailed Learning Session behavior must be documented before implementation.

Queue and Learning Session placement must be documented before implementation.
They should not be assumed to require a separate right-side panel in the current
workbench model.

## 10. Local Playback

The app must support local video playback from a search result.

Requirements:

- Open the matched local video file.
- Seek to the subtitle start timestamp.
- For Search, Shiori, and Context playback actions, seek to the primary Cue's
  own start timestamp. Showing additional Cue Group context must not change
  that target. For ASS sources, prepare source rendering asynchronously.
- Render video inside the native app window.
- Render source ASS subtitles through the accepted source-faithful rendering
  pipeline, with ASS Lite available only as an interim fallback.
- Keep video playback responsive when ASS parsing or rendering is slow,
  unsupported, or fails.
- Allow play and pause.
- Toggle play/pause by clicking the video surface.
- Keep clicks in the playback operation controls from falling through to video-surface play or pause.
- Provide an explicit playback close command in the video surface. Close stops
  the current playback session, exits playback fullscreen if active, clears
  playback selection highlights across Search, Library, Shiori, and playback
  side-panel rows, and returns to the workbench with no active playback UI.
- Closing playback must not clear Search results, database search caches,
  Library rows, Shiori records, Library disclosure state, Cue-table
  presentation, or unrelated workbench state.
- Prefer seek over reload when the current video is already open.
- Continue playback when the Shared Content Panel is collapsed.
- Pause playback when the user switches from Search to another top-level section.
- Preserve the current selected result when the Shared Content Panel is
  collapsed.
- Reopening the Shared Content Panel should not automatically change playback
  state.
- Provide video-level fullscreen that presents a video-only experience using
  AppKit native fullscreen behavior without exposing the normal app shell as the
  fullscreen surface.
- In expanded playback, the right playback side panel occupies the full height
  of the workbench's right column. The video surface and bottom player live in
  the left column and are squeezed by the side panel instead of being covered by
  it.
- The bottom player is visible only while an active playback session exists.
  Non-video pages with no active playback must not render the bottom player.
- The bottom player uses a fixed narrower maximum width and stays centered
  within the current video column. Detailed responsive scaling rules are
  deferred.
- Provide a standalone circular subtitle visibility toggle in the bottom player.
- Provide playback speed control with preset choices from `0.5x` through `2.0x`.
- Provide normal-playback keyboard shortcuts for subtitle visibility,
  fullscreen, play or pause, Search-result navigation, relative seek, volume,
  and speed adjustment.
- Provide cue-scoped Shiori, copy, and continuous-play keyboard actions only
  while the Playback Multi-Module Overlay is visible. Current, Playlist, and
  Shiori use `S`, `C`, and Enter; Playback Search reserves letter keys for
  input and exposes only Enter as its Cue action.
- Limit keyboard speed adjustment to the same `0.5x` through `2.0x` range as the playback controls.
- Adjust volume keyboard shortcuts in `5%` steps.
- Provide transient visual feedback for shortcut and playback-control actions.
- Persist continuous playback preferences across app restarts. This includes
  volume, last nonzero volume used for mute restore, subtitle visibility, and
  playback speed.
- ASS playback rendering should preserve timed source ASS events, including
  visual effects and vector drawing events. Search results should still expose
  readable dialogue or lyric text rather than raw effect commands.

Persistence rule:

- Non-one-shot user preferences that affect future playback or app behavior
  must be persisted by default. One-shot commands such as copying a focused cue
  to the clipboard are not themselves persisted, while durable user-authored
  data created by a command, such as Shiori records, must remain persisted.
- Muting volume should preserve the previous nonzero volume so unmuting restores
  the user's last listening level rather than jumping to a generic default.

Playback Multi-Module Overlay cue action requirements:

- Current, Playlist, and Shiori `S`, `C`, and Enter actions target the exact
  selected Primary Cue, never the current playback timestamp. Search accepts
  Enter against its selected Primary Cue while `S` and `C` remain query input.
- `S` saves that cue idempotently. It shows `Shiori Saved` after a new write or
  `Shiori Already Saved` when the durable record already exists.
- `C` copies the exact Primary Cue's complete text, preserving its source line
  order and line breaks without copying the surrounding Cue Group, and shows
  `Subtitle Copied`.
- `X` in Current, Playlist, and Shiori copies the Primary Cue as the plain
  Markdown string `[Cue text](cueseeker://cue?id={CueID})`. Its label trims each
  nonempty source line, joins the lines with one space, backslash-escapes `\\`,
  `[`, `]`, `<`, `>`, `*`, `_`, backtick, `~`, `&`, and `|`, and falls back to
  `Cue #{CueID}` when no visible label remains. The action shows
  `Subtitle(markdown format) Copied`. It publishes no adaptive HTML or RTF
  clipboard representation. Playback Search reserves `X` for query input.
- `S` and `C` keep the Overlay visible, keep playback paused, and preserve Cue
  selection and reel position.
- Enter synchronously destroys the Overlay Session, seeks to the selected
  Primary Cue start, begins continuous playback, and shows `Play`.
- Space is consumed without an action while the Overlay is visible.
- Playback Search updates after the latest query edit's `100ms` debounce,
  selects its first Result after each update, and does not require Enter to
  submit. It hosts the shared Workbench Search query/results with a temporary
  empty Filter context; Enter plays only an already settled selected Result.
- Playlist follows its existing origin snapshot and displays the Playlist's
  one-based Sequence Number. `Show Cue Group` adds presentation-only context to
  Playlist, Playback Search, and Playback Shiori without changing count,
  ordering, identity, selection target, or Primary Cue actions.
- Recent and Library reuse their established card layouts and directional
  selection and omit the Workbench-only `Context` menu item. Selected state
  reuses the existing Hover visual without a Focus Ring. Recent media actions
  and Library Episode media actions destroy the Overlay Session before opening
  playback. Library Folder actions enter Detail within the same Session, and
  Back restores the prior Folder state.
- Playback Page initialization hides the Pointer. Only physical Pointer Move
  reveals it; Wheel does not. Any key-down hides it. Media-card Hover can
  update Selected only while Pointer is visible.
- The Playback Page retains one Return Context across Overlay Sessions. A
  successful Search, Shiori, Recent, or Library Detail playback replaces it;
  closing Playback restores that Workbench target and destroys the context.
- Cue hover and click have no cue-specific visual or command behavior. Up,
  Down, wheel, and scrollbar navigation remain available.
- If an action key is accepted while cue motion is settling, execute it once
  against the final settled cue.
- Playlist Cue playback exposes related `Auto Stop After a Cue Finishes` and
  `Auto Switch to Next Cues in Playlist` preferences. The first determines
  whether playback pauses on the Cue's final valid picture; the second schedules
  the next Playlist item after the always-editable `Auto Switch Gap` only while
  the first is on. Only on/on, on/off, and off/off are valid. Turning Auto Stop
  off forces Auto Switch off and disables its toggle. A Cue paused by Auto Stop
  keeps its current subtitle visible whether Auto Switch is off or waiting in
  the Gap. Pressing Space after Auto Stop continues from the pause position
  instead of replaying the Cue.
  Search, Shiori, and CueID direct playback use this Playlist behavior; CueID
  direct playback has one item and restores Workbench Search when Playback
  closes.
- Current reel items represent one Cue. Their nominal content height is `52L`,
  where `L` is the complete visual-line count after source breaks and wrapping.
  Natural height is
  `max(nominal content height, visual-line stack height) + 24pt`.
- Playlist, Search, and Shiori share the Current virtual-reel rendering,
  placement, scrolling, measurement, and recycling infrastructure while their
  complete text collections remain resident in the shared Feature or Playlist
  source.
- A fitting Cue displays every line and keeps its complete center at the fixed
  Focus Anchor. An oversized Cue aligns its top edge with the reel viewport
  top, starts from its first visual line, and clips only trailing content.
- Width-dependent remeasurement must preserve stable Cue identity and restore
  the selected Cue to its accepted fitting-center or oversized-top placement.

The playback engine is selected in `docs/decisions/ADR-0007-native-only-playback-backend.md`.

## 11. Settings

The app must provide a Settings surface for local app configuration.

Settings entry requirements:

- Settings opens from `CueSeeker > Settings...` in the macOS app menu.
- Settings is an independent window, not a main-window sidebar section.
- Opening, focusing, or closing Settings must not pause playback, switch the
  main workspace away from the CueSeeker workbench, collapse the Shared Content
  Panel, or clear the selected Search result.

Current Settings categories:

- `Library`.
- `Appearance`.
- `Search`.
- `Decode`.
- `Layout`.
- `Experimental Features`.

`Library` settings requirements:

- Manage indexed subtitle folders.
- Add a local subtitle folder.
- Trigger reindexing for selected folders through an `Index Now` action.
- Remove a selected folder through a confirmation dialog.
- View indexing status.

`Appearance` settings requirements:

- Choose a persisted app appearance mode from `light`, `dark`, and `auto`.
- Default to `auto`, matching the current macOS system appearance.
- Present the appearance mode as the first setting in the `Appearance`
  category.
- Use the same app-drawn segmented-control pattern as the `Decode` category's
  `Decoder` control.

`Search` settings requirements:

- Present `Primary Search Language` in the `Search` category.
- Provide a persisted `Search Scope` picker with `All`, `Only Finished`, and
  `Watching + Finished` options.
- Default `Search Scope` to `All`.
- Apply `Search Scope` only to regular Search results in the Search tab.
- Do not apply `Search Scope` to Shiori search or Cue Context search.
- Present a persisted native `Show Cue Group` switch immediately below
  `Search Scope` and default it to Off.
- Apply `Show Cue Group` to Workbench Search, Shiori, and Context and to
  Playback Playlist, Search, and Shiori presentation only. Changing it may
  remeasure visible rows plus overscan and restore the anchored Primary Cue,
  but must not rerun Search, rebuild Context scope, mutate Shiori data, change
  result counts or identity, or refresh hidden or playback-covered tables.
- Provide a persisted `Prefill with Focused Cue` switch and default it to Off.
  When enabled, opening Command Panel from Playback Overlay Current or Cue
  Playlist fills its root Search field with the focused Primary Cue, normalizes
  line breaks to spaces, focuses the field, and places the insertion point at
  the end without starting Search. It does not apply to Collage or other
  Playback Overlay modules.

`Decode` settings requirements:

- Choose a persisted playback decode mode from `hardware`, `software`, and
  `auto`.

`Layout` settings requirements:

- Choose the persisted Shared Content Panel side.

`Experimental Features` settings requirements:

- Include a persisted `Search Result Thumbnails` toggle.
- The toggle must be disabled by default.
- When disabled, Search must not display thumbnail placeholders, read thumbnail
  cache entries, create thumbnail requests, or start thumbnail generation.
- When enabled, Search may use the current experimental thumbnail preview
  behavior.

Future settings may include playback, database, logging, and privacy options.

## 12. Shiori

Shiori is CueSeeker's saved-subtitle workflow.

The app supports:

- Save the current subtitle cue as a Shiori.
- Save a video or broader saved item only after that Shiori type is
  documented.
- Remove a Shiori record.
- View saved Shiori subtitle cues.
- Jump from a Shiori row to video playback.
- Preserve Shiori identity across reindexing when possible.

Initial Shiori save behavior:

- The normal playback bottom bar has no Shiori command button, and normal
  playback has no current-timestamp Shiori save shortcut.
- While Current, Playlist, or Shiori is active in the Playback Multi-Module
  Overlay, `S` saves the exact selected Primary Cue.
- Shiori shortcut handling must preserve native text input behavior and must not
  intercept editable text fields or modified shortcuts such as `Command-S`.
- The save command uses the stable individual-Cue identity captured by the
  active Overlay Session. Cue Group projection is not part of the saved
  identity or payload.
- If the resolved cue is not already saved, the app should persist it and show a
  playback feedback overlay with the Shiori icon and `Shiori Saved`.
- If the resolved cue is already saved, `S` must not remove or duplicate it and
  should show a playback feedback overlay with the Shiori icon and
  `Shiori Already Saved`.
- Shiori feedback must remain visible above the Playback Multi-Module Overlay
  while the Overlay stays open.
- Shiori deletion must be available only from the Shiori table removal action.
- When playback is opened from the Shiori table, previous and next Shiori
  navigation follows the table row order that was active at open time, including
  the current search or filter result scope, instead of falling back to all saved
  Shiori records.

Initial Shiori panel behavior:

- Shiori is a Shared Content Panel mode selected from the fixed Mode Rail.
- The Shiori mode uses a saved-content icon and should be named `Shiori` in
  user-facing English text.
- Each Shiori record identifies one individual Cue, and each tag is associated
  with that Cue rather than its Cue Group.
- Legacy bilingual Shiori records migrate to the Japanese Cue. When multiple
  Japanese candidates exist, retain the physically bottommost one; only when
  language cannot identify a Japanese candidate may migration fall back to the
  physically bottommost Cue overall.
- Shiori uses the shared native virtual table, not subtitle-file grouped cards.
  Its Cue row geometry and Show Cue Group presentation match Search and
  Context; save, delete, filter, playback, Context, copy, and export retain the
  stable primary Cue identity.

## 13. Cue Export and Copy

CueSeeker export and copy workflows operate on one or more explicitly selected
individual Cues. Show Cue Group is presentation-only and must never add its
additional Cues to an export or copy target.

Initial Anki export behavior:

- Each selected Cue becomes one Anki card, and each card uses only that Cue's
  exact text and own start/end timestamps.
- The export action opens a macOS save panel for an `.apkg` destination. After
  confirmation, export completes without requiring progress UI, success UI, or
  automatic Finder reveal.
- The generated deck name is derived from the selected Cue source context.
- The initial note type contains only `Audio`, `Image`, and `Text`; video clips
  and additional metadata fields remain out of scope.
- Each card front contains the audio clip and midpoint screenshot. Its back
  contains the exact selected Cue text without language labels.

Screenshot, Collage, Context, and copy behavior:

- Screenshot exports render the selected Cue or Cues using each Cue's own
  timing. The rendering object itself is unchanged by this requirement.
- Collage exports use the selected Cues in stable selection order. Every Cue in
  one Collage request must belong to the same subtitle file; no separate
  same-subtitle-file/different-video branch is required by the data model. The
  rendering object itself is unchanged by this requirement.
- `Copy Cue Text` copies exactly one primary Cue's complete text.
- When Show Cue Group is On, `Copy Cue Group Text` copies the complete displayed
  Cue Group without changing the primary Cue action identity.
- `Context` opens at the corresponding primary Cue, not at a Cue Group.

Shiori may also feed Queue or Learning Session workflows after those workflows
have documented placement.
