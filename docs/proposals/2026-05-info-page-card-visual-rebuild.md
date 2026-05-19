# Info-Page Card Visual Rebuild (Rewrite-Plan Phase 5)

Status: Accepted

Accepted (2026-05-19): the step structure (P5.0–P5.5), the audit-first /
reuse-v6 prototype strategy, and this document's location were approved by the
project owner on 2026-05-19, and P5.0 was authorized to begin. This document is
the authoritative App step plan for Phase 5. The confirmed P5.0 audit is
recorded in "P5.0 Confirmed Audit (2026-05-19)" below.

## Relationship To Existing Plans

This is the **separate new independent proposal** that
`docs/proposals/2026-05-native-app-ui-ux-rewrite-plan.md` ("Implementation
Status And Remaining Roadmap") and
`docs/proposals/2026-05-ui-info-page-video-page-refactor.md` ("Status And
Remaining Roadmap") defer Phase 5 to. It is the final net-new UI stage of the
Liquid Glass rewrite.

Inherits (unchanged discipline):

- Replacement rewrite, not patching; the HTML prototype and the mapping
  documents are the source of truth; `swift test` must pass.
- Non-UI behavior preserved: Search pipeline, Library state, Shiori
  persistence, playback/seek/native render path.
- Settings is excluded.
- Doc-first / prototype-first ordering, per-step commits with before/after
  short hashes, benchmark honesty.

Does not supersede: the video-page refactor (complete) or any backend/ADR
decision. The video-page S7 already consumed rewrite-plan Phase 6; Phase 5
needs its own regression closeout (P5.5).

## Background And Audit Findings (2026-05-19)

The info page (Search / Library / Shiori) already renders content; Phase 5 is a
**visual reconciliation to the accepted Liquid Glass prototype, not greenfield**.

Audit findings:

- A card path already exists: `SearchResultCardGroupView`/`SearchResultCard`,
  `ShioriCardGroupView`/`ShioriCard`, `LibraryFolderGroupView` /
  `LibraryEpisodeGrid` / `LibraryEpisodeButton`, `CardGroupHeader`,
  `EqualHeightCardGridLayout`.
- A legacy row path also exists in parallel (`SearchResultGroupView` /
  `SearchResultRow` / `ShioriGroupView` / `ShioriRowView`, thumbnail-bearing).
  Resolving which path the info page uses and retiring the superseded one is an
  explicit P5.0 audit deliverable.
- The Search data pipeline is intact and must not be disturbed: lazy loading
  (`loadMoreSearchResultsIfNeeded`), `searchResultGroups`, `LazyVStack`,
  exact counts, group ordering/collapse, first-screen rendering.
- The v6 prototype already defines the accepted card visuals
  (`result-card`, `shiori-card`, `library-episode-card`, `library-group`,
  `ui-selectable-card`, `results-header`), and doc 12 §6.3/§6.4/§7/§8 plus
  doc 11 already specify the card UX and component ownership.

## Prototype Strategy (approved: audit-first, reuse v6)

The accepted `ui/prototypes/cueseeker-liquid-glass-v6/` prototype plus doc 12
§6/§7/§8 and doc 11 are the visual authority. P5.0 audits coverage. A v6
refinement (and `standalone.html` regeneration) and mapping-doc updates are
made **only where the audit finds the card design genuinely embryonic or
divergent**; otherwise the existing v6 + mapping is recorded as the accepted
authority with no prototype change. A new v7 is created only if the audit shows
v6 cannot express the accepted card design.

## Goals

- Search, Library, and Shiori main surfaces visually match the accepted
  prototype, including hover, pressed, selected, empty, loading, and
  no-results states.
- Retire the superseded legacy row path once the card path is the accepted
  design.
- Preserve every non-UI behavior and invalidation boundary.

## Non-goals

- No change to Search ranking, query parsing, lazy loading, first-screen
  rendering, exact counts, or result ordering.
- No change to Library grouping/natural sort/resume history or Shiori
  persistence/dedup.
- No playback / seek / native render change. No Settings redesign.
- No memory/CPU optimization (deferred by owner decision to post-UI).

## Non-Negotiables (every step)

- `swift test` stays green (94/94, Core/Playback logic) **and `swift build`
  succeeds** for every App-touching step. `swift test` does not compile
  `CueSeekerApp` (no test target depends on it), so the App build is the gate
  that catches UI compile breaks (gate strengthened 2026-05-19). Each step is
  its own commit reporting before/after short hashes; work lands on
  `native-macos-rewrite`.
- Presentation-only: swap card visuals without touching the data pipelines;
  product semantics stay in `AppState`/product-domain, not views (arch
  §2.2/§7).
- Preserve architecture §7 invalidation domains: switching modes, collapse/
  expand, and playback must not rebuild unrelated Search/Library/Shiori rows;
  laziness and first-screen must not regress; avoid dense per-row `NSButton`
  layout.
- Main-page cards must not retain playback selection visuals (doc 12 §6.4,
  doc 11 §5 `ui-is-selected`).
- Do not touch the seek / native render path. Doc-first if any step/rule/
  acceptance changes; benchmark honesty (regression → default revert +
  documented result, no silent reinterpretation).
- This environment has no GUI: visual/behavioral acceptance is the project
  owner's real-machine check.

## App Implementation Steps (P5.0–P5.5)

- **P5.0 — Doc-first audit + this proposal + prototype reconciliation (no App
  code).** Audit v6 / doc 12 §6.3·6.4·§7·§8 / doc 11 coverage vs embryonic
  gaps; resolve the card-vs-row reality and the retirement plan for the legacy
  path; refine v6 + mapping docs only if gaps are found (regenerate
  `standalone.html`); reconcile architecture §7; obtain explicit App-
  implementation approval before any App code. Risk: low.
- **P5.1 — Shared card component + control states (scope clarified
  2026-05-19, owner option (a)).** A native Liquid Glass card (doc 11
  `LiquidGlassSelectableCard` / `ui-selectable-card`) with hover / pressed /
  selected / disabled, colorScheme-token driven (fix any hardcoded light
  values, as the overlay panel required). The shared empty / loading /
  no-results state views are **converged into one shared owner** (single
  source for the App-condition→state mapping) **without visual redesign**:
  the current `EmptyStateView` visual is preserved; the demo-aligned,
  native-leaning state-view visual is deferred to a later visual pass per the
  "P5.0 C2" owner scope ruling. No data/behavior change; no seek / native
  render change; architecture §7 invalidation domains preserved;
  `swift test` green. Surface adoption of the shared card is P5.2–P5.4.
  Risk: low–medium.
- **P5.2 — Search result cards / groups (scope confirmed 2026-05-19, owner
  option A).** Swap the `SearchResultCard` surface to the shared
  `LiquidGlassSelectableCard` (colorScheme/token driven) and rebuild the
  Search group header to v6 (chevron 0°/90° over 160ms, muted count, one
  click target); **excise the retained accent selected visual** (audit
  finding F) so main pages keep no playback selection visual. Card content,
  query `<mark>` highlight, `EqualHeightCardGridLayout` equal-height, lazy
  loading, first-screen, exact counts, and group ordering/collapse are
  unchanged — not a pixel-level redesign beyond v6. Then, as separate commits
  within P5.2: retire the dead Search legacy row path (`resultsList`,
  `SearchResultGroupView` / `SearchResultGroupHeader` /
  `SearchResultGroupRail` / `SearchResultRow`); and remove the now-defunct
  thumbnail plumbing (`searchResultThumbnailsEnabled` AppState property +
  UserDefaults key + SettingsView toggle — permitted cleanup, not a Settings
  redesign; doc 12 §6.2 already reversed). Sub-commits: P5.2-1 card surface +
  selected-visual excision, P5.2-2 group header, P5.2-3 dead-row retirement,
  P5.2-4 thumbnail plumbing removal. Risk: medium-high (highest — easiest to
  regress Search first-screen/laziness/invalidation).
- **P5.3 — Library cards / groups / episode grid.** Rebuild folder group rows
  and the adaptive episode grid to the prototype; preserve grouping, natural
  sort, resume history, and the Library-launched playing indicator. Risk:
  medium.
- **P5.4 — Shiori cards / groups.** Rebuild Shiori cards and group headers;
  preserve Shiori persistence, dedup, and open behavior. Risk: medium.
- **P5.5 — Main-page states + cross-surface polish + regression + changelog.**
  Verify empty/loading/failed/no-results across all three surfaces, no
  retained playback selection visuals, dark mode, and §7 invalidation
  boundaries; `swift test`; project-owner real-machine end-to-end regression;
  update `docs/changelog.md` (Phase 5 is its own milestone; this proposal's
  closeout). Risk: medium.

Dependencies: P5.0 first (doc-first gate, blocks all App code). P5.1 before
P5.2–P5.4. P5.2 / P5.3 / P5.4 are independent and parallelizable as separate
commits. P5.5 last. Legacy row-path retirement happens within whichever
surface step supersedes it, or as an explicit P5.5 cleanup, never mixed with
unrelated visual changes.

## P5.0 Confirmed Audit (2026-05-19)

Confirmed by read-only inspection of the v6 prototype, doc 11/12, and
`SearchView.swift` on `native-macos-rewrite` (HEAD 9b79ad2).

- **A. Card path live, legacy row path dead.** The info page renders the card
  path only: `cardResultsList`→`SearchResultCardGroupView`,
  `shioriCardList`→`ShioriCardGroupView`,
  `libraryList`→`LibraryFolderGroupView`. The legacy row path (`resultsList`,
  `shioriList`, and structs `SearchResultGroupView`/`SearchResultGroupHeader`/
  `SearchResultGroupRail`/`SearchResultRow`, `ShioriGroupView`/
  `ShioriGroupHeader`/`ShioriRowView`) has no call site in the primary
  checkout. Retirement = delete those unreferenced structs within the
  superseding surface step (P5.2/P5.4) or as explicit P5.5 cleanup, never mixed
  with unrelated visual changes.
- **B. Thumbnails not retained (owner decision 2026-05-19).** The dead row path
  was the only thumbnail consumer (`SearchView.swift:397`), but
  `searchResultThumbnailsEnabled` is an `AppState` persisted setting
  (`AppState.swift`) exposed as a user toggle (`SettingsView.swift:320`).
  Removal spans AppState + SettingsView + the dead SearchView path. doc 12 §6.2
  ("thumbnails remain controlled by the existing experimental setting") is
  reversed and must be updated doc-first. The App removal is a gated App step
  (with the row-path retirement), not P5.0; it is permitted cleanup, not a
  Settings redesign, and is called out so it is not treated as scope creep.
- **C. v6 lacks non-steady-state mockups.** v6 `index.html` has no empty /
  loading / failed / no-results mockups for Search / Library / Shiori; the App
  uses a generic `EmptyStateView`. doc 12 §6.1 and this proposal's acceptance
  require these states to match the prototype. A static prototype cannot
  exercise the searching/loading or failed states for review. Owner decision
  2026-05-19: instead of static mockups in v6, build a separate interactive
  state-demo prototype (buttons trigger each state/animation) so the owner
  reviews by clicking; see "P5.0 C2 — Interactive State-Demo Prototype" below.
- **D. Two `.result-card` blocks = base + token-override of the same card,
  not surface-vs-surface.** The video-page overlay/middle panel does not use
  `.result-card`; it uses `.sidebar-row` / `ui-selectable-row`. styles.css
  L563 is the structural + hardcoded-light base; L1758 is a later token layer
  (`var(--card-bg/--card-shadow/--card-hover-*/--card-selected-bg)`) that wins
  and is the authoritative theme-driven skin. Native must be
  colorScheme/token-driven and must not replicate L563's literal
  `rgba(255,255,255,*)` values (P5.1 hazard).
- **E. doc 11 §8 token-mapping gap.** §8 maps `--glass-*`/`--text*`/`--accent*`/
  `--highlight*`/`--search-page-*` but has no `--card-*` / `--row-*` /
  `--card-selected-*` row, so the authoritative card skin (finding D) is
  unmapped. Add a semantic selectable-card surface token-mapping row doc-first.
- **F. Current App violates the no-retained-selection invariant.**
  `selectedResult`/`selectedShiori` are NOT dead params: `SearchResultCard`
  fills `Color.accentColor` with white text when `isSelected`
  (`SearchView.swift:1017-1025`, `955-958`), `ShioriCard` likewise, and
  `CardGroupHeader` emphasizes the title for the selected group
  (`SearchView.swift:931`). This is a retained playback-selection visual on
  main pages, violating doc 12 §6.4 / doc 11 §5·§7 and the Non-Negotiables, and
  confirms the owner's point that the Search page must have no selected effect.
  The `isSelected`/`selected*` plumbing into the main cards and
  `CardGroupHeader` must be excised in P5.2 (Search) / P5.4 (Shiori).
- **G. Architecture §7 reconcile.** §7 / §7.1 invalidation-domain,
  flattened-lazy-row, and no-dense-`NSButton` rules already cover Phase 5; the
  card path already uses `LazyVStack` + `EqualHeightCardGridLayout`. No §7 /
  §7.1 edit is required; the row-path retirement and selected-visual excision
  must preserve these rules.
- **H. doc 12 §16 open question (EP01).** Library episode label format (`EP01`
  vs numeric rank) is still an open review question; v6 and doc 12 §7.2 use
  `EP01`. Recommended resolution: accept `EP01` to match v6. Owner to confirm
  at P5.3; recorded here, not unilaterally resolved.

Doc-first follow-ups before any App code: build the interactive state-demo
prototype (finding C, see below); update doc 12 §6.1 and §6.2 with the
App-condition→state mapping (findings B, C); add the doc 11 §8 card-token row
and a doc 11 §5/§7 note that the current App must drop the retained selected
visual (findings E, F). Then request explicit App-implementation approval (the
P5.0 gate) before P5.1.

## P5.0 C2 — Interactive State-Demo Prototype (owner decision 2026-05-19)

Rationale: a static prototype cannot exercise the searching/loading or failed
states, so the owner cannot review them by reading markup. C2 produces a
separate interactive demo whose buttons switch each surface between its states
(including animated loading), reviewed by opening the self-contained
`standalone.html` and clicking.

Location and structure: a separate folder outside `ui/prototypes/`, by owner
direction — `ui/state-demos/info-page-card-states/`, structured like the v6
prototype: `index.html` + `styles.css` + `script.js` + `standalone.html`
(self-contained share artifact). It reuses the v6 token system and card/header
visual language so states match the accepted card design. This is a focused
split prototype permitted by `docs/engineering/02_git_workflow.md` §10
(documented complex-prototype reason / split focused prototypes); the only
deviation is the location outside `ui/prototypes/`, recorded here as the
documented reason. Follow-up flag: doc 02 §10 currently says prototypes live
under `ui/prototypes/`; a one-line amendment allowing owner-directed
interactive demos in a sibling `ui/` folder is proposed but not made
unilaterally.

States the demo must reproduce (mirrors the real App; condition → state, copy
verbatim from `SearchView.swift`):

- Search: query empty → "No Search Query"; `.searching` & no results →
  "Searching" (animated spinner); `.failed(msg)` & no results → "Search
  Failed" (shows error); completed & 0 matches → "No Results"; results
  present → card list; `.searching` & results present → card list with a
  bottom "loading more" spinner.
- Library: no selected folders → "No Library"; `libraryStatus .loading` & no
  videos → "Loading Library" (animated spinner); `libraryStatus .failed(msg)`
  → "Library Failed"; videos empty → "No Videos"; videos present →
  folder/episode list.
- Shiori: `shioris` empty → "No Shiori"; shioris present → card list. (The App
  has no Shiori loading/failed state; the demo must not invent one.)

The App-condition → state mapping is owned by the mapping docs (doc 12 §6.1 and
surface sections) and is updated in C3, after the owner reviews the demo.

Owner scope ruling (2026-05-19, after reviewing the demo): C2 is accepted as
the **provisional** plan. The demo is authoritative only for **which state
appears under which App condition and whether it animates** — not for the
final pixel-level visual of the state views. Known difference (deferred): the
demo's state-view treatment leans native and diverges from the accepted Liquid
Glass card visual language; pixel-level visual reconciliation of these state
views is **out of the current Phase 5 scope** (current scope is layout
restructuring and operation optimization) and is deferred to a later visual
pass. C3 records this divergence and deferral in the mapping docs per the
git-workflow "known differences" rule; no App visual optimization of the state
views is done now.

## Acceptance

- Main Search / Library / Shiori cards and their hover/pressed/selected/
  empty/loading/no-results states match the accepted prototype.
- Main pages retain no playback selection visuals.
- Search lazy loading, first-screen rendering, exact counts, and ordering are
  unchanged; Library resume history and Shiori persistence are unchanged.
- Switching modes / collapse / playback does not rebuild unrelated rows or
  regress laziness (architecture §7).
- The seek / native render path is untouched; `swift test` passes; the
  project owner's real-machine regression passes.

## Step Document Rule

This document is the authoritative App step plan for Phase 5. If a decision,
step, sequence, or acceptance criterion changes, update this document (and the
relevant mapping/ADR documents) before changing App code.

## Decision

Accepted (2026-05-19). The step structure and prototype strategy were approved
2026-05-19 and P5.0 was authorized to begin; the confirmed P5.0 audit is
recorded above. Implementation proceeds with the P5.0 doc-first follow-ups
(the interactive state-demo prototype, doc 12 §6.1/§6.2, doc 11 §8/§5/§7),
then the P5.0 App-implementation-approval gate, then P5.1.
