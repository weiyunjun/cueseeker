# Playback Multi-Module Overlay

## Human-Owned Source

- `docs/human/requirements/20260714-Feature-Playback Multi-Module Overlay.md`
- `docs/human/design/UI.md`

## Scope

Upgrade the playback Subtitle Focus surface into one temporary multi-module
overlay session. Preserve Current behavior while adding the shared shell,
strict session cleanup, shared virtual-reel infrastructure, Playlist, Search,
Recent, Library, and Shiori in independently verifiable implementation steps.

The repository does not currently contain a Playlist model or store. The shell
therefore accepts Playlist as an explicit session capability and does not infer
it from unrelated Search, Shiori, or Library previous/next navigation. The
capability will be enabled when the Playlist snapshot is implemented.

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

## Outcome

In progress.

## Follow-ups

- Define and capture the real Playlist data source and Overlay Session Snapshot
  contract before enabling Playlist in the sidebar.
- Connect Playlist and then Shiori through module adapters that feed this Result
  core into the shared Reel without creating independent or fully materialized
  lists.
- Update Workbench Search to the documented 100ms live query before connecting
  Playback Search to the same result semantics.
