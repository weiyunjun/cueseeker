# Cue-Centric Table UI

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Cue-Centric Search Shiori Context Playback And Export.md`
- `docs/human/design/UI.md`

## Scope

Implement the Cue-centric Search, Shiori, and Context table presentation in
reviewable stages. Phase 4A establishes the row data contract and preserves
complete source text. Phases 4B and 4C add dynamic virtual row geometry,
optional Cue Group rendering, and shared Cue Group interactions without
changing primary Cue semantics. Phase 4D verifies presentation refresh scope
through mounted native surfaces and exact diagnostic counters.

## Classification

- Product semantics: one table row and every default action target one primary
  Cue.
- Presentation context: ordered sibling Cue text remains optional secondary
  context and cannot replace the primary Cue identity.
- Platform UI data: the AppKit table receives exact primary and group payloads
  without owning database lookup or Cue identity resolution.

## Phase 4A: Row Contract And Complete Text

### Implementation

- Replaced the table row's ambiguous merged subtitle field with explicit exact
  primary Cue text, source-ordered Cue Group texts, and an optional resolved
  primary group index.
- Kept `cues` as a compatibility projection of exact primary Cue text so
  existing drawing and action code cannot silently switch to Cue Group text.
- Derived additional Cue texts by excluding the resolved primary array index,
  not by comparing text. Duplicate sibling Cues therefore remain distinct.
- Added a complete Cue Group clipboard payload that joins every source-ordered
  Cue while preserving each Cue's internal line order and line breaks.
- Mapped Search and Search-hosted Context rows from `SubtitleSearchResult`
  primary content, ordered group lines, and identity-resolved primary index.
  Row identity remains the primary Cue ID.
- Mapped Shiori rows from exact saved Cue content and `ShioriCuePresentation`.
  Indexed Shiori retain ordered group context, Cue-local language and Speaker
  presentation, while unresolved legacy snapshots fall back to their exact
  saved content with no inferred primary group index. Row identity remains the
  Shiori ID.
- Removed the six-line and 500-character table display budgets and stopped
  normalizing table payloads through the trimming/filtering display helper.
- Kept the Copy Table Cues column bound explicitly to exact primary Cue text,
  independent of the future `Show Cue Group` presentation state.
- Preserved primary/group presentation fields when patching visible Shiori tag
  cells.

### Verification

- `swift test --filter TableSandboxRowModelStoreTests` passed 30 tests.
- `swift test --filter SubtitleTableClipboardTests` passed 7 tests.
- `swift test` passed the complete package suite: 505 Swift Testing tests and
  7 XCTest tests, with 0 failures.
- `git diff --check` passed with no whitespace errors.
- Focused coverage verifies more than six source lines, a line longer than 500
  characters, internal empty lines, duplicate sibling text, identity-resolved
  array exclusion, source-ordered group copy text, indexed and orphan Shiori
  presentation, Shiori tag patch preservation, stable Search/Context/Shiori
  row identity, and primary-only Copy Table output.

## Phase 4B: Dynamic AppKit Row Geometry

### Implementation

- Added exact TextKit visual-line measurement for primary and additional Cues.
  Measurement preserves source breaks, terminal and consecutive empty lines,
  and current-width soft wrapping without a line or character ceiling.
- Applied the documented row formula `max(40, 16 + 24P + 20S)`, 8pt vertical
  padding, 12pt leading padding, and 14pt trailing padding. Primary Cue lines
  use 14pt medium text in 24pt slots; additional Cue lines use 12pt regular
  muted text in 20pt slots.
- Added a production measurement cache keyed by row and primary Cue identity,
  exact primary/group payload, resolved primary group index, effective Cues
  width, Show Cue Group state, and layout style revision.
- Replaced the fixed virtual-row placeholder with an explicitly row-counted
  sparse Fenwick height index. Measured height updates, prefix offsets, total
  height, and inverse row lookup remain logarithmic and do not allocate per
  virtual row.
- Limited measurement to the viewport plus four rows of overscan and explicit
  anchor or scroll targets. Append preserves sparse measurements; reload,
  identity/content, width, Show state, and style changes invalidate only the
  required geometry.
- Preserved a scroll anchor made from primary Cue identity and the primary
  first visual line's screen-space Y across Cues-width and Show-state reflow.
  Document size, scrollbar, cursor, hover, and menu geometry update after the
  corrected layout.
- Split dirty drawing from measurement overscan and intersected AppKit dirty
  regions with the viewport, preventing a whole-document invalidation from
  iterating a multi-million-row virtual document.
- Aligned Display Title, Time, Date Added, checkbox, and the first Tags row to
  the primary Cue's first visual slot.

## Phase 4C: Cue Group Presentation And Interaction

### Implementation

- Passed the persistent `SettingsStore.showCueGroup` presentation value into
  Search and Shiori tables; Search-hosted Context reuses the Search table path.
  The change does not notify data hydration, rerun a query, or rebuild a row
  snapshot.
- Show Off renders only the exact primary Cue. Show On renders every additional
  Cue in stable source order above the primary Cue while retaining the primary
  Cue as the row, selection, playback, Context, and menu action target.
- Made all displayed Cue text one actual-text union hover, underline, pointer,
  left-click, and right-click region without expanding interaction to the full
  Cues cell.
- Added `Copy Cue Group Text` with the same copy icon only while Show is On.
  `Copy Cue Text` and Copy Table remain bound to exact primary Cue text, while
  group copy preserves Cue and internal source-line order. Shiori continues to
  include `Remove Shiori`.
- Added an explicit primary Cue identity to table rows so Shiori scroll anchors
  use `ShioriCuePresentation.cueID` instead of incorrectly treating the Shiori
  row ID as a Cue ID; unresolved snapshots use a row-local fallback.

### Verification

- `swift build` passed.
- The combined dynamic table, sparse height index, measurement cache, row model,
  and virtual AppKit table filter passed 94 tests.
- `SubtitleTableVirtualRowTests` passed 50 tests against attached real
  coordinators and AppKit document/scroll views.
- `swift test` passed the complete package suite: 522 Swift Testing tests and
  7 XCTest tests, with 0 failures.
- Coverage verifies 40/64/88pt primary heights, 60/80/84pt mixed heights,
  terminal and consecutive empty lines, CRLF, unlimited hard/soft wrapping,
  documented 24/20pt styles, sparse 2,000,000-row and 50,000-row prefix/inverse
  geometry, append/reload invalidation, width and Show anchor error below 0.5pt,
  unchanged count/selection/primary action identity, shared extra-Cue left and
  right hit targets, Off/On/Shiori menus and copy payloads, row-local dirty
  drawing, and viewport-bounded measurement independent of total row count.
- The Liquid Glass component and UX mapping documents contain no conflicting
  table-specific contract requiring synchronization for this phase.

## Phase 4D: Refresh Scope Verification

### Implementation

- Added a diagnostic action mark for the persistent Show Cue Group setting and
  owner counters for Show-state and width-dependent table reflow.
- Added production counters for table snapshot rebuilds, row hydration,
  dynamic row measurement, scroll-anchor correction, Subtitle Focus Cue
  measurement, Library snapshot rebuilds, Playback render-host updates, and
  high-frequency Playback chrome publication.
- Added synchronous task-local recording plus an asynchronous multi-session
  registry. Async events carry an explicit App scope, match that scope exactly,
  support overlapping scoped and catch-all sessions, and stop recording
  linearly when a session finishes.
- Kept every probe behind a non-test/disabled fast path outside tests and made
  detail construction lazy. The diagnostic flag remains
  `CUESEEKER_PERF_UI`.
- Projected Show Cue Group into its own observable store so changing the
  preference does not publish the complete Settings store. Search, Context,
  and Shiori consume the value through a visibility gate: a playback-covered
  table freezes its current presentation and applies the deferred value once
  when the workbench becomes active again. The persisted On value is used on
  the first visible table presentation without an intermediate Off reflow.
- Passed playback visibility from the observing Search owner as a stable Bool
  instead of making each table observe the complete Playback store.
- The mounted AppKit integration harness is retained only for the bounded test
  suite because releasing the complete SwiftUI graph under
  `swiftpm-testing-helper` crashes in `objc_autoreleasePoolPop` on macOS 15.
  Before retention it stops playback, orders the window out, and explicitly
  removes table-global event and notification monitors.

### Verification

- The real native Settings switch records its user action and performs one
  table-owner reflow in mounted Search, Context, and Shiori. It measures only
  the union of the before/after visible-plus-overscan rows, preserves the
  anchored primary Cue below 0.5pt, and leaves row identity, selection,
  snapshots, hydration, Library, Playback render host, Subtitle Focus, and
  high-frequency Playback chrome unchanged.
- With Playback, its render host, and a multi-line Subtitle Focus reel mounted,
  Show Cue Group leaves both playback surfaces and the covered table unchanged;
  returning to the workbench applies the deferred value exactly once while
  preserving primary Cue identity and the anchor below 0.5pt.
- Mounted width-dependent table reflow records one owner update, preserves the
  anchor below 0.5pt, and leaves a simultaneously mounted Subtitle Focus
  body's native inputs, layout, and Cue measurements unchanged. AppKit may
  redraw already measured Focus pixels during a host-window resize. Table
  snapshots, hydration, Library snapshots, and Playback render host also stay
  unchanged.
- Successful Context hydration records request, snapshot, and applied events;
  a missing target records the request without a false applied event.
- Overlapping scope A, scope B, and catch-all async probe sessions remain
  isolated, and a finished session receives no later event.
- `swift test --filter SettingsStoreSearchTests` passed 4 tests.
- `swift test --filter TableSandboxRowModelStoreTests` passed 31 tests.
- `swift test --filter SubtitleTableVirtualRowTests` passed 52 tests.
- `swift test --filter CueGroupRefreshScopeIntegrationTests` passed 9 tests.
- `swift test --filter PlaybackSubtitleFocusLayoutTests` passed 28 tests.
- `swift test --quiet` passed the complete package suite: 548 Swift Testing
  tests and 7 XCTest tests, with 0 failures.
- `git diff --check` passed with no whitespace errors.

### Documentation Follow-up

The final completion audit corrected the earlier Phase 4C statement about
Liquid Glass mappings: the active mapping documents still described the older
Search and Shiori card surfaces. That conflict was resolved by the active-doc
alignment recorded in
`docs/engineering/records/2026-07-12-cue-centric-documentation-closeout.md`.

## Outcome

Phases 4A through 4D give Search, Shiori, and Context one unambiguous primary
Cue plus complete optional Cue Group context, content-driven virtual geometry,
shared AppKit interactions, and verified local refresh scope. Presentation
changes preserve scroll position and primary action identity without
truncating subtitle content, scanning the full virtual row count, changing Copy
Table semantics, rebuilding row snapshots, or invalidating hidden Playback and
Subtitle Focus surfaces.
