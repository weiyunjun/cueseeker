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

## Outcome

In progress.

## Follow-ups

- Update Workbench Search to the documented 100ms live query before connecting
  Playback Search to the same result semantics.
