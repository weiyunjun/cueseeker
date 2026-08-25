# Architecture Rules

Status: Draft

## 1. Purpose

This document defines architecture rules for the native macOS implementation of CueSeeker.

It is an engineering rule document, not a product requirements document.
Stable product behavior belongs primarily in `docs/human/design/`; derived
product documents must remain aligned with it.

## 2. Architecture Principles

The core native product workflow is implemented. The current architecture
priority is to improve incomplete details and remove architecture problems that
materially slow safe iteration.

Core principles:

- Preserve accepted product behavior while architecture boundaries are refined.
- Prefer small architecture steps that remove a demonstrated ownership,
  dependency, lifecycle, performance, or verification bottleneck.
- Prefer native macOS capabilities when they satisfy the product requirement.
- Keep persistent data local unless a future proposal explicitly changes that rule.
- Make hard-to-reverse technical decisions through ADRs before production implementation depends on them.
- Keep modules isolated enough that indexing, search, persistence, and playback can be tested independently.
- Avoid introducing remote services, sync layers, or broad cross-platform
  abstractions without an accepted proposal or ADR. The accepted shared-core
  direction below is the explicit exception for CueSeeker product-domain
  behavior.

## 2.1 Shared Core Direction

The shared-core architecture direction is accepted in
`docs/proposals/2026-05-shared-core-architecture-plan.md`.

Rules:

- CueSeeker should keep native UI shells per platform.
- CueSeeker should move shared product-domain behavior into a shared core where
  doing so prevents macOS and Windows from reimplementing the same rules.
- Rust is the preferred shared-core implementation language.
- Rust shared-core implementation work remains paused during the current native
  macOS architecture-refinement phase. This architecture work does not restart
  Rust migration. During the pause, macOS code must still be written along the
  future shared-core boundary so later extraction remains practical.
- The first shared-core migration phase is limited to database, folder
  indexing, subtitle parsing, subtitle-to-video matching, Search, Library,
  Shiori, and playback intent resolution.
- The first shared-core migration phase must not migrate playback rendering,
  video decode, audio output, native renderer surface ownership, fullscreen
  behavior, DPI behavior, or platform window management.
- macOS is the first acceptance platform for shared-core migration. Windows
  should not require parallel manual architecture acceptance until the migrated
  shared-core behavior has passed macOS production acceptance.
- The current macOS implementation is the behavioral fact standard for the
  migrated shared-core domain modules until a later accepted document changes
  that behavior.
- Windows should consume the shared core only after macOS acceptance of the
  migrated domain modules, except for isolated build or blocker-level playback
  fixes that do not change shared product semantics.

## 2.2 Future Shared-Core Boundary While macOS Leads

macOS remains the primary product-development platform while Rust shared-core
implementation is paused. This pause must not turn macOS-only code into a
catch-all implementation where future shared-core semantics are buried in UI or
playback execution.

Rules:

- New macOS features must be classified before implementation as product
  semantics, platform UI and UX, platform integration, or playback execution.
- Product semantics must live in `CueSeekerCore` or a similarly isolated
  product-domain module, even when implemented in Swift first. This includes
  database state, migrations, indexing rules, matching rules, parser search
  projections, Search behavior, Library behavior, Shiori identity and
  persistence, alias contracts, and playback intent resolution.
- SwiftUI and AppKit code may coordinate workflows and render view models, but
  must not become the only place where database, indexing, Search, Library,
  Shiori, naming, alias, or playback-intent rules are enforced.
- `CueSeekerPlayback` and native playback code may own media open, decode,
  render, audio, subtitle overlay execution, fullscreen, resize, and memory
  lifecycle, but must not own Search, Library, Shiori, indexing, matching, or
  product identity semantics.
- Playback features that may later become cross-platform must split durable
  product meaning from platform execution. The durable intent or command shape
  belongs in the product-domain layer; actual seek, decode, render, composite,
  file export, and native resource release remain in the platform playback
  backend.
- Do not add new Rust shared-core scaffold, fixtures, FFI, shadow-mode code, or
  production replacement while this pause is active unless the project owner
  explicitly restarts the shared-core migration.
- When the correct boundary is unclear, document the decision before
  implementation. The default bias is to keep durable product meaning in the
  product-domain layer and keep presentation, OS integration, and playback
  execution in platform layers.

## 2.3 Architecture Refinement

Architecture refinement is current product-development work, not a license for
broad speculative rewrites.

Rules:

- Start from a concrete development bottleneck, unclear ownership boundary,
  recurrent regression, or verification problem.
- Preserve accepted behavior unless the current committed requirement
  explicitly changes it.
- Split work into the smallest independently verifiable steps and use test,
  measurement, or focused manual evidence to decide the next step.
- Let repeated implementation and verification refine uncertain details. Do
  not require exhaustive up-front documentation for commonplace implementation
  choices that introduce no CueSeeker-specific behavior or constraint.
- Do not add abstractions solely for hypothetical flexibility or to prepare
  inactive Rust implementation work.

## 2.4 Minimum Sufficient Design

Rules:

- Use the smallest design and change set that satisfies the current committed
  human-owned requirement.
- Reuse an existing source of truth, state, or execution path when it is
  sufficient. Add abstractions, caches, duplicate state, or compatibility paths
  only when the current requirement needs them.
- Keep independent data migration, ownership, UI lifecycle, and performance
  changes separately verifiable unless the requirement explicitly combines them.
- When multiple designs meet the same acceptance criteria, choose the one with
  fewer types, states, execution paths, and modified files.

## 3. Target Platform

Primary platform:

- macOS.

Minimum supported version:

- macOS 13.0 Ventura, provisional.

Rules:

- The app must not depend on Flutter for active native implementation.
- The active native app must live under `apps/macos-native/`.
- Raising the minimum macOS version requires updating product and engineering documentation.
- If a newer minimum version is required by a playback, sandboxing, or UI decision, that decision must be recorded before implementation depends on it.

## 4. Application Stack

The initial native rewrite should use native macOS development tools.

Required stack decisions before implementation:

- UI framework choice.
- Application architecture pattern.
- SQLite access strategy.
- Playback engine strategy.
- Dependency management strategy.
- Sandbox and file-access strategy.
- Packaging and distribution expectations.

Default assumptions until a more specific document or ADR replaces them:

- UI should use native macOS frameworks.
- Persistent search data should use SQLite with FTS5.
- Remote services are out of scope.
- Local file access is central to the app and must be designed explicitly.

Accepted ADRs:

- ADR-0002 selects Swift, SwiftUI, AppKit bridges, Swift Package Manager, SQLite with FTS5, and a project-owned persistence layer for M1.
- ADR-0007 supersedes ADR-0006 and ADR-0003 and selects native-only playback.
- ADR-0011 supersedes ADR-0010 and selects main-window video-only presentation
  using AppKit native fullscreen behavior for playback fullscreen.
- ADR-0004 disables App Sandbox for M1 local development and personal builds.
- ADR-0009 selects `libass` as the only active ASS playback renderer and
  removes the previous native ASS renderer direction from production playback.

## 5. Module Boundaries

The native app should be organized around clear engineering responsibilities.

Expected responsibility areas:

- App shell and window lifecycle.
- Folder selection and file access.
- Subtitle scanning.
- Subtitle parsing.
- Video matching.
- Database persistence and migrations.
- Full-text search.
- Playback.
- Settings and local configuration.
- Error reporting and logging.

Rules:

- Subtitle parsing must not depend on UI state.
- Database persistence must not depend on playback UI state.
- Search must read from the database/index layer, not directly from arbitrary subtitle files.
- Playback must receive a resolved local video path and timestamp, not perform subtitle parsing itself.
- UI state may coordinate workflows, but it must not be the only place where indexing or database rules are enforced.
- Any new macOS product behavior that could later be shared with Windows must
  be implemented behind a product-domain boundary instead of being embedded
  directly in SwiftUI views, AppKit bridges, or native playback classes.

### 5.1 Database Domain Boundaries

The accepted database decomposition is defined in
`docs/proposals/2026-07-database-architecture-decomposition.md`.

Rules:

- `CueSeekerCore` owns database bootstrap, schema validation, indexing,
  Search, Library, Shiori, playback-subtitle data, AI cache, and maintenance
  semantics, but these responsibilities must not be exposed through one
  cross-domain database type.
- Feature callers must depend on the smallest relevant database-domain
  boundary instead of a concrete all-capabilities database object.
- Schema creation and validation run only through database bootstrap. Search,
  Library, playback, and other ordinary readers must not migrate or create the
  production database.
- SQLite write transactions must have one explicit serialized owner. A logical
  transaction must not be interleaved with another operation on the same
  connection.
- Read-heavy feature work should use read-only connections or feature-owned
  reader sessions that can coexist with WAL writes.
- Playback rendering must receive resolved playback-subtitle data or a minimal
  provider. It must not receive a database path or open SQLite directly.
- Derived Search and Library projection rebuilds belong to their persistence
  workflow and must not remain public AppCoordinator maintenance calls.
- Migration to these boundaries must remove superseded methods and temporary
  adapters in the same accepted step. A permanent forwarding facade is not an
  accepted final architecture.

## 6. Data Flow

The M1 local loop should follow this conceptual flow:

```text
Selected folders
Scan supported external subtitle files
Parse subtitle cue groups and cue lines
Match local video files
Persist metadata, cue groups, and cue lines
Update FTS index
Search indexed text
Open matched video at start_ms
```

Rules:

- Source subtitle files remain the source of truth for indexed subtitle content.
- The SQLite database is an indexed local cache plus local app state, not a replacement for the source files.
- ASS indexing preserves cue groups as derived relationships while Search,
  Shiori, and playback actions use individual cue lines as their
  product identity.
- SRT blocks should map to cue groups with one cue line.
- ASS `Dialogue` events should map to cue groups and cue lines.
- ASS cue grouping must use exact subtitle file, `start_ms`, and `end_ms`
  equality. Timestamp tolerance grouping is out of scope for the first ASS step.
- Search may use cue-group aggregate text for recall, but every returned Cue
  must satisfy line-level query semantics so terms split only across different
  cue lines do not create a match. Optional Cue Group context is a presentation
  projection and must not replace the primary Cue identity.
- Workbench Shiori filtering must reuse Search's line-level query semantics
  against the resolved primary Cue only. Display Title and optional Cue Group
  context are presentation data, not Shiori search candidates.
- Reindexing must be able to remove stale entries when source subtitle files disappear.
- Indexed content must be reconciled with the currently selected folders so rows
  from removed folders do not remain visible.
- Search must be scoped to the currently selected folders.
- Search result playback must be based on persisted subtitle timing and matched video path.

## 7. UI Architecture

The UI must support the product's native macOS workflow without forcing future remote or cross-platform assumptions.

Rules:

- The first usable screen should support search and local folder management paths.
- M1 may expose only the settings surface required to manage folders, indexing,
  and decode mode.
- Broader settings polish belongs to M2.
- Search, indexing status, and playback state should be represented explicitly in UI state.
- The workbench must preserve separate invalidation domains for the Left
  Content Panel, central Playback Area, and Right Learning Panel. A state change
  in one domain must not require expensive derived state in another domain to be
  recomputed.
- The workbench observable graph is split into an `AppCoordinator`
  (`apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`) plus seven
  per-domain stores under their respective feature folders: `SettingsStore`,
  `IndexingStore`, `WorkbenchLayoutState`, `ShioriStore`, `LibraryStore`,
  `SearchStore`, `PlaybackStore`. Per-domain `@Published` state lives on the
  store for that domain; AppCoordinator holds orchestration methods that span
  multiple domains and a minimal app-level `@Published` surface (currently only
  `startupError`).
- Views must observe every store whose state they read, including stores read
  indirectly through AppCoordinator computed properties. Because `AppCoordinator`
  holds the stores as plain `let` references and does not republish child store
  changes, reading e.g. `appCoordinator.isPlaybackPageVisible` from a view that
  observes only AppCoordinator leaves that view's body stale until something
  else triggers a re-render. New views that consume a cross-store computed
  property must add the underlying stores to their `@EnvironmentObject` /
  `@ObservedObject` declarations alongside AppCoordinator.
- Large SwiftUI views must not subscribe to unrelated high-frequency or
  high-cardinality state when a smaller store, value model, or binding can
  express the same UI responsibility.
- Editable input draft state may be separated from submitted application state
  only when the product defines an explicit submission boundary. Workbench
  Search has no such boundary: the field keeps its own focus and IME editing
  state, while the latest committed text becomes `searchQuery` after the
  100-millisecond debounce and revision guard. Return does not submit Search.
- AppKit-backed editable controls must not overwrite focused text or active
  IME marked text from `updateNSView` during unrelated SwiftUI invalidations.
  Programmatic text replacement needs an explicit user action or focused-control
  ownership signal.
- Performance diagnostics used to investigate UI stalls, such as run-loop
  observers, automatic `sample` capture, or broad SwiftUI body/layout probes,
  must not become unconditional production behavior. After a regression is
  understood, heavy probes should be removed, gated to `DEBUG`, or enabled only
  through an explicit diagnostic flag.
- Current performance probes must be default-off in normal runs. Use
  `CUESEEKER_PERF=1` for lightweight app timing logs,
  `CUESEEKER_PERF_WATCHDOG=1` for the main-thread watchdog,
  `CUESEEKER_PERF_RUNLOOP=1` for the run-loop observer,
  `CUESEEKER_PERF_AUTOSAMPLE=1` for automatic `/usr/bin/sample` capture,
  `CUESEEKER_PERF_LAYOUT=1` for SwiftUI/AppKit layout probes,
  `CUESEEKER_PERF_SEARCH=1` for persisted Search timing logs,
  `CUESEEKER_PERF_UI=1` for UI invalidation counters, and
  `CUESEEKER_PERF_PLAYBACK=1` for playback slow-path logs. These flags are
  diagnostic tooling, not product behavior.
- Lightweight Search timing logs should be recorded for every Search request
  during development builds and may be enabled explicitly in other builds with
  `CUESEEKER_PERF_SEARCH=1`, `CUESEEKER_PERF_UI=1`, or `CUESEEKER_PERF=1`.
  They must be written under the project log directory
  `logs/search-timing/` as append-only, one-event-per-line `.log` files so local
  development sessions can be compared across machines and pasted directly into
  AI debugging sessions. Search timing logs should not be stored inside
  user-selected subtitle folders.
- The workbench container should own layout coordination only. Library,
  Playback, and Search presentation views should receive scoped state so Search
  focus, Search results, playback clock updates, and side-panel resize gestures
  do not invalidate unrelated panels.
- Future cleanup should continue splitting the workbench into smaller
  invalidation domains. Library, Playback, Search, Queue, Timeline, Shiori,
  and Learning Session views should subscribe only to the state they render,
  rather than inheriting every `AppCoordinator` publication from the root workbench.
- Library presentation rows are persisted indexed-resource presentation state.
  They should be materialized by indexing or an explicit Library data refresh,
  then loaded as a ready snapshot. App startup and ordinary Library disclosure
  changes must not regroup, resort, or regenerate Library row display data.
- Library folder collapse or expand state is presentation state over the
  persisted Library snapshot. Toggling one folder, toggling all folders, or
  resetting all groups to collapsed must not rebuild Library presentation rows.
- Search presentation rows are derived Cue query state. Their identity snapshot
  should be cached and rebuilt only when the active query, loaded Cue page,
  result ordering, or underlying indexed Cue data changes. Cues-column width
  changes and the persisted `Show Cue Group` preference are presentation inputs:
  they may remeasure visible rows plus overscan, but must not rebuild the query,
  row identity snapshot, result count, selection, or primary-Cue action targets.
- Search and Shiori use one native AppKit virtual Cue
  table contract. Every row owns one primary Cue identity and a content-driven
  height of `16 + 24P + 20S`, where `P` is the primary Cue visual-line count and
  `S` is the visual-line count of optional additional Cue Group context shown
  below it. Source line breaks and width-dependent wrapping both contribute to
  those counts; the table must render all Cue text without truncation or a
  maximum line count.
- Dynamic Cue-table measurement is a visible-plus-overscan concern. Width
  reflow and `Show Cue Group` changes should invalidate table-local presentation
  only: measurement and height indexes, visible drawing, document/scrollbar
  geometry, cursor rects, hover state, and menu anchors. They then restore a
  stable scroll anchor made from the primary Cue identity and its first visual
  line's screen-space position. Row-local hover, menu, measurement, and scroll
  state must remain outside Search, Shiori, Library, and Playback stores.

### 7.1 Unified Cue And Shiori Data Ownership

The accepted identity and memory architecture is defined by ADR-0014.

Rules:

- Cue content has one authoritative in-memory representation keyed by CueID.
  Search and Shiori may own different ordered result identities and surface
  state, but they must resolve content through that same representation.
- Search owns an ordered CueID result collection. Shiori owns an ordered
  Shiori-relation collection whose relation identity remains distinct from its
  referenced CueID.
- A Shiori relation owns ShioriID, CueID, list identity, and creation time. It
  must not own another subtitle text, Cue Group, title, language, timing, path,
  media snapshot, or relation-scoped Tags.
- Shiori relations are scoped to the existing multi-list model. Each relation
  keeps one list identity, and list management reuses the accepted Shiori
  persistence and presentation paths.
- Shiori initialization loads its complete relation collection and all
  referenced Cue content into memory before presenting the ready table.
  Arbitrary table positions must not trigger database hydration.
- Search, Shiori, and Playback must use one Cue-to-table projection for
  shared columns and Cue actions. Surface-specific relation metadata is applied
  as a lightweight overlay.
- Workbench and Playback must not keep parallel long-lived copies of the same
  authoritative Cue collection.
- A hidden Search or Shiori surface retains its logical state and stable scroll
  anchor. Switching surfaces must not reconstruct the full logical collection.
- Table drawing and heavyweight presentation caches remain viewport bounded.
  Lightweight scalar height information may outlive the viewport, but it must
  not retain Cue text, Tags, complete row values, attributed text, or native row
  views.

### 7.2 Shared Workbench Feature Hosts In Playback

Search, Recent, Library, and Shiori in Playback are capability-restricted hosts
of their Workbench features. They are not separate feature implementations.

Workbench Library and Shiori level-one pages reuse one Overview layout, one
adaptive Grid, and one Media Card content/style structure. Their differences
are data and actions: Library cards represent folders without a Description,
while Shiori cards represent lists with a Description. Library statistics are
derived from the same displayed folder summaries, and `Add Content` opens the
existing Settings Library entry point rather than adding another folder picker.

Workbench Recent overview and detail, Workbench Library Folder Detail, Playback
Command Panel Recent Videos, and Playback Video Playlist render one adaptive
video-card Grid and one video-card implementation. Every host keeps the Recent
Videos card content contract: folder title, `EPxx`, watch status, cover
progress, and time. Workbench Library Folder Detail does not create persistent
selection. Playback Video Playlist keeps Session-local selection, initially
prefers the current available video, falls back to the first available video,
and preserves the user's selection and exact offset when revisiting the module
within that Session.

Workbench Recent overview and Playback Command Panel render one Recent Shiori
resume-row list. Preview versus complete data limits, Command Panel selection,
Pointer Hover availability, and scrolling are host inputs to the shared card
and row components; they must not create parallel implementations. Command
Panel Recent Videos keeps its ordinal as the only selection source and combines
the current adaptive column count with visible card frames through the shared
media-grid direction rule. Four-direction navigation follows visual position
without wrapping and does not introduce a second selection store. Command Panel
Recent Videos, Recent Shioris, and Playback Video Playlist leave an already
fully visible selection stationary. A partially visible selection is treated as
offscreen and is revealed only at its nearest viewport edge; a lazy Grid target
that has not been materialized uses the nearest leading or trailing edge from
its ordered position. Hidden Playback Pointer state suppresses mouse Hover
visuals without clearing keyboard selection. Video-card Hover is visual-only;
Pointer movement never changes the Session-local selection.

The Playback Multi-Module Overlay owns one strictly temporary Session with
Current, optional Playlist, Search, Recent, Library, and Shiori. Module
switching stays inside that Session; Escape, playback, Playback Page close, and
source replacement cancel unfinished host-local work and destroy temporary
module presentation state. The hidden opening phase selects Current for a
video Playlist and Playlist for a Cue Playlist, falling back to Current when
no Playlist is available.

Data ownership rules:

- `SearchStore`, `ShioriStore`, and `LibraryStore` are the authoritative owners
  of their feature state, database access, paging tasks, loaded result
  collections, refresh rules, and product actions. Recent is a Library
  projection and follows `LibraryStore` ownership.
- A Library video enters Recent only after its existing playback entry point
  successfully starts playback. That history write must refresh the currently
  loaded Workbench Recent overview and complete Recent projection immediately;
  Playback hosts observe those same `LibraryStore` projections.
- Successful playback Modal suspension is the shared publication boundary for
  pending Library playback-history writes and their `LibraryStore`
  projections, whether playback was playing or already paused. Individual
  Modal hosts must not duplicate that synchronization.
- App termination and main-window close must wait for all queued Library
  playback-history writes even after the active source changes. This shutdown
  barrier persists data without refreshing presentation state.
- Playback may observe those stores, dispatch their existing product actions,
  and retain only host-local presentation state. It must not create a second
  feature database reader, query runner, paging store, result accumulator,
  refresh task, persistence path, or full result copy.
- Command Panel Search is a formal Search operation. It reuses `SearchStore`'s
  Workbench query, persisted facet Filter, filtered result projection, paging,
  and promotion lifecycle; Playback must not create a temporary Filter context
  or own a separate result projection.
- Feature data may be queried in pages or batches. Playback must use the same
  paging policy and accumulated result collection as Workbench. A load-more
  signal already supported by a Workbench feature may be forwarded to that
  feature store; Playback must not introduce an additional window-loading
  policy or viewport cache.
- Once a result item is published into the active feature collection, its
  stable identity and complete text remain resident until the authoritative
  feature replaces or releases that collection. Scrolling away from an item,
  changing the selected item, switching Overlay modules, or promoting a Search
  result into playback must not truncate or evict that loaded item.

Presentation virtualization rules:

- Workbench tables and Playback Reels may use different presentation renderers,
  but both operate over the authoritative in-memory feature collection.
- Playback virtualization is limited to visible-plus-overscan measurement,
  drawing or view materialization, height indexing, accepted placement,
  scrolling, and scrollbar geometry. It must not virtualize feature ownership
  or replace complete loaded item text with a Playback-owned data window.
- Current uses a native virtual Cue document over the complete Cue collection
  owned by the active playback source. Opening selects the physically
  bottommost Cue in the active Cue Group; when no Cue is active it falls back to
  the nearest preceding Cue, then the first Cue. Natural height is the greater
  of the minimum Cue height and the measured visual-line stack plus vertical
  Cue padding, followed by the fixed metadata height when metadata is present;
  resolved height is clamped to the Reel viewport. Visual lines use measured
  font-run typographic bounds with the shared internal-line-gap token instead
  of fixed Line Slots. A fitting Cue centers its complete bounds on the fixed
  Focus Anchor; an oversized Cue uses accepted head-first placement at the
  viewport top. Width reflow preserves stable Cue identity and restores that
  placement.
- Playlist, Search, and Shiori reuse Current's measurement, accepted placement,
  scrolling, scrollbar, and recycling behavior while substituting Cue Result
  identity, rendering, and height calculation. `Show Cue Group` remains a
  presentation-only input and must not change count, order, identity,
  selection, or Primary Cue action targets.
- Playback Current, Cue Playlist, Command Panel Search, and Editing Collage
  share one Reel-owned Cue timeline presentation. A fixed-width sequence lane
  keeps the proportional system font right-aligned and derives its width from
  the current dataset's maximum one-based ordinal digit count using the shared
  16-point digit-width token, without a fixed digit limit. The lane is followed
  by one timeline marker and the existing Cue renderer, with the shared
  24-point horizontal gap on both sides of the marker. Current and Collage use
  the physical Cue ordinal; Cue Result adapters use their existing list
  ordinal. Focus changes only sequence and marker colors and never add total
  text or change the lane, Cue width, placement, or scroll position. Marker and
  sequence visible-glyph centers use the Primary Cue first visual line's visible
  glyph center already produced by text measurement; nominal line-box centers
  are not alignment inputs. Connectors are derived from consecutive
  visible-plus-overscan placements during drawing, leave 8 points between each
  marker edge and line endpoint, and do not create another selection or layout
  state owner. Editing Collage substitutes its existing checkbox for the dot
  while keeping the same checkbox state and interaction path.
- Playback Current and Cue Result adapters share Cue typography and one plain
  metadata model and renderer. Current retains its primary-only measurement
  cache and native text drawing hot path; Cue Playlist and Command Panel Search
  retain the general Cue Result layout required for optional Cue Group content.
  Metadata contains only Display Title and Time Range, uses fixed geometry, and
  follows the complete visible Cue stack. It has no Badge background, border,
  radius, or padding. The existing Reel and Session owners remain the only
  selection and scrolling state sources.
- Playback Command Panel Search uses the Cue Playlist's general Cue Result
  Adapter and Reel over a host-owned resident preview Window capped at 50
  results. That Window is the only Command Panel Search selection source for
  keyboard, wheel, and scrollbar input. Activating a preview result continues
  to install the complete Search Playlist. Command Panel Search must not
  reintroduce its dedicated result Row or a duplicate selection store. Its
  sequence denominator uses the complete Search result count while the resident
  preview remains capped at 50 results.
- Cue Result base extent depends only on Primary Cue, optional resident Cue
  Group content, fixed metadata presence, presentation width, and style. Every
  metadata-bearing Cue extent includes the same fixed metadata height;
  selection must not enter the measurement key, advance the dataset revision,
  clear the measurement cache, or change Reel placement. Current applies the
  same fixed height to every cached base Cue measurement without creating a
  general Cue Result. Current and Cue Result retain bounded text-measurement
  caches; the two-string metadata layout remains stateless presentation work.

Playback-specific differences are limited to:

- the appearance-aware full-stage Overlay shell, module Sidebar, Tab routing,
  Pointer visibility rules, pause behavior, and Playback Feedback layer; the
  shell follows CueSeeker's effective Light, Dark, or Auto appearance without
  changing Overlay Session state;
- temporary Overlay Session state and Playback Return Context;
- the documented capability mask, including removal of batch, export, folder,
  Filter-control, and table-copy entry points;
- Playback Cue Reel layout, Focus Anchor, accepted placement, settled selection,
  shared sequence/timeline/metadata presentation, Cue Group visibility policy,
  and the Playback-only Current and Playlist modules;
- Playback Search's formal Workbench Filter projection, text-field focus
  routing, Up/Down Reel routing, and Enter-only Cue action;
- Recent and Library persistent single selection, directional navigation,
  session-local Library hierarchy and scroll position, and locked menu target;
- Playback-specific play, dismiss, resume, seek, feedback, and Return Context
  side effects.

Any behavior outside this list does not justify a parallel Playback feature
implementation. In particular, database access, paging, loaded result retention,
feature actions, and durable state remain shared with Workbench.

Replacement and simplicity rules:

- Each feature migration must delete the replaced Playback loader, store,
  adapter, cache, compatibility branch, and obsolete tests in the same feature
  commit. A shared type may remain only while an unmigrated live consumer still
  requires it, and must be removed with the last such consumer.
- Do not add shadow paths, fallback implementations, generalized transports, or
  projection frameworks for hypothetical consumers. Extract an abstraction only
  when both Workbench and Playback use it directly; otherwise prefer the
  existing Feature Store plus the smallest host-local presentation state.
- Current, Playlist, and Shiori actions operate on an immutable exact Primary
  Cue after accepted placement settles: `S` saves it idempotently, `C` copies
  its complete text, and Enter synchronously destroys the Session before seek
  and play. Search preserves text input and accepts only Enter as its Cue
  action. Space is consumed without action throughout the Overlay. Overlay
  layout, selection, motion, deferred-action, and visible-plus-overscan state
  must not invalidate Workbench tables or the playback render host.
- Side-panel collapse or expand must not destroy and recreate large list state.
  Prefer stable panel shells whose layout width, visibility, opacity, or hit
  testing changes without discarding the panel's current presentation model.
- Workbench side panels should use fixed-width drawer content during collapse
  and expand animations. The Library and Search panel contents must keep their
  expanded width while sliding in or out; the workbench may separately adjust
  the central Playback Area's reserved width. Do not animate panel content to
  zero width or place large panel ScrollViews in a layout path that forces their
  rows and buttons to accept changing width proposals during every toggle frame.
- The embedded Playback Area should not be wrapped in a SwiftUI `ScrollView` for
  the normal workbench playback surface. Side-panel toggles should resize a
  top-aligned playback container directly instead of making ScrollView layout
  repeatedly measure playback controls and the native render surface.
- If SwiftUI lazy stacks are used for large grouped lists, row models should be
  flattened when necessary so lazy rendering applies to individual headers and
  rows rather than to a single large group view that eagerly builds all children
  inside the group.
- Dense Library, Search, Timeline, Queue, and Shiori rows should avoid
  expensive SwiftUI/AppKit button layout when a lighter row plus explicit hit
  handling can provide the same interaction. Full-row actions, hover actions,
  and context menu affordances should be implemented without forcing large
  result lists through repeated `NSButton` metrics or baseline calculations.
- Search field focus should be owned by the Search Panel presentation layer
  unless another documented command needs to coordinate focus. Focus changes
  must not be treated as Library or Playback state changes.
- Playback time exposed to SwiftUI controls should be rate-limited separately
  from the native playback clock so progress text and controls do not invalidate
  unrelated workbench UI at video-frame cadence.
- The embedded Playback Area's black video background, native video view,
  `AVSampleBufferDisplayLayer`, and source-faithful ASS overlay should be owned
  and laid out by the native playback render container. SwiftUI may size and
  clip the overall playback card, but it should not provide a separate black
  backing layer whose layout can get ahead of the native video layer.
- Native playback layout updates during workbench side-panel animations should
  disable implicit CALayer frame animations and synchronously lay out attached
  AppKit subviews where necessary so the video frame and black background remain
  visually locked together.
- Workbench actions that animate the video's available size must be serialized
  while the animation is active. This includes Library/Search panel toggles,
  bottom-player video overlay expand/collapse, titlebar double-click zoom,
  playback fullscreen enter/exit, the `F` fullscreen shortcut, and
  Escape-driven fullscreen exit. Direct divider drags remain a live resize
  interaction and are not part of this serialized command gate.
- Playback fullscreen and titlebar zoom transition gates must use AppKit's
  current resize-animation duration for the actual source and target window
  frames, such as `NSWindow.animationResizeTime(_:)`. They must not use a fixed
  guessed delay for fullscreen or window-zoom animation length.
- The main window should use `CueSeeker` as its top-level workbench identity.
  The old standalone `Search` AppShell label should be removed; Search is a
  right-side learning panel workflow.
- Settings belongs to the macOS app menu and an independent Settings window.
  Opening or focusing Settings must not mutate CueSeeker workbench pane state,
  selected result identity, or playback state.
- The Settings window may share app state for configured folders, indexing
  commands, indexing status, and decode mode, but its presentation state should
  not be stored inside Search Panel state.
- The CueSeeker workbench uses a player-first layout: Library on the left when
  expanded, embedded playback in the center, and a collapsible Right Learning
  Panel on the right.
- The Right Learning Panel is the collapsible auxiliary pane. Playback must not
  be treated as the collapsible auxiliary pane in the CueSeeker workbench.
- Collapsing the Right Learning Panel must preserve playback state, selected
  result identity, and Search/Shiori presentation context.
- Future side-panel work should preserve distinct responsibilities around
  playback: the Left Content Panel owns Library and Timeline-style precise
  resource positioning, while the Right Learning Panel owns Search, Shiori,
  Queue, and Learning Session-style active learning and result aggregation
  workflows.
- The Left Content Panel and Right Learning Panel should evolve into stable
  mode containers. Switching between Library, Timeline, Search, Shiori,
  Queue, and Learning Session modes should preserve each mode's current
  presentation state where practical and must not rebuild unrelated panel lists
  or reset playback.
- Left and Right panel mode selectors belong visually to the global titlebar,
  not to the panel content body. Their horizontal positions must stay
  synchronized with the current panel visibility and user-resized panel widths,
  so the controls remain visually inside each side-panel titlebar region while
  still being rendered as top-level titlebar controls.
- Left panel titlebar modes should start with a selected Library folder icon.
  Right panel titlebar modes should start with Search and Shiori icons:
  magnifying glass for Search and a Shiori saved-content icon for Shiori.
  Shiori is a Right Learning Panel mode because it behaves like collected
  Search/playback context, not like Library folder navigation.
- Titlebar mode buttons should use hover feedback and selected feedback only.
  Their hover background should match the titlebar collapse-toggle hover
  background, and their selected background should match the collapse-toggle
  pressed background. Mode buttons should not add a separate pressed visual
  state on click.
- During side-panel collapse and expand animation, the titlebar collapse-toggle
  and mode controls must visually move with the same side-panel edge they
  represent. The collapse-toggle should stay above mode buttons in z-order so
  its motion defines the visible boundary of the side-panel titlebar controls.
- Titlebar side-panel controls must use a drawer-style clipped strip, not
  conditional insertion/removal or opacity transitions. During collapse, mode
  buttons should be pushed into the collapsed side and disappear by clipping,
  leaving only the collapse-toggle visible. During expand, the strip should
  reveal mode buttons by reversing the same clipped movement.
- The drawer-style clipped strip must use a globally stationary mask boundary.
  The container frame should maintain its full expanded width during the
  animation so hit testing and dragging are not broken, while a `.mask` with a
  dynamically calculated width creates a clipping edge that remains perfectly
  stationary in global coordinates as the buttons translate past it.
- Titlebar side-panel control animation and side-panel body animation must use
  the same duration and finish at the same time. Their travel distance may
  differ; matching duration matters more than matching speed.
- These synchronized animations must be driven by a single, explicit global
  `withAnimation` transaction on the underlying state mutation (e.g.,
  `toggleLibraryPanel`). Redundant implicit `.animation` modifiers on dependent
  layout views or `GeometryReader`s must be avoided to prevent loss of geometry
  tracking and "instant snap" bugs.
- In fullscreen mode, the titlebar's left side-panel controls must dynamically
  re-align their collapsed coordinate to match the right side-panel controls'
  symmetry (e.g., matching padding from the screen edge), since the standard
  macOS window controls (traffic lights) are hidden.
- When side-panels are expanded, their titlebar toggle buttons should dock
  flush against the side-panel's vertical divider line (0px padding), while
  maintaining their required outer padding from the screen edge when collapsed.
- Library should be modeled as a Left Content Panel mode, not as AppShell
  navigation and not as Settings folder management.
- The fixed left titlebar control should collapse or expand Library, not a
  standalone AppShell sidebar.
- Library width should be resizable, with its first default width equal to its
  minimum width of `310pt`, `50pt` narrower than the previous fixed `360pt`
  Library width. User-adjusted Library width should persist as UI preference
  state.
- The first Library implementation should materialize flat one-level folder
  groups from indexed playable video metadata during indexing or explicit
  Library refresh. The materialized snapshot should use Finder-like natural
  comparison for folder and video ordering, derive each video's one-based
  sibling rank among playable sibling videos in the same folder, and keep
  indexed duration metadata available for tooltips, accessibility, and future
  features even though the visible folder row and episode-grid layout do not
  draw per-video durations.
- Library folder rows present a two-line layout: folder display name on the
  first line and an episode-count subtitle on the second line. The subtitle
  reads `N episodes` by default and `N episodes · Playing M` while a
  Library-launched playback session is active for a video in this folder, where
  `M` is that video's sibling rank. Folder rows must not draw a leading
  first-letter or first-character avatar block.
- The full Library folder row is a single click target that toggles expand or
  collapse. The right-side chevron is a visual indicator only.
- Expanded Library folders render a numbered episode-button grid using each
  video's sibling rank. The grid must not draw per-video file names, durations,
  or language tags. The grid must use minimum-button-width auto-flow columns so
  the column count adapts to the user-resized Library panel width, and must be
  indented slightly to the right of the folder row's left edge to express
  hierarchy.
- Episode buttons must use only three visual states: default, hover, and
  playing. Hover should reuse the existing collapse-toggle hover treatment.
  The playing state highlights only when playback was launched through Library.
- Library startup state must be hydrated from the persisted Library presentation
  snapshot before the first visible main-window render when the local database is
  available. Startup must not rebuild Library presentation from subtitle/video
  joins, grouping rules, or sorting rules. A one-time schema migration may
  backfill the snapshot for older databases, but normal restarts must only read
  the snapshot.
- Library folder collapse or expand state is current-session presentation state.
  It should not persist across app restarts. App startup, Library data refresh,
  and reindex completion should all present Library folder groups as collapsed.
- When the user expands a Library folder that contains the currently
  Library-launched playing video, the panel should auto-scroll that video's
  episode button into view as part of the expand transition. Auto-scroll must
  not fire on already-expanded folders or on data refresh.
- Library does not expose a panel-wide `Collapse All` or `Expand All` control.
  Folder disclosure remains per-folder.
- Clicking a Library episode button should dispatch through the same playback
  open path used by Search-result playback, but should resolve its start
  timestamp from Library-only resume history before falling back to `0`.
- Library resume history is durable user state keyed by video identity. It
  should be read and written only for playback sessions opened from Library.
  Search-result playback must not read, write, or overwrite Library resume
  history.
- The Library `Playing M` folder subtitle and the playing-state episode button
  highlight are presentation indicators driven exclusively by Library-launched
  playback. Playback opened through Search results, Shiori, or any other
  surface must not toggle these Library indicators. Whether a given playback
  session is Library-launched is part of playback session state and should be
  resolvable without inspecting Search or Library row identity directly.
- Reindexing a folder should invalidate Library and Search presentation for
  resources under that folder. After reindex completion, Library should be
  refreshed with all folder groups collapsed, and any active Search query should
  be rerun against the rebuilt index.
- If current playback is using a media file under a folder being reindexed, the
  app should stop or clear that playback before the reindex begins. This keeps
  playback state from referencing resource identities that are actively being
  rebuilt.
- Derived local index rows may be deleted, rebuilt, or marked stale, but
  durable user state that references those resources must remain separate.
  History, Shiori records, future queues, and learning-session records should show
  unavailable or unbound resource states when their current index binding is
  missing rather than being silently deleted.
- Queue and Learning Session state must not be hidden inside playback UI state
  alone if it becomes durable or cross-view behavior.
- Learning Session playback rules require product documentation before
  implementation because they affect playback state, keyboard behavior,
  persistence, and test coverage.
- Keyboard behavior must preserve standard macOS text editing behavior.
- UI errors should be concise and actionable, with technical detail reserved for logs.
- The M1 app shell may combine SwiftUI content with AppKit titlebar controls when SwiftUI-only layout cannot match native macOS titlebar behavior.
- AppKit titlebar controls should coordinate through shared app state rather
  than duplicating side-panel visibility state.
- The current M1 shell uses a fixed titlebar toggle and centered title.
- To achieve custom offsets for native traffic light buttons, the app uses a Proxy View reparenting pattern to extract buttons from the system's `_NSTitlebarContainerView` rather than fighting the private AppKit layout engine with frame or bounds overrides.
- Window dragging must be handled explicitly by the custom titlebar (`performDrag(with:)`) with `window.isMovableByWindowBackground` set to `false`. Relying on window background dragging causes conflicts with SwiftUI drag gestures on transparent views.
- Resizable dividers must use a custom `NSView` overlay to natively handle `resetCursorRects`, `NSTrackingArea`, and drag events (`mouseDown`/`mouseDragged`). SwiftUI's `.onHover` with `NSCursor.push()` is unreliable due to AppKit's continuous cursor rect evaluation, and SwiftUI's `DragGesture` can conflict with window event routing.
- A pointer shape must come from the framework that draws the surface. SwiftUI
  surfaces declare it with SwiftUI's own pointer style; AppKit surfaces register
  cursor rects on a view that takes hits. Setting or pushing a shape from
  outside the hosting framework is overwritten on the next mouse move, because
  the SwiftUI hosting view and AppKit both restate the shape while the pointer
  moves. A representable's `NSView` cannot carry a cursor rect for a SwiftUI
  surface: SwiftUI keeps it out of hit testing, so AppKit never consults it.
- A SwiftUI `Button` decides the pointer for its own area, so a pointer style
  meant for a button must be applied to its label rather than around it.
- Playback keyboard shortcuts are handled through a local AppKit key-down monitor and must not intercept keys while native text input is focused.
- Playback shortcut handling should route through shared playback state instead of duplicating command behavior in individual views.
- Playback controller support is a macOS platform-integration boundary covered
  by `docs/human/requirements/20260731-Feature-Playback DS5 Controller Support.md`
  and `docs/human/design/Controller.md`. `GameController` connection and input
  lifecycle belongs at the App delegate boundary; normalized controller events
  use physical positions rather than vendor button names, while device-specific
  adapters own vendor mappings. The initial adapter accepts the standard
  DualSense profile only.
- Controller input is active only while CueSeeker is foreground, the main
  window is key, and the video page or its fullscreen presentation is visible.
  Disconnect and App termination must remove handlers and cancel pending
  continuous input.
- Keyboard-equivalent controller behavior must reuse the shared Playback input
  state machine without synthesizing system keyboard events. When that state
  machine leaves an event to native text editing, controller routing must issue
  the equivalent first-responder movement, insertion, deletion, or paste command
  instead of dropping the unhandled result. Collage Copy and Export belong to
  the shared preview Store so mouse and controller actions execute the same
  implementation.
- The left thumbstick uses its dominant axis, activates at `0.65`, releases at
  `0.35`, and cannot trigger another direction until it returns to the release
  deadzone. Continuous input begins after `0.4` seconds and repeats every
  `0.08` seconds. All four directions retain their keyboard-equivalent repeat
  behavior on the normal video page, Playback Overlay, Command Panel, and
  Collage; the additional product examples do not exclude unlisted interfaces
  or axes. Controller buttons and the directional pad retain press and release,
  use the same repeat lifecycle, and forward `isRepeat` so the shared keyboard
  state machine can preserve or suppress each repeated action exactly as it does
  for a physical keyboard.
- The packaged App must declare controller user interaction and the Extended
  Gamepad profile. DS5 Bluetooth and USB use the same normalized mapping;
  connection transport must not enter Playback behavior code.
- Further visual polish should remain incremental.

### 7.1 Info-page / video-page refactor (v6)

This subsection reconciles §7 with the info-page / video-page refactor. The
human-owned UI authorities are `docs/human/design/UI Design System.md` and
`docs/human/design/UI Application Rules.md`. The derived implementation
mapping is `docs/product/12_liquid_glass_ux_mapping.md`
(§5, §10.1, §10.4, §11), supported by
`docs/proposals/2026-05-ui-info-page-video-page-refactor.md` and ADR-0013. The
§7 invalidation-domain and product-semantics rules above are preserved; the
following points clarify how they apply.

- The video page is a dedicated full-window presentation layered above a still
  alive info-page workbench (Library / Search / Shiori). It is not a route swap
  and does not make playback the collapsible auxiliary pane. The separate
  invalidation domains are preserved while the video page is shown: info-page
  rows and presentation state must not be rebuilt, and video-page overlay-panel
  updates (Search navigation snapshot, current subtitle entries) must not
  invalidate Library rows or the native playback render.
- The centered overlay panel floats over the video and does not change the
  video's available size. Toggling it is therefore NOT a video-size-changing
  command and is OUTSIDE the serialized resize gate defined above. The
  previously enumerated "bottom-player video overlay expand/collapse" control is
  removed by this refactor and no longer participates in that gate.
- On the video page the native NSWindow traffic lights are suppressed and a
  custom-drawn top-bar control cluster provides app semantics: close restores
  the current Playback Return Context (not quit), minimize collapses playback,
  zoom enters fullscreen. These are presentation/platform controls; they must
  dispatch through shared playback and navigation state and must not embed
  product semantics in the view.
- Product semantics stay out of views: the overlay panel renders existing
  shared app state (Search navigation snapshot, current subtitle entries) and
  must not reimplement Search, subtitle, or indexing logic. This preserves the
  module boundary in §2 and §5.

## 8. File Access and Sandboxing

Local subtitle and video file access is a core product requirement.

Rules:

- Folder selection must use native macOS folder selection behavior.
- Native file and Finder interactions may temporarily create AppKit,
  QuickLook, or Finder-related helper services. This is an acceptable cost for
  explicit low-frequency actions such as adding folders or future commands that
  reveal the current video in Finder.
- Helper-service optimization should focus on avoiding unnecessary helper
  creation during app launch, Search, opening or focusing Settings, and
  playback, and on preventing helper-service accumulation after the app exits.
  The app should not replace standard macOS file panels or force-terminate
  system helper services only to reduce Activity Monitor process counts.
- Persistent access to selected folders must be designed before relying on it across launches.
- ADR-0004 disables App Sandbox for M1 local development and personal builds.
- Security-scoped bookmark handling is not required for M1 while App Sandbox is disabled.
- If sandboxing is later enabled, security-scoped bookmark handling must be documented and tested.
- The app must not silently scan folders that the user has not selected or otherwise authorized.
- Selected-folder access is not permission to process every file in that
  folder. CueSeeker must use the smallest supported file surface for the
  product workflow: video files for playback and metadata, plus `.srt` and
  `.ass` subtitle files for indexing and subtitle playback.
- Files outside the supported video and subtitle formats must be ignored by
  default, including fonts, images, loose text files, archives, and sidecar
  asset folders. The app must not scan, read, copy, cache, index, or pass those
  files to renderers unless a future product feature explicitly accepts the
  file type and documents the permission, UX, data, and test model first.
- Video container attachments that are not required for supported video/audio
  playback are outside the current product surface. Font, image, or document
  attachments in media containers must not be extracted or materialized for
  subtitle rendering.

The final sandboxing and persistent file-access strategy may require an ADR.

## 9. Playback Architecture

Playback is a high-risk component.

Rules:

- M1 requires local file playback and timestamp seek only.
- ADR-0007 selects native-only playback.
- Playback code must not assume remote streams, local HTTP proxying, cache
  layers, or complete ASS subtitle renderer compatibility.
- Playback errors must be propagated in a form that the UI can present clearly.
- M1 playback must be embedded in the native app window.
- ASS playback rendering must use the `libass` source-faithful overlay. The
  native ASS renderer and ASS Lite fallback must not be reachable from the
  active playback route.
- Settings must not expose an ASS renderer selector while CueSeeker has a
  single supported ASS renderer.
- Search result previews are database-owned primary-Cue projections. Optional
  Cue Group context is presentation-only and never replaces the primary Cue's
  row identity, selection, playback target, or action target. Playback subtitle
  rendering remains source-file-owned.
- The database cue projection must not be treated as a replacement ASS renderer.
- Search projection may omit non-searchable visual-effect details from FTS, but
  playback rendering must preserve timed source ASS events, including
  `Effect=fx`, `\p` vector drawing, clipping, karaoke, blur, alpha, transforms,
  and short-duration effects.
- ASS parsing and renderer preparation must not run synchronously on the search
  result click path.
- Video open, video seek, selected-row UI state, and playback controls must not
  wait for ASS parsing or rendering.
- ASS rendering should be coordinated through an asynchronous render coordinator
  with cancellation and cache invalidation keyed by source file identity.
- ASS rendering may use only the source `.ass` subtitle content and
  system-installed fonts available through the platform font provider. CueSeeker
  must not scan adjacent font folders, copy external fonts, extract video
  container font attachments, build app-owned font directories, or pass an
  app-owned external font cache directory to `libass`.
- `libass` full-source loading and indexed render-segment loading must follow
  the same font boundary: system fonts only, with no external sidecar or
  container attachment font resources.
- Existing ASS font-resource manifest schema is legacy derived metadata only.
  It must not be treated as an active playback input, rebuilt from local
  sidecar files, or used to reintroduce external font-resource handling.
- Source-faithful ASS rendering must avoid rebuilding presentation payloads when
  the renderer reports an unchanged visual frame. Static subtitle intervals
  should reuse the previous cropped subtitle surface and layer contents instead
  of repeatedly compositing RGBA data or replacing `CALayer.contents`.
- Database cue timing is consistent with the source ASS event timing and may be
  used to identify the selected cue window and nearby cue windows before ASS
  render preparation finishes.
- Source ASS lookup remains required for exact render payload, including style,
  override-tag, vector drawing, `Effect`, and other formatting details.
- Time-windowed or segmented ASS preparation is the preferred future
  optimization for large ASS files. Full-file preparation may remain a fallback,
  but it should not be the only long-term render preparation path.
- Large ASS render segmentation must be done during indexing, not on the
  result-selection or playback-render path. The playback path may query a
  precomputed render segment by source identity and timestamp.
- ASS render segmentation should be enabled for `.ass` files at or above
  256 KB. Segments should use complexity-aware windows: low-complexity regions
  may be widened up to 60 seconds, while dense effect regions should shrink
  toward 5-10 second windows according to dialogue count, byte count, override
  tags, animation, vector drawing, clipping, and peak active render cost.
- Complexity-aware segmentation must be a conservative source-preserving
  optimization. The segmenter may change only which overlapping source events
  are packaged into each indexed render script; it must not rewrite event
  timing, style names, override tags, drawing commands, layer values, margins,
  or source order to reduce cost.
- The segmentation budget should optimize for stable playback memory and
  click-to-subtitle latency, not for the smallest possible number of database
  rows. Small ASS files below the threshold should keep the full-file path to
  avoid segment-switch overhead and lost renderer cache locality.
- Large ASS render segments stored in SQLite must preserve complete render
  context for the segment: script metadata, styles, event format, original event
  timestamps, original event text, layer values, and source order for every
  event overlapping that segment.
- Large ASS render segments are a derived cache. They must be rebuilt when the
  source subtitle file size or modified time changes, and stale segment rows
  must be removed with the owning subtitle file.
- The ASS render-segment cache must carry an algorithm version so segmentation
  strategy changes invalidate older derived rows instead of reusing stale
  windows for unchanged subtitle files.
- The dedicated ASS renderer must be separate from the SQLite search layer and
  from the native video decoder. It should receive playback clock updates and
  present overlay output through the playback render container.
- ASS timing-source consolidation is deferred until the workbench invalidation
  boundaries are stable. Any future change to ASS playback timing must preserve
  immediate selected-row updates, immediate video open or seek, and prompt
  subtitle source loading after Search result selection.
- Bundling and updating `libass` remains an explicit playback dependency
  concern because it affects packaging, signing, license review, system-font
  discovery, and font fallback behavior.
- The current playback route must always use the project-owned native backend.
- The active native macOS app must not link against, initialize, or fall back to `libmpv`.
- The native backend uses FFmpeg demuxing, user-selectable hardware, software,
  or automatic video decode mode, native display, FFmpeg audio decode, and
  `AVAudioEngine` output.
- The native backend must use the same bounded read-ahead behavior for all
  path-based media sources. Local files, mounted NAS volumes, and future
  WebDAV-style file access must not be split into separate playback quality
  classes just because macOS presents mounted network storage as a local path.
- Native read-ahead is session-scoped and must be cleared on open, close, and
  seek/session replacement. It must not copy or stage whole media files into a
  temporary local directory.
- Native read-ahead should queue compressed FFmpeg packets, not decoded video
  frames or decoded audio frames, unless a later design explicitly changes the
  memory model.
- Native read-ahead starts playback immediately with a 0 second startup packet
  waterline, targets 10 seconds of queued packet media time during steady
  playback, and caps queued compressed packet data at 64 MB.
- Native read-ahead should remain a simple fixed-watermark policy until field
  evidence justifies adaptive behavior. It must not automatically raise startup
  waterlines after repeated rebuffer events without a documented design update.
- Timeline scrubbing is a modal playback state and must not reuse ordinary
  pause semantics as its only mechanism. During active timeline scrubbing,
  audio and the playback clock remain paused, but the video surface may still
  be updated by an isolated keyframe-only scrub render path.
- Active timeline scrubbing must suspend or freeze ordinary session read-ahead.
  The normal 10-second / 64 MB compressed-packet queue must not continue
  advancing from the old playback position while the user is dragging.
- Keyframe-only scrub render work must remain isolated from ordinary playback
  read-ahead. It may decode or reuse individual keyframe frames for display,
  but it must not populate the normal packet queue. When scrubbing ends, the
  final seek position decides whether the ordinary read-ahead queue can be
  retained or must be discarded and rebuilt.
- Hardware decode uses VideoToolbox.
- Software decode uses FFmpeg software decoders and initially converts decoded
  frames to BGRA with `libswscale` before display.
- Software decode may automatically recycle the initial software playback
  session once after the first target frame has been displayed. This is a
  targeted mitigation for first-session dirty allocator pressure observed with
  high-resolution software AV1 decode.
- Automatic software session recycling must preserve the user's selected
  software decoder parallelism, must not use Metal YUV as the primary mitigation
  for this issue, must not recurse, and must not publish a transient pause or
  `0` timestamp to the UI.
- Automatic decode should prefer VideoToolbox and may fall back to software
  decode when hardware setup is unavailable.
- The next Metal YUV iteration should be scoped to software-decoded frame
  compatibility. The VideoToolbox hardware decode display path must remain on
  the existing hardware path unless a separate decision expands that scope.
- The app should query current-device VideoToolbox hardware decode support once at startup or before folder scanning, because codec support differs across Apple Silicon generations such as M1 and M4.
- Folder scanning should perform fast media-file native compatibility inspection using only stream presence, codec names, and current-device hardware decode support. Scanning must not decode frames, start a player, or perform heavy disk reads for compatibility inspection.
- The initial video codec candidates for fast native compatibility inspection are H.264, HEVC, VP9, and AV1, filtered by current-device VideoToolbox hardware decode support.
- Fast video compatibility inspection should use video codec support first. If no video stream exists but an audio stream exists, the same media-file profile model should allow native audio-only candidates as audio playback support evolves.
- Native compatibility metadata is a media-file property. It must not depend on `srt_path` as a unique key or on exact subtitle-to-video filename matching.
- If a native media file fails during real playback, the app should surface the native failure and may update the media-file profile so the failure reason is available for diagnostics.
- Full playback verification may still inspect actual decoder output when debugging the native backend, but that verification is not part of the fast folder-scan preselection path.
- The native display path should move toward a shared Metal YUV renderer for both hardware `CVPixelBuffer` frames and software-decoded FFmpeg `AVFrame` planes.
- Unsupported color layouts, bit depths, ranges, chroma layouts, or frame strides must produce explicit native failure reasons rather than silent incorrect rendering.
- Native timestamp seek should first try the selected video stream and then fall back to a global seek before treating seek setup as a native failure.
- Native seek state updates must not publish a transient `0` timestamp while a target seek is being prepared.
- The playback UI hosts a singleton render container owned by the playback player; fullscreen must preserve that same container rather than creating an independent render view.
- Playback fullscreen should use the main CueSeeker workbench window's AppKit
  native fullscreen capability, then switch that same window into a video-only
  playback presentation.
- Playback fullscreen must not create a second playback fullscreen `NSWindow`
  for the standard path.
- Playback fullscreen must not move the singleton native render container across
  windows during fullscreen entry or exit.
- AppKit should own the fullscreen Space transition, including Dock, menu bar,
  desktop, wallpaper, Mission Control, app switching, and system overlay
  behavior. CueSeeker must not manually emulate standard playback fullscreen
  with an always-on-top borderless overlay window.
- Playback fullscreen state should be coordinated through AppKit fullscreen
  lifecycle callbacks rather than fixed guessed transition delays. If custom
  fullscreen animation is later required, use AppKit's custom fullscreen
  delegate callbacks and the system-provided duration.
- Ordinary app fullscreen and playback fullscreen must be distinct states. The
  green traffic-light button or system View fullscreen command may request app
  fullscreen, while playback controls and playback shortcuts request video-only
  playback fullscreen presentation.
- Closing fullscreen, hiding the CueSeeker workbench, switching to another
  future top-level workspace, closing the main window, or terminating the app
  must clean up playback fullscreen presentation state.
- Playback controls in the embedded Playback Area and fullscreen overlay should
  share the same playback view model and feedback overlay model.
- Fullscreen player UI visibility and cursor hiding are owned by the fullscreen
  manager, not by individual SwiftUI playback control views. Player UI means
  the bottom player plus the video-frame `Close` capsule.
- Entering fullscreen must force player UI and cursor into the not-visible
  state and suppress the initial hover event generated by the newly activated
  fullscreen presentation until actual mouse movement occurs.
- Cursor hide and unhide calls must remain balanced when entering, exiting, or cleaning up fullscreen.
- App switching while playback fullscreen is active should rely on AppKit Space
  behavior and must not reveal a separate CueSeeker workbench window that has
  lost its video surface.

## 10. Dependency Management

Dependencies should be introduced conservatively.

Rules:

- Prefer platform APIs and small focused dependencies over broad frameworks.
- Any dependency that affects playback, database access, sandboxing, packaging, or signing must be documented before adoption.
- Dependencies that require bundled native binaries, special signing, or notarization handling require explicit review.
- Package manager and build tooling choices must be documented in or alongside the native app project.

## 11. Logging and Diagnostics

Logging should support debugging without exposing unnecessary personal data.

Rules:

- Logs may include technical diagnostics for indexing, parsing, database, search, playback, and UI errors.
- Logs must not include credentials, tokens, or authentication headers.
- Logs should avoid dumping full user file trees.
- User paths may be logged when necessary to debug local file behavior, but broad recursive listings should be avoided.
- User-facing errors should be shorter and less technical than diagnostic logs.

Recommended error categories:

- File access.
- Subtitle parsing.
- Video matching.
- Database.
- Search.
- Playback.
- UI state.

## 12. Credential and Secret Handling

The early native rewrite should not require stored credentials.

Rules:

- Do not introduce credential storage for M1.
- Do not store passwords, tokens, API keys, or authentication headers in plain text.
- If future features need credentials, prefer macOS Keychain.
- Credential handling requires documentation before implementation.
- Secrets must not be written to Git-tracked files or logs.

## 13. Configuration

Local configuration should remain minimal in M1.

Expected M1 configuration:

- Selected local subtitle folders.
- Indexing state needed to support refresh behavior.
- Window or section persistence only if practical.

Rules:

- Configuration must be local to the user's machine.
- Configuration storage format must be documented before it becomes hard to migrate.
- Configuration should not duplicate large indexed subtitle content outside the database.

## 14. Legacy Flutter Reference

The archived Flutter implementation may be used as a reference, but it is not active code.

Rules:

- Do not import active Flutter dependencies into the native app.
- Do not assume archived database compatibility without a documented database strategy.
- Useful behavior from the archived implementation should be translated into native architecture deliberately.

## 15. ADR Requirements

The following decisions require ADRs before production implementation depends on them:

- Final playback engine.
- Sandboxing and persistent folder access strategy, if non-trivial.
- Direct compatibility with or migration from the archived Flutter database.
- Any destructive or hard-to-reverse schema change.
- Any remote service, sync, or network-backed storage feature.
- Raising the minimum supported macOS version.
