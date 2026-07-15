# Playback Multi-Module Overlay

## Human-Owned Source

- `docs/human/requirements/20260714-Feature-Playback Multi-Module Overlay.md`
- `docs/human/design/UI.md`

## Scope

Upgrade the playback Subtitle Focus surface into one temporary multi-module
overlay session. Preserve Current behavior while adding the shared shell,
strict session cleanup, shared virtual-reel infrastructure, Playlist, Search,
Recent, Library, and Shiori in independently verifiable implementation steps.

Playlist is the Overlay name for the already-existing ordered result list that
opened the current Search or Shiori playback item. It is not a new persistent
business model. The implementation adapts those existing source-list identities,
counts, order, exact-search progress, and navigation scope into a temporary
Overlay window without changing their established behavior.

## Implementation Steps

### 1. Session Shell and Sidebar

- Added canonical Current, optional Playlist, Search, Recent, Library, and
  Shiori module identities with the documented labels and symbol assets.
- Made available modules and the selected module session-owned transient state.
  A new session starts on Current; Tab cycles only the available canonical
  order; direct selection supports sidebar clicks.
- Clear the selected module and available-module capability together with cue,
  action, navigation, scrollbar, and motion state when the session ends.
- Added the fixed 240-point sidebar using the existing app-sidebar size tokens
  and the existing Subtitle Focus selected/unselected color tokens. Current is
  still rendered by the existing reel without geometry changes.
- Routed unmodified Tab before editable-input focus handling so it always
  switches modules. Current now uses Enter for playback; Space is consumed
  without a playback action.
- Bound the mounted overlay view identity to the session generation so a
  destroyed session dismantles the previous native reel before a later session
  is mounted.

### 2. Strict Five-Point Visual Line Stack

- Added the documented five-point internal-line token without changing the
  eight-point gap between independent Current cue containers.
- Replaced Current's fixed per-line slot drawing with one Visual Line Stack
  planner shared by measurement and native drawing.
- Kept TextKit responsible for hard-line and soft-wrap fragmentation, then used
  CoreText run typographic bounds to resolve the actual fallback-font ascender
  and descender for every visual line. Ink bounds and fixed line-fragment
  heights do not participate in vertical placement.
- Placed every line from the second onward exactly five points below the prior
  line's typographic bottom. The complete stack is centered once inside
  `max(52 * line count, stack height)` so ordinary one-, two-, and three-line
  Current heights remain 76, 128, and 180 points.
- Normalized CRLF and CR for layout and used an invisible zero-width sentinel
  only when needed to retain empty text and a trailing empty source line.
- Kept the complete natural layout anchored at the top of oversized cue rows
  and clipped only the trailing overflow. No internal reading offset or
  ellipsis was introduced.
- Incremented the measurement style revision so pre-change cached geometry
  cannot be reused.

### 3. Item-Agnostic Shared Virtual Reel

- Extracted Current's local placement, dynamic extent measurement, direct
  drawing, scrolling, selection, scrollbar, and view recycling behind a shared
  item adapter without changing Current's accepted geometry or interactions.
- Defined a snapshot contract with a stable dataset identity, generation,
  monotonic revision, stable total count within one generation, and one
  contiguous loaded ordinal range. Every loaded item must also provide a stable
  item identity; missing identities fail closed instead of falling back to an
  ordinal-derived identity.
- Made adapters responsible only for item identity, extent measurement,
  drawing, visible-window requests, measurement invalidation, and complete
  teardown. The shared reel remains independent of Current, Playlist, Search,
  and Shiori data models.
- Routed Current through a dedicated adapter while preserving its five-point
  internal Visual Line Stack, eight-point gap between independent cues,
  50,000-item viewport-bounded work, exact cue actions, and existing motion.
- Added the standard 32-item remote window policy for visible selection,
  keyboard, wheel, and scrollbar navigation. An unloaded target is committed
  only after a matching dataset and generation window is mounted.
- Enforced latest-intent-wins behavior across external selection changes,
  keyboard and wheel input, scrollbar commits, restore requests, and delayed
  window responses. Scrollbar drag previews remain non-committing until mouse
  up, including when the preview requires a remote window.
- Reject stale generations, revision regressions, malformed replacement
  snapshots, and same-generation total-count changes without allowing a late
  replacement adapter to clear valid mounted content. Pending requests are
  reissued when their adapter transport or intermediate partial window changes.
- Bound Current's adapter generation to the overlay session generation. Session
  dismantle cancels motion and pending requests, clears selection and geometry,
  releases measurements, and invalidates the mounted adapter.
- Kept Playback Cue Result rendering and all Playlist, Search, and Shiori data
  adapters out of this infrastructure-only step.

### 4. Shared Playback Cue Result Rendering and Extents

- Classified this step as platform UI/UX and kept the presentation model,
  TextKit/CoreText layout, native drawing, and measurement cache inside
  `CueSeekerApp`. No module store, durable product mutation, playback execution,
  keyboard action, or real Playlist/Search/Shiori data source was added.
- Added a Playback-specific Result presentation model that separates the stable
  occurrence `itemID` used by the shared Reel from the stable Primary Cue
  identity used by later module actions. This supports repeated occurrences of
  the same Primary Cue without making Cue Group visibility part of identity.
- Extended the existing Visual Line Stack planner from one uniform Current Cue
  to mixed-style segments while retaining Current's original single-segment
  entry point. Segment identity and nominal line height are carried through
  ordinary text, Cue-boundary newlines, empty lines, and terminal sentinels.
- Rendered all visible Additional Cues above the Primary Cue as one continuous
  stack. Primary uses 40/52 semibold typography; Cue Group uses 28/38 medium
  typography. Every adjacent typographic line remains exactly five points apart
  across hard lines, soft wraps, Additional Cue boundaries, and the final
  Additional-to-Primary boundary.
- Calculated mixed nominal height by summing each visual line's 52- or 38-point
  slot height, compared it with the actual font-run typographic stack, centered
  the complete stack once, added 12-point top and bottom padding, and passed the
  resulting natural/resolved/oversized extent through the shared Reel contract.
- Added the documented selected Primary, selected Cue Group, and common
  unselected colors. Show Cue Group changes presentation and extent without
  changing the occurrence or Primary Cue identities.
- Added the optional 48-point Playlist Sequence Number lane. It uses the 14-point
  body font, the unselected color, right alignment, and the real baseline of the
  Primary Cue's first visual line. The lane participates in wrapping width but
  not Result height or identity, and it clips with the same vertically padded
  content region as the Cue text.
- Added a 64-entry LRU measurement cache keyed by all geometry inputs. The exact
  Sequence Number and Selected color state intentionally do not invalidate
  geometry; lane presence, content, order, Cue Group visibility, width, viewport,
  identities, and style revision do.
- Verified the Result core against the item-agnostic shared Reel with a lazy
  50,000-item test adapter. Only visible/overscan Result extents are measured;
  no production module adapter or second virtual-list implementation was added.

### 5. Existing Playback-Origin List Adapter

- Classified Playlist source capture as application presentation/session state,
  while keeping the ordered Shiori retrieval needed by that adapter inside
  `CueSeekerCore`. No new Playlist business model, persistence, or independent
  navigation semantics were introduced.
- Captured the existing Search result-list run or Shiori playback navigation
  scope as the current playback-origin source. Search adjacent playback reuses
  its run; Shiori adjacent playback reuses the exact explicit ID scope or the
  existing database-order fallback. Library playback and playback stop clear
  this capability.
- Kept Search as the list authority. The adapter mirrors its current `xx rows`
  total independently from the identities already hydrated in memory, reads
  loaded ranks directly when possible, and otherwise reuses the existing table
  window loaders. Initial results, cumulative exact progress, and final exact
  completion refresh the source without cancelling or replacing the existing
  exact-completion task.
- Preserved one dataset identity while Search exact work progresses. A change
  to total, order, membership, or known identity boundary advances generation,
  satisfying the shared Reel's stable-total-per-generation invariant; a
  same-boundary content refresh advances only source revision. Requests and
  responses validate dataset, generation, revision, total, range, ordinal, and
  stable item identity so late work cannot publish into a newer boundary.
- Adapted Shiori explicit scopes by loading only the requested IDs, in their
  existing navigation order, with Cue Presentation metadata. Added a Core
  batch API that preserves first-occurrence input order, ignores missing rows,
  and reuses the established Shiori presentation resolver. Scope-free playback
  continues to use `created_at DESC, id DESC` through the existing page API.
- Mapped Search and Shiori rows to presentation/action items without changing
  their Primary Cue. Cue Group siblings are removed by `primaryGroupIndex`, not
  by text equality, so repeated subtitle text remains correct. Playlist sequence
  remains the one-based source ordinal.
- Added a Session-owned window store that retains at most the standard 32
  items. Overlay dismissal cancels its load, rejects late publication, clears
  loaded items and selection, and leaves the playback-origin Search/Shiori
  source intact. Reopening creates a fresh window; playback source replacement
  invalidates the origin source itself.

### 6. Playlist Module and Shared Reel Interaction

- Classified the Playlist module as platform UI/session presentation over the
  existing playback-origin source, with only the final target dispatch entering
  playback execution. No Playlist persistence, ordering, or independent
  business semantics were introduced.
- Enabled Playlist only when the current playback-origin source has items and
  mounted its Session window through the item-agnostic shared Reel. The adapter
  maps the existing dataset/generation/revision contract, retains the standard
  32-item window, renders the shared Playback Cue Result, displays the one-based
  source ordinal, and applies the persistent Show Cue Group setting.
- Reused Current's Focus Anchor, dynamic extent, wheel, trackpad, keyboard,
  scrollbar preview, settle, and recycling implementation. Remote keyboard,
  wheel, and scrollbar commits now keep the shared motion gate active until the
  matching window has loaded and the target selection has settled.
- Preserved Playlist window data, selection, and Reel position when switching
  modules inside one Overlay Session. Adapter dismantle releases only its
  presentation measurements; Overlay dismissal destroys the Session window,
  cancels its load, clears its items and selection, and releases the adapter
  cache.
- Added Playlist Up/Down and the shared S/C/Enter action contract. Actions wait
  for the settled Primary Cue, including remote-window navigation. S saves only
  a Search Primary Cue and reports an existing Shiori item as already saved; C
  copies only Primary Cue text; Enter destroys the Overlay Session and opens the
  selected existing Search or Shiori target.
- Made Playlist Enter explicitly bypass Auto Play Cue Sequence segmentation so
  both Search and Shiori targets continue from Primary Cue Start Time. Ordinary
  Workbench and navigation-history playback retains its existing bounded-cue
  behavior.
- Rebound pending Playlist navigation across both generation changes and
  same-generation revision refreshes, while leaving background Playlist updates
  unable to disturb Current intent. Deferred actions survive a valid window
  replacement, reject invalid or empty targets, and cannot remain permanently
  interaction-blocking after the source becomes empty.
- Replaced the three window-hydration detached reads used by Playlist with the
  existing cancellation-propagating detached-task wrapper. Added cancellation
  checkpoints to visible and all-cue database search loops so Session teardown
  stops the worker instead of merely rejecting its late UI result.

### 7. Standalone Shiori Module

- Classified standalone Shiori as platform UI/session presentation over the
  existing persisted Shiori semantics. The module reads the established Core
  `created_at DESC, id DESC` order and Cue Presentation data without adding a
  second Shiori model, filter state, or Workbench row-store dependency.
- Added a Session-owned Shiori source and bounded window that are independent
  from the existing playback-origin Playlist. The source uses the exact Shiori
  count and cancellation-aware page reader, always creates a window even when
  the count is zero, and defaults a nonempty list to ordinal zero.
- Exposed the existing Playlist result-window transport under neutral Playback
  Cue Result names while preserving Playlist source identity, scope, and
  lifetime. Playlist and Shiori now mount the same shared Result overlay,
  native Reel, 32-item window policy, Focus Anchor, wheel, scrollbar, keyboard,
  settlement, measurement, drawing, and recycling implementation.
- Made Sequence Number a Result-module presentation policy. Playlist continues
  to render the one-based source ordinal; Shiori passes no Sequence Number.
  Both modules use the same persistent Show Cue Group state and cache
  invalidation without changing item identity, Primary Cue identity, selection,
  or data order.
- Generalized Session Result routing by module for selection commits, pending
  identity, remote keyboard targets, snapshot observation, motion, scrollbar
  state, and deferred actions. Each module retains its own loaded window and
  selected ordinal across Tab or sidebar transitions, and stale callbacks from
  a disappeared module cannot mutate the currently selected module.
- Added Shiori Up/Down and the shared S/C/Enter contract. S recognizes every
  displayed Shiori as already saved without writing; C targets only the Primary
  Cue; Enter destroys the Overlay Session and opens the existing Shiori target
  for continuous playback. Standalone Shiori Enter explicitly passes a nil
  navigation scope, restoring the complete database order instead of inheriting
  a playback-origin Playlist's explicit Workbench scope.
- Refresh the Session-owned Shiori boundary after a successful Current or
  Playlist save so a newly saved Primary Cue appears at the head of Shiori
  without reopening the Overlay. A transition from zero to one creates the
  first selection and advances source generation before the new page loads.
- Unified teardown now cancels both Result-window observers and loads, clears
  their items and selections, invalidates only the Session-owned Shiori source,
  releases all module references, and leaves the playback-origin Playlist
  source available for a later Overlay Session.

### 8. Workbench Search Live Input

- Changed the Workbench Search Box from Return submission to live query input.
  The Search field no longer receives an `onSearchSubmit` action, so Return is
  consumed by the field without starting a second immediate search.
- Routed only user edits and Inline Clear through a dedicated Binding setter.
  Programmatic draft synchronization from URL Scheme, navigation restoration,
  existing Search state, or Cue Context setup bypasses the setter and therefore
  cannot replace those immediate searches with a debounced request.
- User input exits any active Cue Context, clears its stored one-shot request
  and empty-query suppression, preserves the existing injected filters, and
  calls the existing `updateSearchQuery` path with the original input text.
  Empty input uses the same path, cancelling pending work and resetting Search
  before the Workbench selects its empty or filter-only presentation.
- Replaced the former 250-millisecond delay with the documented named
  100-millisecond input debounce. Pagination, URL Scheme, navigation history,
  and other explicit `debounce: false` entry points remain immediate.
- Preserved the existing visible-page then Exact-completion search pipeline and
  its cumulative Playlist refresh. Visible and Exact database workers now use
  cancellation-propagating detached execution, while visible publication,
  Exact progress, Exact final publication, and Exact failure all validate the
  current result-list generation in addition to query and filter state.
  Therefore rapid repeated text such as `foo -> bar -> foo` cannot accept
  progress from the first `foo` run into the latest run.

### 9. Playback Search Module

- Added an independent Session-owned Playback Search store. It captures the
  opening Search scope, language, watch-state, and filter configuration without
  reading from or publishing into Workbench Search query, results, counts, or
  navigation state. User input uses the same named 100-millisecond debounce;
  every query revision synchronously cancels the prior debounce, visible read,
  Exact read, source, window, selection, and retained data.
- Reused the established visible-page then Exact-completion pipeline with a
  unique run identity, cumulative Exact progress, and generation-validated
  publication. Repeated text such as `foo -> bar -> foo` cannot accept the
  first run's late result. Every accepted boundary resets selection to the
  first Result and cancels stale Reel navigation or motion intent.
- Added an optional Core Exact-progress result limit. Its default remains
  unlimited for Workbench compatibility; Playback Search passes the standard
  32-item Reel window size. Exact still retains the complete lightweight Cue ID
  order, count, and file summaries, while hydrated Result objects and known
  identity publication remain bounded to one window.
- Mounted Search through the shared Playback Cue Result overlay, item adapter,
  dynamic-height measurement, Focus Anchor, scrollbar, motion, recycling, and
  32-item virtual window. Search shows no Sequence Number, uses the persistent
  Show Cue Group setting, and adds only a fixed-dark Playback Search Box above
  the Reel with the existing Search Box geometry, icon, placeholder, and clear
  affordance tokens.
- Kept the Search Box focused while Up and Down drive the Result Reel. Tab and
  Escape retain their global Overlay meanings; Enter acts only on an already
  loaded and settled Result. Ordinary text, S, C, Space, native Command-A/C,
  and marked-text IME input stay with the editor. Clear removes the query and
  restores editor focus without adding a Focus Ring or focused color change.
- Search Enter transfers the exact same run and source into the existing
  playback-origin Playlist before destroying the Overlay Session. Ownership
  transfer lets an in-flight Exact completion continue updating Playlist; an
  unpromoted dismissal cancels it. Source replacement or Playback stop still
  invalidates the transferred source and cancels all work.
- Bound the promoted source's immutable query and scope to its source origin,
  and stored the current playback cursor as the authoritative Playlist ordinal.
  Subsequent Playlist Enter and Playback Previous/Next reuse that same source,
  query, scope, count, and order instead of falling back to Workbench Search or
  assuming `SubtitleSearchResult.searchRank` is the Playlist cursor.
- Added a Playback-specific adjacent-navigation task and current-source
  boundary subscription. Exact total changes refresh Chrome availability;
  generation or revision changes during a window read retry only against the
  newer boundary. Source replacement, cursor change, a newer navigation intent,
  or Playback stop rejects late responses without affecting Workbench Search's
  independent navigation task.
- Unified Session teardown now cancels the Search query debounce, source and
  window observations, virtual-window load, motion, selection, and retained
  Results, then clears the query and module references. Reopening creates a new
  empty Search state; no Search Session state survives Overlay dismissal.

### 10. Recent Module

- Classified Recent as Session-owned platform UI/UX over the existing Library
  history semantics. Its lazy loader reads the same complete Recent Watching
  dataset and database order as the Workbench surface without reading from or
  publishing into the Workbench Library route, status, items, selection, or
  scroll state.
- Reused the existing Recent Watching adaptive grid and card instead of adding
  a Playback-specific card design. The Overlay adds only the established Focus
  Ring selection treatment and frame reporting; existing hover, pointer,
  availability, context-menu, and watch-state behavior remains owned by the
  shared card. Accepted watch-state mutations trigger an independent Overlay
  snapshot refresh; returning after a mutation completed in another module also
  rereads the snapshot while preserving Session selection and scroll position.
  Load generation and requested-source revision gate both success and failure;
  a revision change during an in-flight read replaces or follows that read, and
  a cancelled late task cannot overwrite the latest snapshot or task state.
- Added a Session-local media selection model that defaults to the first
  available item, navigates the actual visible card geometry with an adaptive
  grid fallback for unloaded cards, and requests visibility after keyboard
  selection or grid-width changes. Module switches preserve selection, visible
  anchor, and exact native clip-view pixel offset.
- Added a native scroll-position bridge that observes and restores the exact
  AppKit clip-view offset while item anchors remain a content-change fallback.
  Attachment and restoration are cancellable and tolerate SwiftUI hierarchy
  and document-layout delay; the bridge mounts only after the Recent grid is
  available so a loading placeholder cannot consume restoration at offset zero.
- Routed Left, Right, Up, Down, and nonrepeating Enter only while Recent is the
  active module. Repeats are consumed without reopening; S and C remain no-ops.
  Keyboard Enter and an explicit card click share one dispatcher, and a click
  opens the clicked item rather than the previously selected item.
- Recent playback first validates the active Session and requested item, then
  destroys the Overlay synchronously. A guarded asynchronous transition loads
  the existing same-folder Library navigation scope and calls the established
  Library video opening path, preserving saved position, display title,
  playback history, Chrome state, and previous/next behavior. An in-flight gate
  prevents reopening the Overlay, and generation/source validation rejects a
  late transition after playback state changes.
- Module switching retains an in-flight Recent load, while Overlay dismissal,
  playback close, or source replacement cancels it, clears every retained item
  and selection field, and releases the store. Recent and complete-folder Core
  readers now propagate task cancellation during row iteration; the Recent
  Session task also avoids retaining its store across the database await.

### 11. Library Module

- Classified Library as Session-owned platform UI/UX over the existing complete
  Library semantics. Its independent lazy loader opens its own database reads
  through the established complete-folder summary and detail APIs, preserving
  their order and presentation without reading from or publishing into the
  Workbench Library route, load status, hierarchy, selection, or scroll state.
- Reused the existing Folder and Episode grids instead of adding Playback-only
  cards. Optional selection, item-frame reporting, and passive Focus Rings were
  added without changing Workbench defaults: Folder hover, click, and context
  menu still cover the full card, while Episode playback and context actions
  remain restricted to the existing Cover Region.
- Added an independently lazy two-level Session store. Folder and Detail each
  own their task, generation, requested revision, loaded revision, data,
  selection, and exact scroll offset. Entering a Folder creates fresh Episode
  state with the first available item selected; Back cancels and clears only
  Detail, restoring the exact Folder selection and pixel offset.
- Refreshes use the current Folder and playback-history revisions only as
  invalidation signals. Matching in-flight reads are retained; changed
  revisions reload the affected level, preserve a still-valid selection and
  exact offset, reject stale success and failure, and return to Folder level if
  the open Folder no longer exists.
- Rendered Folder as the existing adaptive grid with a 32-point outer inset.
  Detail keeps the existing header fixed above its independent Episode
  ScrollView and composes the same 32-point outer inset across header and list.
  Left, Right, Up, and Down use the shared media selection model; nonrepeating
  Enter enters the selected Folder or opens the selected Episode. Repeats are
  consumed, while S and C remain no-ops.
- Kept exact AppKit clip-view restoration separate for Folder and Detail. A
  pending selection request now suppresses old-offset restoration for that
  bridge lifetime, scrolls the requested card after layout, and acknowledges
  the request only afterward, so delayed bridge attachment cannot move a newly
  selected item back out of view.
- Keyboard Enter and explicit Episode clicks share one validated dispatcher.
  It captures the currently open Folder's existing ordered videos, installs
  that Folder as the previous/next navigation scope, synchronously destroys the
  Overlay Session, and calls the established Library opening path with its
  saved position, display title, history, and playback behavior unchanged.
- Module switching preserves both levels and their in-flight work. Overlay
  dismissal, playback close, or failed Session creation cancels both levels,
  clears their retained hierarchy and selection state, and releases the store.
  Complete-folder Core readers now reject pre-cancelled tasks and cooperate
  with cancellation during row iteration.

### 12. Cross-Module Integration, Cancellation, and E2E Gate

- Added a real temporary-SQLite integration fixture that traverses Current,
  Playlist, live Playback Search, Recent, both Library levels, and Shiori in one
  Session. It verifies each module's independent selection, query, hierarchy,
  bounded window, and exact scroll state, then destroys every reference and
  confirms that a later Session starts from documented defaults.
- Added deterministic suspended-worker integration coverage for Current initial
  and complete Cue loads, Playlist, Playback Search, Recent, Library Folder and
  Detail, and Shiori. Playback stop must cancel every task, invalidate owned
  sources and windows, clear all Session state, and reject each loader's result
  even after the cancellation probe deliberately returns it late.
- Kept the Current loader test seam internal and optional. The production path
  still resolves the existing database actor; tests inject only the two Cue
  loader closures needed to suspend the same Coordinator task and publication
  gates deterministically.
- Made Result-window selection retain the selected stable item identity
  independently from the current 32-item virtual window. A Shiori prepend now
  shifts the known identity boundary and restores the previous selected Result
  at its new ordinal even when that Result had already been paged out of the
  retained window.
- Added cooperative cancellation before and during complete Current Cue row
  iteration. A 2,500-row database test cancels on row 32 and uses a thread-safe
  probe to prove that row 33 is never read, distinguishing true mid-iteration
  cancellation from an entry-only or end-of-loop check.
- Replaced the superseded Subtitle Focus keyboard acceptance text in the active
  testing rules and added a complete packaged Playback Multi-Module Overlay E2E
  gate. The gate includes deterministic source-growth and cancellation
  prerequisites, marked log capture with exact failure predicates, mechanical
  Playlist count/order ledgers, real IME and pointer checks, per-module
  before/after state evidence, strict new-Session defaults, and cleanup.
- Added the completed feature outcome to the engineering changelog without
  changing either human-owned requirement or UI document.

## Verification

### Step 1

- `swift test --filter playbackOverlay`
  - Passed 7 new module, lifecycle, keyboard, and token tests.
- `swift test --filter subtitleFocus`
  - Passed 61 existing Subtitle Focus regression tests.
- `swift test`
  - Passed 7 XCTest tests and 642 Swift Testing tests.
- `git diff --check`
  - Passed.

### Step 2

- `swift test --filter subtitleFocus`
  - Passed 64 tests, including strict hard/soft line gaps, CRLF/CR, empty and
    trailing lines, fallback-font metrics, oversized clipping, and existing
    50,000-cue virtualization coverage.
- `swift test`
  - Passed 7 XCTest tests and 645 Swift Testing tests.
- `swift test --filter subtitleFocusVisualLineStack`
  - Passed the 3 focused strict-gap and resolved-font-run tests after the final
    cross-version assertion hardening.
- `git diff --check`
  - Passed.

### Step 3

- `swift test --filter playbackVirtualReel`
  - Passed 24 shared-reel tests covering 50,000-item bounded work, empty and
    partial snapshots, stable identity, generation and revision rejection,
    adapter replacement, pending-window reissue, latest-intent selection,
    discrete and precise wheel window loading, rejected commits, exact remote
    scrollbar preview, and preview cancellation.
- `swift test --filter subtitleFocus`
  - Passed all 64 Current regression tests.
- `swift test`
  - Passed 7 XCTest tests and 669 Swift Testing tests.
- `git diff --check`
  - Passed.

### Step 4

- `swift test --filter playbackCueResult`
  - Passed 11 tests covering tokens, mixed typography and resolved font runs,
    hard/soft lines, role-aware empty and trailing lines, strict five-point
    boundaries, whole-stack centering, Show Cue Group identity stability,
    Sequence Number width/color/baseline, oversized clipping, bounded cache
    invalidation, and 50,000-item shared-Reel virtualization.
- `swift test --filter subtitleFocus`
  - Passed all 64 Current regression tests after the Visual Line Stack gained
    mixed-segment support.
- `swift test --quiet --skip sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed 7 XCTest tests and the other 679 Swift Testing tests.
- `swift test --filter sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed the isolated persistence migration test.
- `swift test --quiet`
  - One combined run passed 7 XCTest tests and all 680 Swift Testing tests.
    Two later combined reruns exposed an existing order-dependent
    `ApplicationPersistenceTests` failure: another test's registered
    `workbenchPanelMode = search` default was visible instead of the isolated
    fixture's legacy `shiori` value. The test passes alone, all other 679 tests
    pass together, and Step 4 does not change persistence code or tests.
- `git diff --check`
  - Passed.

### Step 5

- `swift test --filter PlaybackPlaylist`
  - Passed 11 source mapping, existing Search exact-progress, Shiori scope,
    generation/revision, 50,000-item bounded-window, stale-response, and two-level
    lifecycle tests.
- `swift test --filter shioriPageForIDs`
  - Passed the ordered, deduplicated, missing-ID, empty-input, and Cue
    Presentation Core batch test.
- `swift test --filter SearchStore`
  - Passed 11 existing Search source, count-progress, distant-window, all-cue,
    navigation, and identity regressions.
- `swift test --filter subtitleFocus`
  - Passed all 64 Current Subtitle Focus regressions.
- `swift test --filter shiori`
  - Passed all 16 matching Shiori and new Playlist-scope tests.
- `swift test --quiet`
  - Passed 7 XCTest tests and all 692 Swift Testing tests.
- `git diff --check`
  - Passed.

### Step 6

- `swift test --filter 'PlaybackPlaylist|visibleSearchReadersRejectPreCancelledTasks|appCoordinatorOnlyBoundsCuePlaybackWhenAutoSwitchIsEnabled'`
  - Passed 28 tests covering the shared Playlist adapter and rendered View,
    32-item and 50,000-item windows, module-state preservation, source refresh
    rebinding, distant scrollbar actions, empty-boundary cleanup, Session worker
    cancellation, Primary Cue actions, continuous Enter playback, and strict
    Session destruction.
- `swift test --filter 'subtitleFocus|playbackVirtualReel|PlaybackSegmentCompletion|SearchStore'`
  - Passed 110 shared-Reel, Current, Search, keyboard-action, playback-segment,
    and lifecycle regression tests.
- `swift test --quiet`
  - Passed 7 XCTest tests and all 711 Swift Testing tests.
- `git diff --check`
  - Passed.

### Step 7

- `swift test --filter 'playbackShiori|playbackPlaylistAndShiori'`
  - Passed 12 standalone Shiori tests covering canonical database order,
    50,000-item bounded loading, empty and first-selection states, no Sequence
    Number, Cue Group identity stability, shared-Reel View rebinding, independent
    Playlist/Shiori windows, remote settled actions, late-module callback
    isolation, idempotent S, independent Enter scope, save refresh, and strict
    cancellation/destruction.
- `swift test --filter 'PlaybackPlaylist|playbackShiori|playbackPlaylistAndShiori|subtitleFocus|playbackVirtualReel|PlaybackSegmentCompletion|SearchStore'`
  - Passed 147 Shiori, Playlist, Current, shared-Reel, Search, action, playback,
    and lifecycle regression tests.
- `swift test --quiet --skip sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed 7 XCTest tests and the other 722 Swift Testing tests.
- `swift test --filter sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed the isolated persistence migration test.
- `swift test --quiet`
  - The final combined run passed all 7 XCTest tests and 722 of 723 Swift
    Testing tests. The one failure was the already-recorded order-dependent
    `ApplicationPersistenceTests` case from Step 4: another parallel test's
    registered `workbenchPanelMode = search` value was visible instead of the
    isolated fixture's legacy `shiori` value. It passes alone; Step 7 does not
    modify persistence code or tests.
- `git diff --check`
  - Passed.

### Step 8

- `swift test --filter 'searchInputDebounceIsOneHundredMilliseconds|liveSearchUsesLatestInputAndClearsWithoutSubmit|staleExactProgressCannotPublishIntoRepeatedQueryText'`
  - Passed 3 focused tests covering the exact 100-millisecond setting,
    latest-input cancellation, live results without submission, empty-query
    reset, and repeated-query generation rejection.
- `swift test --filter 'SearchStore|URLSchemeSearchRouting|searchPlaybackPlaylistFollowsExactProgressInsteadOfFreezingClickedRows'`
  - Passed 20 Search, URL Scheme immediate-routing, Cue Context, Exact progress,
    and Search-origin Playlist regression tests.
- `swift test --filter 'SearchStore|URLSchemeSearchRouting|PlaybackPlaylist|playbackShiori|playbackPlaylistAndShiori|subtitleFocus|playbackVirtualReel|PlaybackSegmentCompletion'`
  - Passed 156 Workbench Search, Playlist, Shiori, Current, shared-Reel,
    URL Scheme, action, and playback lifecycle regression tests.
- `swift test --quiet --skip sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed all 7 XCTest tests and the other 725 Swift Testing tests.
- `swift test --filter sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed the isolated persistence migration test.
- `swift test --quiet`
  - The combined run passed all 7 XCTest tests and 725 of 726 Swift Testing
    tests. The one failure was the already-recorded order-dependent
    `ApplicationPersistenceTests` case from Step 4: another parallel test's
    registered `workbenchPanelMode = search` value was visible instead of the
    isolated fixture's legacy `shiori` value. It passes alone; Step 8 does not
    modify persistence code or tests.
- `git diff --check`
  - Passed.

### Step 9

- `swift test --filter PlaybackSearch`
  - Passed 9 tests covering latest-run publication, the production
    100-millisecond debounce, debounce cancellation on Session dismissal,
    bounded 32-item hydration, full Cue ID retention, strict teardown, Search
    keyboard and IME routing, complete Enter promotion, Exact ownership
    transfer, Workbench isolation, Playlist re-entry, ordinal-based adjacent
    navigation, Chrome count refresh, stale-generation retry, and late-response
    rejection after Playlist source replacement.
- `swift test --filter searchPageEmitsExactProgressCountSnapshotsBeforeFinalExactCounts`
  - Passed the 5,100-result Core Exact-progress test with at most 32 hydrated
    Results, ordered rank `0..<32`, complete ordered known Cue ID prefixes, and
    the full final Cue ID order and count.
- `swift test --quiet --filter 'playbackSearch|PlaybackSearch|playbackPlaylist|PlaybackPlaylist|subtitleFocus|SubtitleFocus|searchInput|liveSearch|PlaybackNavigation'`
  - Passed 160 Playback Search, Playlist, Current, shared-Reel, Workbench live
    Search, navigation-history, action, and lifecycle regression tests.
- `swift build`
  - Passed.
- `swift test --quiet --no-parallel --skip sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed all 7 XCTest tests and the other 734 Swift Testing tests, including
    the Native Playback presentation cases that can miss their frame deadline
    when the complete suite runs concurrently.
- `swift test --filter sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed the isolated persistence migration test.
- `swift test --quiet --no-parallel`
  - The combined serial run passed all 7 XCTest tests and 734 of 735 Swift
    Testing tests. The one failure was the already-recorded order-dependent
    `ApplicationPersistenceTests` case from Step 4: a registered
    `workbenchPanelMode = search` default was visible instead of the isolated
    fixture's legacy `shiori` value. It passes alone; Step 9 does not modify
    persistence code or tests.
- Three Native Playback frame-presentation cases that failed only during
  concurrent full-suite attempts all passed individually and in the complete
  serial run. Step 9 does not modify the native playback pipeline or tests.
- `git diff --check`
  - Passed.

### Step 10

- `swift test --filter 'PlaybackRecent|playbackRecent|playbackMedia|recentLibraryWatchingRejectsPreCancelledTasks'`
  - Passed 11 tests covering the complete production Recent dataset, first
    available selection, adaptive and visible-frame navigation, exact pixel
    offset restoration and observation, module-state preservation, independent
    snapshot refresh without selection or offset loss, stale success and failure
    rejection across revision races, strict load cancellation and release,
    pre-cancelled Core reads, keyboard teardown and re-entry gating, and explicit
    clicked-item playback with same-folder navigation and saved-position
    restoration.
- `swift test --quiet --filter 'PlaybackRecent|playbackRecent|playbackMedia|PlaybackSearch|playbackSearch|PlaybackPlaylist|playbackPlaylist|playbackShiori|playbackPlaylistAndShiori|subtitleFocus|SubtitleFocus|PlaybackNavigation|Library'`
  - Passed 213 Recent, Library, Search, Playlist, Shiori, Current, navigation,
    action, and lifecycle regression tests.
- `swift build`
  - Passed.
- `swift test --quiet --no-parallel --skip sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed all 7 XCTest tests and the other 745 Swift Testing tests.
- `swift test --filter sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed the isolated persistence migration test.
- `swift test --quiet --no-parallel`
  - The combined serial run passed all 7 XCTest tests and 745 of 746 Swift
    Testing tests. The one failure was the already-recorded order-dependent
    `ApplicationPersistenceTests` case from Step 4: a registered
    `workbenchPanelMode = search` default was visible instead of the isolated
    fixture's legacy `shiori` value. It passes alone; Step 10 does not modify
    persistence code or tests.
- `git diff --check`
  - Passed.

### Step 11

- `swift test --filter 'playbackMediaSelection|playbackLibrary|playbackRecent'`
  - Passed 15 Library, Recent, and shared media-selection tests covering both
    hierarchy levels, Workbench-compatible database order, independent Session
    state, revision refresh, stale success and failure rejection, Back and
    module restoration, keyboard routing, explicit Episode dispatch, current
    Folder navigation scope, and strict teardown.
- `swift test --filter playbackMediaScrollBridge`
  - Passed 2 native bridge tests covering exact pixel restoration and the
    pending-selection precedence that suppresses a stale offset while retaining
    scroll observation.
- `swift test --quiet --filter 'PlaybackLibrary|playbackLibrary|playbackMedia|PlaybackRecent|playbackRecent|Library|completeLibrary'`
  - Passed 54 complete Library, Recent, selection, navigation, cancellation,
    reusable-layout, persistence, and playback regression tests.
- `swift build`
  - Passed.
- `swift test --quiet --no-parallel --skip sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed all 7 XCTest tests and the other 753 Swift Testing tests.
- `swift test --filter sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed the isolated persistence migration test.
- `swift test --quiet --no-parallel`
  - The combined serial run passed all 7 XCTest tests and 753 of 754 Swift
    Testing tests. The one failure was the already-recorded order-dependent
    `ApplicationPersistenceTests` case from Step 4: a registered
    `workbenchPanelMode = search` default was visible instead of the isolated
    fixture's legacy `shiori` value. It passes alone; Step 11 does not modify
    persistence code or tests.
- Two independent read-only final reviews found no P0, P1, or P2 code, Session
  lifecycle, asynchronous-state, playback-dispatch, or UI interaction issues.
- `git diff --check`
  - Passed.

### Step 12

- `swift test --filter 'subtitleFocusDatabaseBatchStopsAfterCancellationDuringRowIteration|playbackMultiModuleOverlayStopCancels|playbackShioriSavePreservesSelectedResultIdentityAfterPrepend'`
  - Passed 4 focused tests covering cross-window Shiori identity restoration,
    Current initial and complete task cancellation, Library Folder and Detail
    cancellation, all other module workers, late-result rejection, and an exact
    row-32 database cancellation boundary.
- `swift test --filter 'searchPlaybackPlaylistFollowsExactProgressInsteadOfFreezingClickedRows|playbackSearchEnterPromotesRunningExactSourcePastSessionTeardown|playbackLibraryRejectsStaleDetailSuccessFailureAndDismissal|playbackMultiModuleOverlayStopCancels'`
  - Passed all 5 deterministic E2E prerequisite tests named by the manual gate.
- `swift test --quiet --no-parallel --filter 'playbackOverlay|PlaybackOverlay|subtitleFocus|SubtitleFocus|playbackVirtualReel|PlaybackVirtualReel|playbackCueResult|PlaybackCueResult|playbackPlaylist|PlaybackPlaylist|playbackSearch|PlaybackSearch|playbackRecent|PlaybackRecent|playbackLibrary|PlaybackLibrary|playbackShiori|PlaybackShiori|playbackMultiModule|PlaybackMultiModule|playbackMedia|PlaybackMedia|SearchStore|searchInputDebounce|liveSearch'`
  - Passed all 196 Overlay, Current, shared-Reel, Cue Result, Playlist, Search,
    Recent, Library, Shiori, media-selection, Workbench Search, action, and
    lifecycle regression tests. One first attempt hit an existing short Shiori
    hydration deadline; that test passed immediately in isolation and the full
    matrix rerun passed.
- `swift build`
  - Passed.
- `scripts/verify_macos_media_runtime.sh .build/media-runtime/arm64-macos13`
  - Passed.
- `scripts/package_macos_app.sh --output /private/tmp/CueSeeker-Overlay-E2E.app`
  - Passed the production build, bundled-dylib closure, code-signing,
    Designated Requirement, self-contained runtime, and ARM64 checks.
- Packaged-app launch smoke
  - `/private/tmp/CueSeeker-Overlay-E2E.app` launched as the real CueSeeker
    process and was then closed cleanly. This proves startup only; it is not
    recorded as the manual interaction gate.
- `swift test --quiet --no-parallel --skip sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed all 7 XCTest tests and the other 759 Swift Testing tests.
- `swift test --filter sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed the isolated persistence migration test.
- `swift test --filter showCueGroupInvalidationIsScopedToMountedContext`
  - Passed the isolated mounted Show Cue Group integration test.
- `swift test --quiet --no-parallel`
  - The combined serial run passed all 7 XCTest tests and 758 of 760 Swift
    Testing tests. The already-recorded order-dependent persistence case saw a
    registered `workbenchPanelMode = search` default instead of its isolated
    `shiori` fixture. The mounted Show Cue Group integration also missed its
    three-second table-hydration deadline only in this 116-second combined run.
    Both pass alone, the complete 759-test run excluding the known persistence
    case passes, and Step 12 changes neither persistence nor Workbench table
    mounting behavior.
- Two independent final code/test reviews found no remaining P0, P1, or P2
  production-semantic, concurrency, lifecycle, or coverage issue after the
  cross-window identity and complete cancellation matrix were added.
- The final E2E-document review removed timing-dependent false failures, added
  explicit inconclusive/retry rules and executable Search/Shiori count bridges,
  and found no remaining P0, P1, or P2 after the corrections.
- `git diff --check`
  - Passed.

### Completion audit correction: Workbench Shiori Playlist scope

- The completion audit found that Workbench Shiori passed only
  `rowStore.snapshot.rows` into Playback. During continuous table hydration,
  that array is only the loaded prefix, so Playlist incorrectly froze before
  the visible `xx rows` boundary.
- Core now produces a cancellable `ShioriTableIDIndex` by streaming candidates
  in the existing `created_at DESC, id DESC` order. Search and Filter semantics
  still use the established Swift matchers; only matching `Int64` identities
  are retained. `shioriTablePage` uses the same scanner and materializes rich
  Shiori/Cue Group presentation only for its requested page, including an exact
  filtered count when `limit == 0`. The scanner uses an ID-only path for the
  unfiltered order, title/content fields for ordinary Search and Filter rules,
  and a dedicated primary-Cue Speaker path; Language metadata and full Cue
  records are loaded only when Language matching requires them. Speaker values
  use a lossless hex transport so embedded delimiter characters remain valid.
- The Workbench Shiori result run owns one UUID-addressed ordered ID snapshot.
  Its initial page establishes the exact `xx rows`; later continuous hydration
  slices that same snapshot and calls `shioriPage(shioriIDs:)`. A database
  mutation after the first page therefore cannot change the displayed run's
  count, membership, or ordinal order. Initial and continuous hydration now
  retain their task handles, so refresh, route departure, and teardown cancel
  the detached database work instead of merely ignoring its eventual result.
- `PlaybackPlaylistShioriScope.table` carries the result-run UUID and query
  provenance without hashing the complete ID array. Opening a Workbench Shiori
  transfers the same ordered identities into the durable playback-origin
  Playlist source. Every Playlist window batch is loaded by an exact ID slice,
  is rejected if an indexed item is missing or reordered, and still retains at
  most the shared Reel's 32 rich items. Replacing or clearing the source releases
  both the coordinator snapshot and the source's stable identities and loader
  closure.
- Playback from a prefix-external Playlist item and normal Shiori Previous/Next
  resolve adjacency from the same stable source index. A table-scoped item that
  is absent from that index fails closed instead of falling back to unfiltered
  database adjacency. Reopening within the same result UUID reuses the source;
  a new Workbench result UUID replaces and invalidates it.
- The database-backed regression uses 80 saved Shiori, only three initially
  hydrated rich rows, and a 40-row combined Search + Filter snapshot. It loads
  ordinal 35 through the standard `8..<40` window, retains 32 rich items,
  remains at 40 after a new matching Shiori is inserted, navigates to ordinal
  34 within the snapshot, rejects a batch after an indexed row is deleted, and
  rejects late reuse after result UUID replacement.
- Core regressions prove ID-index Search/Filter equivalence, Language-filtered
  slicing, exact filtered count-only pages, and row-iteration cancellation at
  candidate 32 in both ordinary and Speaker scans, pre-cancelled Workbench
  loads, and Speaker values containing the former delimiter character.
- `swift test --filter 'shioriPlaybackPlaylistTableScopeKeepsCompleteFilteredRowsBeyondLoadedPrefix|shioriTablePageAppliesSearchAndFiltersBeforeSlicing|shioriTableIDIndexStopsImmediatelyAfterCancellationDuringScan|shioriCuePresentationUsesDurableIdentityAndPrimaryCueMetadata'`
  - Passed all 4 focused snapshot, window, mutation, navigation, presentation,
    and cancellation regressions.
- `swift test --filter 'Shiori|shiori|Playlist|playlist|Navigation|navigation|Speaker|speaker'`
  - Passed all 129 Shiori, Playlist, Navigation, and Speaker regressions.
- `swift test`
  - Passed all 7 XCTest tests and all 762 Swift Testing tests.
- `swift build`
  - Passed.
- Three independent read-only reviews found no remaining correctness,
  lifecycle, concurrency, snapshot-ownership, or navigation issue. The one
  reported Speaker-only performance over-read was removed before this commit.
- `git diff --check`
  - Passed.

### Completion audit correction: Focus Ring and pointer Cursor

- The completion audit found that the shared `--focus-ring-width` metric still
  used the earlier 3-pixel implementation value even though the accepted UI
  design defines a 2-pixel width and a separate 2-pixel offset.
- The shared metrics now preserve width and offset as independent tokens. Focus
  Ring paths expand by `offset + width / 2`, so the visible inner edge remains
  exactly 2 pixels from its control while the stroke remains exactly 2 pixels.
  Workbench controls, native and SwiftUI table checkboxes, sortable headers,
  and the Recent, Library Folder, and Library Episode selection rings all use
  the same derived geometry. The native Checkbox border is inset by half its
  stroke width so it does not consume the documented Ring gap.
- The Shiori Tag private hover-cursor implementation moved into a shared
  modifier that balances AppKit Cursor stack changes on mouse exit, disabled
  state changes, and View teardown. Playback Module Sidebar Items and the
  Playback Search Inline Clear Button now use that modifier over their exact
  Button surfaces. The Clear Button explicitly exposes its complete 24-by-24
  token frame as the hit shape; Sidebar whitespace and the Search text input
  are unchanged.
- `swift test --filter 'workbenchFocusRingMetricsMatchDesignTokens|PlaybackMultiModuleOverlay|playbackMultiModule|PlaybackSearch|playbackSearch|ShioriTag|shioriTag|PlaybackRecent|playbackRecent|PlaybackLibrary|playbackLibrary'`
  - Passed all 36 Focus Ring token, Playback module, Search, Shiori Tag, Recent,
    and Library regressions.
- `swift test --filter 'workbenchFocusRingMetricsMatchDesignTokens|Checkbox|checkbox|PlaybackSearch|playbackSearch|PlaybackMultiModule|playbackMultiModule'`
  - Passed all 26 final Focus Ring, native and SwiftUI Checkbox, Search hit-area,
    and Overlay regressions after the visual-gap and hit-shape corrections.
- `swift test --quiet --skip sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed all 7 XCTest tests and the other 762 Swift Testing tests.
- `swift test --quiet --filter sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  - Passed the isolated known order-dependent persistence test documented in
    Step 12.
- `swift build`
  - Passed.
- `scripts/package_macos_app.sh --output /private/tmp/CueSeeker-Overlay-E2E.app`
  - Passed the latest production build, bundled-dylib validation, code-signing,
    Designated Requirement, self-contained runtime, and ARM64 checks.
- `git diff --check`
  - Passed.
- The independent test/document review found no P0, P1, or P2. The first final
  code review found the native Checkbox border-gap and Clear Button hit-shape
  details described above; both were corrected, and its read-only re-review
  found no remaining P0, P1, or P2.
- Cursor shape and ring appearance remain part of the owner-visible packaged
  app E2E because unit tests do not observe the system Cursor or rendered
  pixels.

## Outcome

All twelve implementation steps and automated verification are complete. The
packaged owner-visible manual UI E2E remains required before final acceptance;
the launch smoke above does not substitute for that interaction evidence.

## Follow-ups

- Run `Playback Multi-Module Overlay` in
  `docs/engineering/08_end_to_end_testing.md` against the packaged app and paste
  back actions 1 through 17, the marked log review, count/order ledgers,
  before/after screenshots, clipboard values, and recordings.
