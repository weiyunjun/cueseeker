# Proposal: Playback Quick Search Overlay

Status: Proposal

## Background

CueSeeker already supports subtitle search, lazy-loaded search results, search
result playback, result-to-result playback navigation, and copying the current
subtitle from the playback page.

The next interaction step should not start with AI features. The first step is a
fast playback-page search overlay for local subtitle lookup with minimal
friction. This keeps the product direction grounded in local subtitle search
before adding optional AI-assisted query expansion later.

## Goals

- Add a centered, slightly upper-positioned quick search overlay on the playback
  page.
- Open the overlay with the Return key when video playback is visible and no
  editable text input already owns focus.
- Give the overlay keyboard priority immediately after opening. Focus the text
  input only when the input is the current logical focus target.
- Pause playback while the overlay is active.
- Restore the pre-overlay playback state when the overlay is dismissed.
- Open the overlay input empty.
- Keep the playback page's current subtitle sentence available as transient
  overlay context for optional AI-assisted actions, using the same source of
  truth as the playback subtitle sidebar.
- Submit the query with Return and show results directly below the input.
- Reuse existing search result data, paging, lazy loading, and playback
  behavior.
- Reuse existing input, row, highlighting, timestamp, and subtitle display
  helpers wherever practical instead of creating a separate transitional UI
  system.
- Keep Escape owned by the quick search overlay before fullscreen Escape
  handling.

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
Overlay receives keyboard priority immediately
Input is empty
User types a query or uses an optional overlay action to choose a query
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

Dismissal flow from the input:

```text
User presses Escape while the overlay input has focus
Overlay closes
Playback returns to the state it had before the overlay opened
If the overlay search did not open a result, the previous Search page and
playback result-list context are restored
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

## Current Subtitle Context

The Quick Search input opens empty. The playback page's current subtitle
sentence may still be captured as transient overlay context for optional
AI-assisted actions, but it must not be inserted into the input by default.

Current subtitle context must come from the playback page's current subtitle
list, not from a separate database lookup:

```text
playback.currentSubtitleEntries
playback.currentSubtitleEntryLookup
subtitleDisplayLines(content:cueLines:)
```

This keeps optional Quick Search actions aligned with the visible playback
subtitle sidebar and avoids a second "current subtitle" source of truth.

When the overlay opens:

- Use `playback.currentSubtitleEntryLookup.activeEntryID(atMilliseconds:)` to
  locate the current subtitle entry from `playback.currentSubtitleEntries`.
- Use `subtitleDisplayLines(content: entry.content, cueLines: [])` to derive
  the visible display lines for that entry.
- Capture that entry's last non-empty display line as the current sentence
  context.
- Leave the input empty.

Current sentence context is line-based, not cue-card-based:

- Build a transient quick-search line stream from
  `playback.currentSubtitleEntries`.
- Each subtitle entry contributes every non-empty display line returned by
  `subtitleDisplayLines`, in display order.
- Opening the overlay captures the current subtitle entry's last non-empty
  display line as the current sentence context.
- Same-timestamp merged subtitle content should be treated as one subtitle
  moment for display selection.
- If a same-timestamp subtitle moment contains multiple subtitle entries, their
  display lines remain adjacent in the quick-search line stream.
- Up and Down do not switch subtitle candidates. They are reserved for moving
  between the input, visible option rows, and visible search results.

Example:

```text
Two same-timestamp subtitle entries
Each entry has two lines
Quick Search line candidates contain all four display lines in order
```

This keeps optional quick-search actions aligned with visible subtitle lines
without making the current entry's final visible line the default query.

## Search Behavior

Submitting the overlay query may temporarily use the existing Search execution
path, but it must not permanently replace the Search page or playback
result-list context until the user opens a result:

- Snapshot the current Search page and playback result-list context when the
  overlay opens.
- Set the main search query to the submitted overlay query only for the active
  overlay interaction.
- Start the existing non-debounced search flow.
- Preserve existing result grouping, lazy loading, and paging behavior.
- Show a compact overlay projection of those results under the search field,
  using the existing playback sidebar result row.
- Select the first loaded result by default after the query is submitted.
- After direct search results are visible, pressing Escape while a result has
  logical focus moves focus back to the input and keeps the result list visible.
- After direct search results are visible, pressing Escape while the input has
  focus dismisses the overlay and restores the pre-overlay Search page and
  playback result-list context.
- Pressing Return again while a result is selected should open that selected
  result.
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
- Pressing Escape from the input closes the overlay.
- Pressing Escape from a direct-search result moves focus back to the input and
  keeps results visible.
- Escape restores playback only if playback was playing before the overlay
  opened and the overlay is dismissed.
- Escape keeps playback paused if playback was already paused before the
  overlay opened and the overlay is dismissed.
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

1. Escape follows the overlay focus rules and consumes the event.
2. Return submits the input or opens the selected result.
3. Up and Down move logical focus between the input, visible option rows, and
   visible search results.
4. Left and Right remain available to the input unless a visible option row owns
   its own horizontal selection.
5. Other playback shortcuts are disabled while the overlay owns focus.

Escape must be handled before fullscreen Escape behavior. In fullscreen,
pressing Escape with the overlay visible must not exit fullscreen.

Logical focus must align with visible first-responder behavior:

- When the logical focus target is an option row or search result, the search
  input must not show a caret and must not be the AppKit first responder.
- When logical focus returns to the input, the input becomes the AppKit first
  responder and may show the caret.

## Data Model Impact

No database schema change is required.

Transient UI state is expected:

- Overlay visibility.
- Overlay input text.
- Whether playback was playing before the overlay opened.
- Current subtitle sentence context.
- Current logical focus target: input, option, or result.
- Current overlay result selection index.
- Whether submitted results came from direct search or an option-driven search.
- A transient snapshot of the pre-overlay Search page and playback result-list
  context so Escape can restore it when no result is opened.

The existing Search flow remains authoritative for executing submitted overlay
queries. The pre-overlay Search context remains authoritative again if the
overlay is dismissed without opening a result.

## Implementation Stages

Stage 1: overlay shell and playback state.

- Return opens the overlay on the playback page.
- The overlay receives keyboard priority immediately.
- Opening pauses playback and records whether playback was playing.
- Escape from the input closes the overlay, consumes the event, and restores the
  prior playback state.
- The input opens empty.
- The current subtitle sentence context is captured from the playback subtitle
  sidebar source of truth: current subtitle entry plus its last display line.

Stage 2: logical focus navigation.

- Build the quick-search line stream from `playback.currentSubtitleEntries`.
- Each entry contributes every non-empty display line in display order.
- Opening captures the current subtitle entry's last display line as current
  sentence context.
- Up and Down move between input, visible option rows, and visible search
  results.
- Up and Down do not replace the input with nearby subtitle candidates.
- Moving logical focus away from the input removes real text focus from the
  input.
- Moving logical focus back to the input makes the input the real text
  responder.

Stage 3: query submission and result display.

- Return submits the current input through the existing `SearchStore` flow.
- Results appear under the overlay input.
- The first loaded result is selected by default.
- If a result is already selected for the submitted query, pressing Return opens
  that selected result through the existing playback path.

Stage 4: result navigation and playback.

- Up and Down move between the input and visible overlay results.
- Lazy loading follows the existing Search page behavior.
- The overlay result list renders the loaded result set rather than an arbitrary
  fixed preview count.
- Escape from a result reached by direct search returns focus to the input.
- Escape from the input dismisses the overlay.
- Return opens the selected result through `openSearchResult(result)`.
- Opening a result closes the overlay and does not restore the old playback
  state.

## Technical Risk

Risks:

- Keyboard handling can conflict with fullscreen Escape and existing playback
  shortcuts if overlay priority is not explicit.
- Reusing the main `SearchStore` from an overlay requires care so the Search
  page and overlay do not fight over focus, presentation, or lazy loading.
- Current sentence context must avoid assuming a universal bilingual or
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
- The overlay receives keyboard priority immediately after opening.
- Opening the overlay pauses playback.
- The overlay input opens empty.
- The overlay captures the current playback subtitle entry's last non-empty
  display line as current sentence context, using the same data source as the
  playback subtitle sidebar.
- Up and Down do not move between nearby display-line candidates.
- Up and Down move logical focus between the input, visible option rows, and
  visible search results.
- When an option row or result is selected, the search input does not show a
  caret and does not own AppKit text focus.
- Same-timestamp merged subtitle content follows the quick-search line selection
  rules in this proposal.
- Pressing Return with a query submits a Search using the existing Search flow.
- Search results appear directly below the search field.
- The first loaded search result is selected by default after submission.
- Result list keyboard navigation supports selecting a result with Up and Down.
- Pressing Return on a selected result opens it through the existing Search
  result playback flow.
- Opening a result closes the overlay.
- Opening a result updates the underlying Search page to the submitted query and
  default result presentation.
- After direct search results are visible, pressing Escape while a result has
  logical focus moves focus back to the input and keeps results visible.
- Pressing Escape while the input has focus closes the overlay and restores the
  Search page and playback result-list context that existed before the overlay
  opened.
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
