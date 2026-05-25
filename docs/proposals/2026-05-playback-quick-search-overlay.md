# Proposal: Playback Quick Search Overlay

Status: Proposal

## Background

CueSeeker already supports subtitle search, lazy-loaded search results, search
result playback, result-to-result playback navigation, and copying the current
subtitle from the playback page.

The next interaction step should not start with AI features. The first step is a
fast playback-page search overlay that turns the current subtitle line into a
search query with minimal friction. This keeps the product direction grounded in
local subtitle search before adding optional AI-assisted query expansion later.

## Goals

- Add a centered, slightly upper-positioned quick search overlay on the playback
  page.
- Open the overlay with the Return key when video playback is visible and no
  editable text input already owns focus.
- Focus the overlay input immediately after opening so the user can type or
  press Return without an extra click.
- Pause playback while the overlay is active.
- Restore the pre-overlay playback state when the overlay is dismissed.
- Seed the overlay input from the playback page's current subtitle list, using
  the same source of truth as the playback subtitle sidebar.
- Let the user move through subtitle lines with Up and Down before searching.
- Submit the query with Return and show results directly below the input.
- Reuse existing search result data, paging, lazy loading, and playback
  behavior.
- Reuse existing input, row, highlighting, timestamp, and subtitle display
  helpers wherever practical instead of creating a separate transitional UI
  system.
- Keep Escape focused on dismissing the quick search overlay before fullscreen
  Escape handling.

## Non-goals

- Add AI segmentation, synonym generation, antonym generation, or RAG behavior.
- Change search ranking, query semantics, or the SQLite search schema.
- Add a second independent search engine or search result playlist model.
- Redesign the main Search page.
- Replace the current playback keyboard shortcuts except for adding Return and
  overlay-specific key handling.
- Change playback engine behavior.

## User Flow

The proposed user flow is:

```text
User is watching a video
User presses Return
Playback pauses
Quick Search overlay appears near the upper center of the playback page
Input receives focus immediately
Input is seeded with the current subtitle's last display line
User optionally presses Up or Down to choose a nearby subtitle line
User presses Return
Search results appear directly below the input
The first result is selected by default
User presses Down to move into the result list
User presses Up or Down to select a result
User presses Return
Overlay closes
Selected result opens through the existing Search result playback flow
The underlying Search page state updates to the submitted query and default
result presentation
```

Dismissal flow:

```text
User presses Escape while the overlay is visible
Overlay closes
Playback returns to the state it had before the overlay opened
The Escape event is consumed by the overlay and must not exit fullscreen
```

## UI/UX Impact

The overlay should use the current playback-page cinematic visual language, not
the older light Liquid Glass search-card style and not a literal macOS Spotlight
clone.

Spotlight is only a geometry and interaction reference:

- Wide rounded search surface.
- Search icon at the leading edge.
- Large, comfortable text field.
- Slightly upper-centered placement rather than exact screen center.

The actual surface should align with the current playback UI:

- `PlaybackTheme.cinematicBacking` for the overlay body.
- `.ultraThinMaterial` where the existing playback overlays use it.
- `PlaybackTheme.textPrimary`, `textSecondary`, and `textTertiary` for text and
  hairline contrast.
- The playback overlay hairline pattern:
  `PlaybackTheme.textTertiary.opacity(0.3)` at `0.5`.
- The playback overlay shadow pattern:
  black at roughly `0.42` opacity, large radius, downward offset.

The overlay should be a distinct reusable style/component, not inline ad hoc
styling inside the playback page.

Result presentation should reference the compact Bilibili-style search overlay:

- Results appear in a vertical list directly under the search field.
- The matched query text may be highlighted.
- Rows should show enough subtitle text to identify the result.
- Rows should preserve timestamp and source context where space allows.
- The selected row should have a clear keyboard selection state.
- The list should remain compact and keyboard-first, not a card grid.

## UI Reuse Plan

The quick search overlay is a transitional interaction layer and should stay
thin. It should compose existing UI and helper code rather than creating a new
parallel search UI stack.

Input reuse:

- Use `SearchTextView` for the text input. It already owns single-line editing,
  focus coordination, IME behavior, and Return submission.
- Add only a playback-specific wrapper such as `PlaybackQuickSearchField` to
  provide the larger command-overlay layout, leading magnifying-glass icon, and
  optional clear button.
- Do not implement a custom text field, custom IME handling, or custom Return
  handling inside SwiftUI text primitives.

Result row reuse:

- Use `PlaybackSidebarResultRow` for compact overlay results.
- Do not use `SearchResultCardGroupView`; the main Search card grid is too
  heavy for a command overlay.
- Do not create a second result-row renderer unless the existing playback
  sidebar row proves insufficient after implementation review.

Helper reuse:

- Reuse `formatTimestamp(_:)` for timestamps.
- Reuse `subtitleDisplayLines(content:cueLines:)` for result text display.
- Reuse `highlightedContent(...)` and `SearchHighlightState` for query
  highlighting.
- Reuse `PlaybackTheme.menuItemHighlight` for hovered or keyboard-selected
  result rows.

State and data reuse:

- Reuse `SearchStore.searchQuery`, `searchResults`, paging state, and selected
  result state for submitted overlay searches.
- Reuse the existing search execution path instead of adding an overlay-only
  database query path.
- Reuse `markSearchResultVisible` and `loadMoreSearchResultsIfNeeded` for lazy
  loading.
- Reuse `openSearchResult(result)` for playback.

New UI should be limited to layout glue:

```text
PlaybackQuickSearchOverlay
  -> PlaybackQuickSearchField
  -> PlaybackSidebarResultRow
  -> existing SearchStore / openSearchResult
```

## Subtitle Line Selection

The initial query and subtitle-line navigation must come from the playback
page's current subtitle list, not from a separate database lookup:

```text
playback.currentSubtitleEntries
playback.currentSubtitleEntryLookup
subtitleDisplayLines(content:cueLines:)
```

This keeps Quick Search aligned with the visible playback subtitle sidebar and
avoids a second "current subtitle" source of truth.

When the overlay opens:

- Use `playback.currentSubtitleEntryLookup.activeEntryID(atMilliseconds:)` to
  locate the current subtitle entry from `playback.currentSubtitleEntries`.
- Use `subtitleDisplayLines(content: entry.content, cueLines: [])` to derive
  the visible display lines for that entry.
- Seed the input with that entry's last non-empty display line.

Line navigation is line-based, not cue-card-based:

- Build a transient quick-search line stream from
  `playback.currentSubtitleEntries`.
- Each subtitle entry contributes at most one quick-search candidate: the last
  non-empty display line returned by `subtitleDisplayLines`.
- Up moves to the previous candidate in that stream.
- Down moves to the next candidate in that stream until the user enters result
  navigation.
- Same-timestamp merged subtitle content should be treated as one subtitle
  moment for display selection.
- If a same-timestamp subtitle moment contains multiple subtitle entries, each
  entry contributes only its last non-empty display line to the quick-search
  line candidates.
- Up and Down can switch subtitle candidates only while the input is unchanged
  from the currently selected subtitle candidate. Once the user edits the input,
  Up and Down must no longer replace the query with another subtitle line.

Example:

```text
Two same-timestamp subtitle entries
Each entry has two lines
Quick Search line candidates use only the last line from each entry
```

This keeps quick search aligned with the user's visible final subtitle line
rather than forcing the user to search every bilingual or multi-line component.

## Search Behavior

Submitting the overlay query should update the existing Search state instead of
using a separate search store:

- Set the main search query to the submitted overlay query.
- Start the existing non-debounced search flow.
- Preserve existing result grouping, lazy loading, and paging behavior.
- Show a compact overlay projection of those results under the search field,
  using the existing playback sidebar result row.
- Select the first loaded result by default after the query is submitted.
- Pressing Return again immediately after the first result is selected should
  open that selected result. This makes the common flow "Return, Return" mean
  "search current subtitle line, then play the best/default result."
- Keep the underlying Search page in its default result presentation after a
  result is opened.

The overlay result list should call the existing lazy-load hooks when the user
navigates near the loaded result boundary, matching the main Search page's
behavior.

## Playback Behavior

Opening the overlay records whether playback was playing immediately before the
overlay opened.

Rules:

- Opening the overlay pauses playback.
- Pressing Escape closes the overlay.
- Escape restores playback only if playback was playing before the overlay
  opened.
- Escape keeps playback paused if playback was already paused before the
  overlay opened.
- Opening a selected result closes the overlay and then uses existing search
  result playback.
- Opening a selected result should not restore the old playback state; the new
  selected result owns playback state.

Opening a result should use the existing search result path, equivalent to:

```text
openSearchResult(result)
```

This ensures the current Search result playlist and previous/next result
navigation remain consistent with the main Search page.

## Keyboard Priority

Keyboard handling priority while the overlay is visible:

1. Escape dismisses the quick search overlay and consumes the event.
2. Return submits the input or opens the selected result.
3. Up and Down navigate subtitle line candidates only while the input still
   equals the selected subtitle candidate.
4. After the user edits the input, Up and Down no longer replace the query with
   subtitle candidates.
5. After search results are visible, Up and Down navigate the result list.
6. Other playback shortcuts are disabled while the overlay owns focus.

Escape must be handled before fullscreen Escape behavior. In fullscreen, pressing
Escape with the overlay visible closes the overlay and must not exit fullscreen.

## Data Model Impact

No database schema change is required.

Transient UI state is expected:

- Overlay visibility.
- Overlay input text.
- Whether playback was playing before the overlay opened.
- Current subtitle line candidate index.
- Whether the input is still equal to the current subtitle candidate.
- Current overlay result selection index.
- Whether the overlay is in subtitle-line navigation or result-list navigation.

The existing Search state remains authoritative for submitted query and results.

## Implementation Stages

Stage 1: overlay shell and playback state.

- Return opens the overlay on the playback page.
- The overlay input receives focus immediately.
- Opening pauses playback and records whether playback was playing.
- Escape closes the overlay, consumes the event, and restores the prior
  playback state.
- The default input is seeded from the playback subtitle sidebar source of
  truth: current subtitle entry plus its last display line.

Stage 2: subtitle candidate navigation.

- Build the quick-search line stream from `playback.currentSubtitleEntries`.
- Each entry contributes only its last non-empty display line.
- Up and Down switch to the previous or next candidate while the input remains
  unchanged from the selected candidate.
- Once the user edits the input, Up and Down stop replacing the query with
  subtitle candidates.

Stage 3: query submission and result display.

- Return submits the current input through the existing `SearchStore` flow.
- Results appear under the overlay input.
- The first loaded result is selected by default.

Stage 4: result navigation and playback.

- Up and Down move through visible overlay results.
- Lazy loading follows the existing Search page behavior.
- Return opens the selected result through `openSearchResult(result)`.
- Opening a result closes the overlay and does not restore the old playback
  state.

## Technical Risk

Risks:

- Keyboard handling can conflict with fullscreen Escape and existing playback
  shortcuts if overlay priority is not explicit.
- Reusing the main `SearchStore` from an overlay requires care so the Search
  page and overlay do not fight over focus, presentation, or lazy loading.
- Subtitle line selection must avoid assuming a universal bilingual or
  "Chinese-line" concept. It should use the database's normalized subtitle lines
  and the quick-search line rules above.
- Command-overlay visual treatment can become hard to maintain if it introduces
  one-off colors instead of following the current playback cinematic tokens and
  overlay patterns.
- Because the overlay is transitional UI, custom result rows, custom
  highlighting, or a duplicate search state model would create avoidable
  maintenance cost.
- The overlay must avoid restoring old playback state after the user opens a new
  result.

## Acceptance Criteria

- Pressing Return on the playback page opens the quick search overlay when no
  editable text input is focused.
- The overlay input receives focus immediately after opening.
- Opening the overlay pauses playback.
- The overlay input defaults to the current playback subtitle entry's last
  non-empty display line, using the same data source as the playback subtitle
  sidebar.
- Up and Down can move between nearby subtitle candidates before a search is
  submitted while the input is unchanged from the selected candidate.
- Up and Down do not replace the query after the user edits the input.
- Same-timestamp merged subtitle content follows the quick-search line selection
  rules in this proposal.
- Pressing Return with a query submits a Search using the existing Search flow.
- Search results appear directly below the search field.
- The first loaded search result is selected by default after submission.
- Pressing Return twice from the initial seeded input can search and then open
  the default selected result.
- Result list keyboard navigation supports selecting a result with Up and Down.
- Pressing Return on a selected result opens it through the existing Search
  result playback flow.
- Opening a result closes the overlay.
- Opening a result updates the underlying Search page to the submitted query and
  default result presentation.
- Pressing Escape while the overlay is visible closes the overlay.
- Escape restores playback only when playback was playing before the overlay
  opened.
- Escape is consumed by the overlay and does not exit fullscreen while the
  overlay is visible.
- The overlay style is implemented through a reusable class/component that
  follows the current playback cinematic overlay visual language.
- The text input uses `SearchTextView` rather than a custom text field.
- Overlay result rows reuse `PlaybackSidebarResultRow`.
- Query highlighting, subtitle display lines, and timestamp formatting reuse the
  existing helper functions.

## Decision

Pending.

The current direction is to build the playback quick search overlay before any
AI-assisted search feature. The overlay should be treated as the first product
step toward lower-friction subtitle lookup, with optional AI query expansion
remaining outside this proposal.
