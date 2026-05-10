# CueSeeker Search Interface LLM Brief

Status: Draft  
Audience: LLMs, designers, product reviewers, and implementation agents  
Scope: Current native macOS Search workspace, not playground experiments

## 1. Purpose

This document describes CueSeeker's Search interface in high detail so an LLM
can reason about layout, behavior, visual hierarchy, and future UI/UX redesigns
without needing to infer everything from source code.

CueSeeker is a native macOS subtitle search and playback tool. The Search
screen is the primary workspace. Its job is to let the user type text, scan
grouped subtitle results, select a cue, and immediately preview the matching
video at the result timestamp.

The Search interface should feel like a focused desktop utility:

- Fast and local.
- Dense but readable.
- Native macOS first.
- Search-result centric.
- Playback is contextual, not a separate destination page.

Avoid treating this surface like a marketing website, landing page, content
feed, or media library home screen.

## 2. High-Level App Shell Context

The Search screen lives inside the main CueSeeker window.

The app shell has three persistent regions:

1. Native/custom titlebar.
2. Optional left sidebar.
3. Main workspace.

When the selected sidebar section is `Search`, the main workspace renders
`SearchView`.

The shell currently uses a quiet light macOS palette:

- Window background: light warm gray.
- Sidebar background: slightly different quiet gray.
- Titlebar background: slightly darker gray.
- Dividers: thin gray 1 px lines.
- Selected sidebar item: solid accent color with white text.

The Search screen should respect the existing titlebar and sidebar model unless
a redesign explicitly proposes a broader app-shell change.

## 3. Search Workspace Structure

The Search workspace is a horizontal split view:

```text
Search Workspace
├── Search Results Pane
│   ├── Search Header
│   │   ├── Search Field
│   │   └── Result Summary Row
│   ├── Empty / Loading / Error / No Results State
│   └── Grouped Results List
├── Inspector Resize Divider
└── Playback Inspector
    ├── Empty Selection State
    └── Selected Result Preview
        ├── Video Preview
        ├── Playback Error Message
        └── File Location Buttons
```

The split is controlled by `SearchView`.

The Search Results Pane is always present. The Playback Inspector is optional
and appears on the right when `appState.isPlaybackInspectorVisible == true`.

The right inspector uses a move-from-trailing plus opacity transition. The
animation duration is short, about `0.18s`, so it should feel responsive and not
ceremonial.

## 4. Window and Size Constraints

Current shell constraints:

- Minimum window width: `1040`.
- Minimum window height: `560`.
- Titlebar height: `45`.
- Sidebar width: `154`.

Search layout constraints:

- Search pane minimum width: `480`.
- Playback Inspector minimum width: `380`.
- Default Playback Inspector width: `520`, persisted in user defaults.
- Inspector width is clamped so the Search pane never shrinks below its minimum.

Design implications:

- The Search result list must remain useful at the minimum window width.
- The Playback Inspector cannot assume a very wide right panel.
- Long subtitle text must wrap predictably.
- Hit rows no longer render a cue start timestamp. Time order inside an
  Episode is conveyed by row order alone.

## 5. Search Results Pane

The Search Results Pane is the left/main content region of the Search workspace.

It uses a vertical stack:

1. Search Header.
2. One of several state views, or the results list.
3. Spacer below content.

The pane starts below the titlebar through the app shell. Internally it has a
top padding of `16`.

The result pane should be visually dominant because it is the primary task
surface. The inspector should support the selected result but not overpower the
search list.

## 6. Search Header

The Search Header contains:

1. Search Field.
2. Result Summary Row, shown only when the current query is non-empty and the
   search has enough state to show a summary.

Current header spacing:

- Search Header vertical spacing: `6`.
- Search Field leading padding: `12`.
- Search Field trailing padding: `28`.
- The extra trailing padding accounts for the ScrollView scrollbar width.

### 6.1 Search Field

The Search Field is a custom SwiftUI wrapper around an AppKit `NSTextView`.

Visual structure:

```text
Rounded Search Field, 36 pt high
├── Leading magnifying glass icon
├── Single-line text input
└── Inline clear button, visible only when text is non-empty
```

Current visual details:

- Height: `36`.
- Corner radius: `8`.
- Horizontal padding: `12`.
- Background: `Color(nsColor: .textBackgroundColor)`.
- Leading icon: SF Symbol `magnifyingglass`, 14 pt, medium weight, secondary
  foreground.
- Text size: 16 pt.
- Placeholder: `Search subtitles`.
- Focus outline: rounded rectangle stroke using separator color at about 80%
  opacity, line width `4`.
- Clear button: SF Symbol `xmark.circle.fill`, secondary foreground, plain
  button style.

Behavior:

- The input is single-line.
- Pressing Return does not insert a newline.
- Typing updates `appState.searchQuery`.
- Query changes start a debounced search.
- Debounce duration: `250 ms`.
- Empty query returns search state to idle and clears result loading state.
- The search field tracks focus through `appState.isSearchFocused`.

Design note:

The field intentionally uses a gray focus outline rather than a strong accent
ring. This preserves a quiet macOS utility feel.

### 6.2 Result Summary Row

The summary row appears below the search field when `searchResultSummaryText`
exists.

It contains:

- Total result count, e.g. `Found 42 results`.
- Rendered row count, e.g. `Rendered 100 results`.
- Spacer.
- Collapse / expand all button, shown only when search result groups exist.

Typography:

- Detail text size: `12`.
- Total result count: secondary foreground.
- Rendered count: tertiary foreground.
- Button label: secondary foreground.

Behavior:

- The collapse / expand all button clears Search focus.
- The button toggles all current result groups.
- Its label is controlled by global action state:
  - `Collapse All Results`
  - `Expand All Results`

Important behavioral constraint:

The global collapse/expand label tracks only global control state. Manually
collapsing or expanding one group should not rewrite the global label.

## 7. Search States

The Search pane renders exactly one primary content state below the header.

### 7.1 Empty Query

Shown when the trimmed query is empty.

Content:

- Title: `No Search Query`
- Icon: `text.magnifyingglass`
- Message: `Add subtitle folders in Settings, then search indexed subtitle text.`

Purpose:

This is the resting state of Search. It should direct the user toward Settings
only if they have not indexed anything, but it should not become a large
onboarding page.

### 7.2 Searching With No Current Results

Shown when `searchStatus == .searching` and there are no current results.

Content:

- Title: `Searching`
- Icon: `magnifyingglass`
- Message: `Looking through indexed subtitle text.`
- ProgressView overlaid and vertically offset.

Purpose:

Communicates active work for the first page of results. Search is local and
should feel fast; avoid heavy full-page loading treatments.

### 7.3 Search Failed With No Current Results

Shown when `searchStatus == .failed(message)` and there are no current results.

Content:

- Title: `Search Failed`
- Icon: `exclamationmark.triangle`
- Message: error message from state.

Purpose:

Make failure understandable without leaving the user in a blank list.

### 7.4 No Results

Shown when the query is non-empty, search is complete or otherwise not showing
results, and `searchResults` is empty.

Content:

- Title: `No Results`
- Icon: `tray`
- Message: `No indexed subtitle entries matched this query.`

Future UX opportunity:

This state could echo the query and suggest alternate terms, but the current
implementation keeps it minimal.

### 7.5 Populated Results

Shown when `searchResults` is non-empty.

The populated state renders a scrollable grouped list.

### 7.6 Appending / Lazy Loading

When a search is in progress and existing results are already visible, a small
ProgressView appears at the bottom of the LazyVStack.

This is used for incremental pagination, not initial loading.

## 8. Results List

The results list is a vertical `ScrollView` containing a `LazyVStack`.

Current list padding:

- Top: `4`.
- Bottom: `8`.

Each result belongs to an Episode (subtitle file) inside a Show (parent
folder). The list renders Show rows at the top level; each expanded Show
contains Episode headers and Hit rows. Show rendering is delegated to the
view module that owns the right-sidebar Show / Episode / Hit hierarchy.

The list supports lazy loading:

- Global page size: `100`.
- Prefetch threshold: `10`.
- When the user scrolls near the end of loaded results and more results exist,
  the app fetches another page.
- Search result lazy loading is based on matched cue groups, not Shows or
  Episodes.

## 9. Search Result Grouping

Results are grouped in three levels: Show → Episode → Hit.

A Show is the parent folder of one or more matched subtitle files. An
Episode is one subtitle file inside a Show, identified by its
contract-based alias rank. A Hit is one matched cue group inside an
Episode.

Each Show has:

- `showId` (the parent folder path)
- `title` (the parent folder's last path component)
- `totalCount` (total matched cue groups across the Show)
- ordered `episodes`
- `isCollapsed`

Each Episode has:

- `subtitlePath`
- `rank` (one-based, supplied by the contract-based alias rule)
- `label` (`Episode NN`, zero-padded)
- `totalCount` (per-Episode matched cue groups)
- loaded `results`

Show ordering uses Finder-like localized standard comparison on the Show
title, with the parent folder path as the secondary stable ordering key.
Episode ordering inside a Show follows the same Finder-like rank ordering
used to derive `NN`.

### 9.1 Show Row

The Show row is a full-width click target with a two-line left column.

Row content:

```text
Show Title                                [▾]
N results
```

Example:

```text
葬送的芙莉莲                              [▾]
67 results
```

Visual details:

- Show title and count occupy the left column. The title uses the same
  weight and tone as the Library folder title; the count uses the same
  secondary tone as the Library folder subtitle.
- A single disclosure chevron sits on the right.
- The chevron rotates between `0°` (collapsed) and `90°` (expanded) over
  `160ms` with an ease curve when toggled. The same chevron animation is
  shared with the Library folder row.
- The full row is clickable as a single target. Hover state shows a soft
  fill across the full row width.
- The Show row is never the selected row.

### 9.2 Episode Header

The Episode header is a non-interactive section heading inside an expanded
Show.

Header content:

```text
Episode 01                          4 results
```

Visual details:

- Label on the left: `Episode NN`, secondary tone, semibold.
- Per-Episode count on the right: tertiary tone, plain text.
- No chevron. No hover. No click target. The Show name is not repeated.

### 9.3 Show Collapse Behavior

Clicking the Show row toggles that Show.

When collapsing:

- The Show row remains visible.
- Loaded rows and Episode headers are hidden.
- Result counts do not change.
- Search does not re-run.
- Selection identity is preserved.

When expanding:

- If needed, the app reveals an initial page distributed across the Show's
  Episodes.
- Expanding an individual Show should reveal at most the first 100 matching
  rows across the Show.

## 10. Search Result Row

Each row represents one matched subtitle cue group.

The row is a full-width button whose label is `SearchResultRow`.

Layout:

```text
Rounded row background area
└── Subtitle cue lines (translation + original-language with inline
    keyword highlight)
```

Current row layout:

- The row no longer renders a cue start timestamp. Time order inside an
  Episode is conveyed by row order alone.
- The row's hover and selected backgrounds left-align with the enclosing
  Episode header text. The row's internal left padding then offsets the cue
  text further to the right, so the cue text reads as visually nested
  under the Episode header even on a selected row.
- Row text leading and trailing padding stay generous so long cue lines
  wrap predictably.
- Row selected/hover background corner radius: `8`.

Typography:

- Subtitle body text: 14 pt.
- Cue line spacing: `4`.
- Multiline text alignment: leading.
- Long text wraps and row height grows predictably.

Cue text source:

- Preferred display is `result.cueLines`.
- Each cue line is trimmed.
- Empty lines are removed.
- If no cue lines exist, fallback to `result.content`.

This matters for grouped SRT / ASS results:

- A matched result may contain multiple cue lines.
- The UI must not deduplicate visually similar lines.
- The row should display every derived cue line in order.

### 10.1 Row Selection

Selected row behavior:

- Background: `Color.accentColor` (the macOS system accent color, surfaced
  from `NSColor.controlAccentColor`). When the user changes the system
  accent color, the selected background reflects that color.
- Text becomes white.
- Query highlights invert to a translucent-white fill with bolder white
  text (see §10.2).

Unselected row behavior:

- Text color: primary at about 76% opacity.
- No horizontal divider lines.

Hover behavior:

- Hover background uses a soft gray fill consistent with native macOS list
  rows.
- Hover does not override selected state.

Selection action:

- Clears Search focus.
- Sets `selectedSearchResult`.
- Opens the Playback Inspector.
- Persists inspector visibility.
- Starts playback at the cue timestamp.

### 10.2 Query Highlighting

Query highlighting is applied per visible cue line.

Highlight term extraction:

- Splits the query by any scalar that is not alphabetic and not numeric.
- Removes empty terms.
- Deduplicates terms with a Set.

Matching:

- Case-insensitive.
- Diacritic-insensitive.

Highlight styling (light mode):

| Row state | Highlight background | Highlight foreground | Weight |
|---|---|---|---|
| Default | `#FFE066` | label primary | 500 |
| Hover | `#FFCB1F` | label primary | 500 |
| Selected | `rgba(255,255,255,0.30)` | white | 600 |

The highlight inverts on a selected row so the matched substring stays the
most prominent token in the line while staying inside the accent-color
envelope. Dark-mode equivalents are deferred.

## 11. Playback Inspector

The Playback Inspector is the right-side context panel for the selected search
result.

It is visible only when `appState.isPlaybackInspectorVisible == true`.

It has two modes:

1. No selection.
2. Selected result.

### 11.1 No Selection State

If there is no selected result, the inspector shows an EmptyStateView.

Content:

- Title: `No Selection`
- Icon: `play.rectangle`
- Message: `Select a subtitle result to preview its matching video.`

The empty state fills the inspector.

### 11.2 Selected Result State

If a result is selected, the inspector contains a ScrollView with a vertical
stack.

Content order:

1. PlaybackView.
2. Playback error message, only if playback failed.
3. File location buttons.

Spacing:

- Vertical stack spacing: `16`.
- Top padding: `16`.
- Horizontal padding: `20`.
- Bottom padding: `20`.

Inspector background:

- `Color(nsColor: .controlBackgroundColor)`.

### 11.3 Video Preview

PlaybackView is rendered as a 16:9 preview.

Visual container:

- Aspect ratio: `16 / 9`, fit.
- Max width: infinity.
- Background: black.
- Clip shape: rounded rectangle, corner radius `8`.

Behavior:

- The embedded video surface toggles play/pause when clicked.
- Clicking the video clears Search focus.
- Playback controls appear when the video area is hovered.
- The subtitle overlay renders over the video.
- Feedback overlays appear for playback operations.

### 11.4 Playback Controls

Playback controls are part of `PlaybackView`, not directly part of SearchView,
but they are visible inside the inspector.

Available controls include:

- Play/pause.
- Timeline / seek.
- Volume.
- Current time / duration.
- Copy current subtitle.
- Subtitle visibility toggle.
- Playback speed.
- Fullscreen.

The playback operation zone should not let control clicks fall through to the
video-surface play/pause toggle.

### 11.5 Playback Error

If `appState.playbackStatus == .failed(message)`, the inspector shows:

- SF Symbol `exclamationmark.triangle`.
- Error text.
- 12 pt detail typography.
- Red foreground.

The error appears below the video and above file buttons.

### 11.6 File Location Buttons

The inspector shows two action buttons:

- `Video Folder`, SF Symbol `folder`.
- `Subtitle Folder`, SF Symbol `folder`.

Behavior:

- Clicking `Video Folder` clears Search focus and reveals the matched video file
  in Finder.
- Clicking `Subtitle Folder` clears Search focus and reveals the source subtitle
  file in Finder.

These buttons replaced earlier read-only metadata fields. A redesign should not
reintroduce passive full path labels as the primary inspector content unless
there is a clear diagnostic mode.

## 12. Inspector Resize Divider

When the Playback Inspector is visible, a resize divider appears at the trailing
edge of the Search Results Pane.

Structure:

- Hit width: `6`.
- Idle line width: `1`.
- Active line width: `3`.
- Idle opacity: black at `0.08`.
- Hover/drag opacity: black at `0.18`.
- Cursor: left-right resize.

Behavior:

- Hovering marks divider active.
- Mouse down clears Search focus.
- Dragging adjusts inspector width.
- Drag delta is inverted so dragging left increases inspector width.
- Width is clamped to preserve Search pane minimum width and inspector minimum
  width.
- New width is persisted through `appState.updatePlaybackInspectorWidth`.

Design implication:

The divider is intentionally subtle. It should remain discoverable on hover but
not become a heavy visual boundary.

## 13. Search and Playback Interaction Flow

Primary user flow:

```text
User types query
→ app debounces 250 ms
→ database returns first search page
→ results are grouped by Show → Episode → Hit
→ user scans Show rows, expands a Show, scans Episode sections and Hit rows
→ user clicks a Hit row
→ Search focus clears
→ Playback Inspector opens if collapsed
→ selected row gets the system accent color background
→ video opens or seeks to timestamp
→ playback starts
```

If the selected result belongs to the same video that is already open:

- The player loads the subtitle source as needed.
- It seeks to the new timestamp.
- It does not reopen the video file from scratch.

If it is a different video:

- The player opens the new video request.
- It starts at the result timestamp.

If playback fails:

- Subtitle cues are cleared from the playback view model.
- Playback status becomes failed.
- The inspector renders the error.

## 14. Focus Behavior

Search focus is explicitly managed because the Search field is an AppKit
NSTextView embedded in SwiftUI.

Focus clears when:

- User triggers topbar app commands.
- User selects a sidebar section.
- User toggles the Playback Inspector.
- User toggles all search result groups.
- User toggles one search result group.
- User selects a search result.
- User clicks inside the Playback Inspector.
- User starts dragging the inspector divider.
- User clicks inspector file buttons.
- User clicks video surface actions that are wired through SearchView.

Focus should not be cleared by unrelated system behavior such as app switching
unless AppKit naturally changes first responder.

Design implication:

If a redesigned UI adds toolbar buttons, filters, tabs, or inspector controls,
they should usually clear Search focus when activated unless they are directly
part of text input.

## 15. Keyboard Behavior Relevant to Search

The Search text input must keep normal typing behavior.

Playback keyboard shortcuts are handled only when:

- Search section is active.
- Playback Inspector or fullscreen playback is visible.
- A selected result exists.
- Playback view model exists.
- No editable text input is focused.
- Command, Control, and Option modifiers are not used.

Relevant playback shortcuts:

- `Q`: copy current subtitle.
- `C`: toggle subtitles.
- `F`: fullscreen.
- Space: play/pause.
- Left arrow: seek back 5 seconds.
- Right arrow: seek forward 5 seconds.
- Up arrow: volume up.
- Down arrow: volume down.
- Shift + comma: speed down by 0.25.
- Shift + period: speed up by 0.25.

Design implication:

Do not introduce Search UI keyboard shortcuts that conflict with text input or
with playback shortcuts while video review is active.

## 16. Data and Loading Model

Search starts from `updateSearchQuery`.

Important constants:

- Search debounce: `250 ms`.
- Global page size: `100`.
- Prefetch threshold: `10`.

Search uses database pagination:

- First search: offset `0`, appending `false`.
- Lazy load: offset equals loaded global result count, appending `true`.

Search page returns:

- `results`
- `totalCount`
- `fileSummaries`

Search state tracks:

- Loaded results.
- Total matching count.
- File summaries for grouping.
- Whether more global results exist.
- Collapsed group paths.
- Additional expanded group rows by path.

Design implication:

The UI must distinguish:

- Total matching result count.
- Currently rendered row count.
- Per-file total match count.
- Loaded rows inside each group.

Do not design a count presentation that implies all rows are currently loaded
when only a page is loaded.

## 17. Visual Hierarchy Summary

Current hierarchy from strongest to weakest:

1. Search field.
2. Selected search result row.
3. Group headers.
4. Unselected subtitle row text.
5. Result count / rendered count.
6. Timestamps and secondary metadata.
7. Rail line and dividers.

The Playback Inspector hierarchy:

1. Video preview.
2. Playback error, if present.
3. File location buttons.
4. Empty state text or passive context.

For redesigns, preserve this intent:

- Search results are the main work object.
- Video preview is important but contextual.
- Counts and controls support scanning.
- Dividers should structure the workspace without becoming visual noise.

## 18. Current Design Strengths

- Native macOS shell and controls.
- Good density for subtitle review.
- Search input is always easy to reach.
- Result grouping matches source subtitle files.
- Friendly subtitle display titles reduce filename noise.
- Query highlights are readable on selected and unselected rows.
- Playback Inspector keeps user in Search instead of navigating away.
- Inspector width is resizable and persisted.
- File reveal actions are more useful than passive path metadata.

## 19. Current Design Weaknesses / Redesign Opportunities

These are not bugs; they are areas where future UI exploration may help.

- The Search Header is functional but visually plain.
- Result summary and rendered count read like diagnostics rather than polished
  product UI.
- Collapse/expand-all is text-only and visually understated.
- Empty states are clear but generic.
- The right inspector has little information architecture beyond video and
  buttons.
- The resize divider is subtle and may be hard to discover.
- The Show / Episode / Hit hierarchy relies on indented row backgrounds
  and text weight; spacing and surface treatment may be refined further as
  the design matures.
- File buttons are useful but could better communicate Finder reveal behavior.
- There is no visible quick filter, sort, or scope affordance.
- Search result rows are readable but could better support very long bilingual
  cue groups.

## 20. Redesign Guardrails

When proposing new UI directions, keep these constraints:

- Keep Search as the first-class workspace.
- Do not turn the screen into a marketing page, landing page, or media gallery.
- Preserve native macOS interaction expectations.
- Preserve dense result scanning.
- Preserve the Show → Episode → Hit grouped hierarchy.
- Preserve query highlighting.
- Preserve right-side contextual playback.
- Preserve no-navigation result preview.
- Preserve lazy loading and collapse semantics.
- Do not hide critical result counts behind decorative UI.
- Do not use heavy colorful decoration that competes with subtitle text.
- Do not rely on hover-only controls for essential actions.
- Do not design a fixed-width layout that fails near the minimum window size.
- Do not show long raw file paths as primary visual content.

## 21. Useful Source References

Primary implementation files:

- `apps/macos-native/Sources/CueSeekerApp/SearchView.swift`
- `apps/macos-native/Sources/CueSeekerApp/SearchTextView.swift`
- `apps/macos-native/Sources/CueSeekerApp/AppState.swift`
- `apps/macos-native/Sources/CueSeekerApp/PlaybackView.swift`
- `apps/macos-native/Sources/CueSeekerApp/PlaybackControlsView.swift`
- `apps/macos-native/Sources/CueSeekerApp/ContentView.swift`

Product design references:

- `docs/product/03_ui_design.md`
- `docs/product/04_ux_interaction.md`

## 22. Short Prompt for Other LLMs

Use this when asking another AI to discuss the Search UI:

```text
You are reviewing CueSeeker, a native macOS subtitle search and playback app.
The Search screen has a left Search Results Pane and an optional right Playback
Inspector. Users type a query, scan grouped subtitle results by subtitle file,
select a cue row, and the inspector opens or updates to play the matching video
at that timestamp. The UI should remain a dense, native macOS utility, not a
marketing page. Preserve grouped results, query highlighting, lazy loading,
collapse/expand behavior, and contextual playback. Improve visual hierarchy,
state presentation, inspector structure, and scanning ergonomics without
breaking native desktop expectations.
```

