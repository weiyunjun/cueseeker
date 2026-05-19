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
- **P5.2 — Search result cards / groups (scope corrected 2026-05-19 from
  option A to option B: precise visual alignment to v6).** Correction record:
  option A was wrongly recommended by over-extending the C2 state-view visual
  deferral (which was state-views-only) to the Search cards, and by reading
  audit finding D ("steady-state not embryonic" = prototype/doc coverage is
  sufficient) as if it meant the App already matched v6 pixel-for-pixel. A UI
  rebuild's purpose is visual alignment, so the owner selected option B.
  Completed structural sub-commits stand: P5.2-1 swap `SearchResultCard`
  surface to the shared `LiquidGlassSelectableCard`; P5.2-2 excise the
  retained accent selected visual on card and shared `CardGroupHeader` (audit
  finding F); P5.2-3 retire the dead Search legacy row path (`resultsList`,
  `SearchResultGroupView`/`SearchResultGroupHeader`/`SearchResultRow`); P5.2-4
  remove the defunct thumbnail plumbing. **Added scope P5.2-B — precise
  visual alignment to the v6 prototype**: the `LiquidGlassSelectableCard`
  surface tokens (radius, fill, hairline, shadow, hover, pressed), the
  `SearchResultCard` content typography/spacing (`.meta` / `.line` / `mark`),
  the `CardGroupHeader`, and the results-header are aligned to the v6
  `.result-card` / `.group-header` / `.results-header` spec. Native material
  / scheme-adaptive color may stand in for CSS `backdrop-filter` per doc 11
  §10 and doc 12 §15 while preserving the accepted visual hierarchy; no
  hardcoded light values; colorScheme-driven. Non-visual invariants unchanged:
  query `<mark>` highlight semantics, `EqualHeightCardGridLayout` equal-height,
  lazy loading, first-screen, exact counts, group ordering/collapse,
  architecture §7 invalidation, seek / native render. `swift test` 94/94 and
  `swift build` green every step. Risk: medium-high (highest — easiest to
  regress Search first-screen/laziness/invalidation).
- **P5.3 — Library cards / groups / episode grid.** Rebuild folder group rows
  and the adaptive episode grid to the prototype; preserve grouping, natural
  sort, resume history, and the Library-launched playing indicator. `EP01`
  episode label format accepted (finding H resolved 2026-05-20). Library has
  no separable dead path; old code is replaced in place — see "P5.3 / P5.4
  Old-Code Audit & Deletion Plan". Risk: medium.
- **P5.4 — Shiori cards / groups.** Rebuild Shiori cards and group headers;
  preserve Shiori persistence, dedup, and open behavior. The dead Shiori
  legacy cluster and the orphaned `SearchLayout` enum are removed in dedicated
  cleanup commits before the visual rebuild (P5.4-1..4 then P5.4-B), per "P5.3
  / P5.4 Old-Code Audit & Deletion Plan". Risk: medium.
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
  at P5.3; recorded here, not unilaterally resolved. **Resolved (owner,
  2026-05-20): accept `EP01`** to match v6 and doc 12 §7.2; this closes the
  doc 12 §16 EP01 open question for P5.3.

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

## P5.2-B Confirmed Pixel Spec (2026-05-19)

Owner-reviewed and confirmed. Two areas implemented in one step: the Search
results page and the topbar. Values are from the v6 prototype CSS; light /
dark are both explicit (scheme-driven, no hardcoded light values; CSS
`backdrop-filter` realized with native scheme-adaptive color/shadow per doc 11
§10 / doc 12 §15 — NOT a frosted `Material`). Native-difference boundary: the
NSWindow traffic lights, window shell, and desktop are native and not aligned.

App-authoritative exception (owner decision): the subtitle `.line` font weight
and opacity are better in the App; the v6 prototype was updated to match the
App (`.line` → weight 600, opacity 0.88; commit `7c2ea1f`). Everything else
aligns App → v6.

Search result card:

- Radius 10; padding 13 horizontal / 11 vertical; inner gap 6 (meta→lines and
  between lines).
- Fill (explicit scheme color, not Material): light white @0.62 over the page;
  dark white @0.10. Hover: light white @0.82; dark white @0.15. Pressed:
  scale 0.995.
- Border 0.5px: light `rgba(0,0,0,0.08)`; dark `rgba(255,255,255,0.10)` (hover
  dark `0.14`).
- Shadow rest: light `0 1px 2px rgba(15,18,30,0.06)` + inset highlight
  `rgba(255,255,255,0.92)` / lowlight `rgba(255,255,255,0.22)`; dark
  `0 1px 2px rgba(0,0,0,0.22)`. Hover: light `0 4px 12px -4px
  rgba(15,18,30,0.14)`; dark `0 5px 14px -5px rgba(0,0,0,0.44)`.
- Meta row: 11px monospaced, tabular figures, color text-3 (light `#7a7c84` /
  dark `#aaa6b6`), letter-spacing −0.01em; rank/time space-between; rank gap 5.
- Line: 13.5px, **weight 600 / opacity 0.88 (App-authoritative)**, color
  text (light `#1a1a1f` / dark `#f3f1f6`), line-height 1.4.
- Highlight `<mark>`: bg light `rgba(255,204,0,0.42)` / dark
  `rgba(255,214,92,0.32)`; text light `#4a3300` / dark `#fff0b5`; padding
  1px 3px; radius 3.

Group header / group / results-header:

- Group: padding 14 top / 6 bottom; bottom hairline 0.5px light
  `rgba(0,0,0,0.05)` / dark `rgba(255,255,255,0.07)`; margin-bottom 6.
- Group-header: flex gap 8; padding 5 8 5 4; radius 7; subtle hover bg;
  active scale 0.995. Chevron 16pt, color text-3, 0°/90° over 160ms.
- Group-title: 13px weight 600, **full text color** (not dimmed), letter-
  spacing −0.005em. Group-count: text-3, 11.5px, tabular.
- Results-header: padding 14 24 6; summary 12.5px color text-2 (light
  `#4d4e55` / dark `#c9c6d2`); count `strong` full text color, weight 600,
  tabular. Content horizontal padding 24.
- Collapse All: pill min-width 92, height 26, radius 999, 0.5px pill border,
  pill fill + pill shadow, 11.5px; hover pill-hover; active scale 0.94.

Topbar (traffic lights NOT changed — native):

- Toolbar bg: top-light gradient (light `rgba(255,255,255,0.35)` →
  `rgba(255,255,255,0.10)`; dark the corresponding low-white); bottom border
  0.5px light `rgba(0,0,0,0.06)` / dark equivalent.
- Tool buttons (folder / bookmark = `LiquidGlassIconButton.Kind.topbar`):
  30×26, radius 7, transparent; hover fill white @0.55 + inset highlight
  white @0.8 + ring 0.5px `rgba(0,0,0,0.06)`; active scale 0.94; selected
  white @0.7.
- Search field (`LiquidGlassSearchField`, `ui-input-capsule`): height 30,
  radius 999 (capsule), fill white @0.55, shadow inset highlight white @0.9 +
  inset lowlight white @0.25 + ring 0.5px `rgba(0,0,0,0.07)` + drop
  `0 1px 2px rgba(0,0,0,0.04)`; padding 0 10 0 12; gap 8; magnifier color
  `rgba(0,0,0,0.45)`; input 13.5px.
- Search field focus: fill white @0.85; ring 0.5px accent @0.55 + glow
  `0 0 0 3.5px` accent @0.18 (accent light `#0a84ff` / dark `#6ea6ff`).
- All topbar values scheme-adaptive for dark.

Page background: light `#f4f4f6` / dark `#1f2027` (replaces the current pure
`.textBackgroundColor`) so the near-white cards read as elevated.

## P5.3 / P5.4 Old-Code Audit & Deletion Plan (2026-05-20)

Read-only audit of `SearchView.swift` on `native-macos-rewrite` (HEAD
`ae2a424`). Establishes which old code each surface step removes and when, so
deletion is never mixed with visual change (git workflow §3) and the proven
P5.2 sub-commit sequence is reused.

- **Library has no separable dead path.** `libraryList` →
  `LibraryFolderGroupView` / `LibraryFolderHeader` / `LibraryEpisodeGrid` /
  `LibraryEpisodeButton` is the only path and is live. P5.3 is an in-place
  visual rebuild; old-code removal is intrinsic to the rebuild commit. There
  is no pre-deletion step for Library.
- **Shiori has a dead legacy cluster — structurally the Search legacy that
  P5.2-3 retired.** Live path: `shioriPanel` → `shioriCardList` →
  `ShioriCardGroupView`. Dead (no call site; `shioriList` is defined but never
  rendered because `shioriPanel` uses `shioriCardList`):
  - `shioriList` (the unrendered legacy list var)
  - `ShioriGroupHeader`, `ShioriGroupView`, `ShioriRowView`
  - `SearchResultGroupRail` — misleadingly named; its only caller is the dead
    `ShioriGroupView`, so it is dead Shiori code, not Search code
  - the entire `SearchLayout` enum — every constant is referenced only by the
    dead cluster above, so it is fully orphaned once the cluster is removed

  ≈200 lines (≈15% of `SearchView.swift`). Zero-risk: no call site, and every
  `AppState` member the dead `shioriList` touches is also used by the live
  `shioriCardList`, so removal orphans nothing in `AppState` / `SettingsView`
  (cleaner than the Search thumbnail plumbing removed in P5.2-4).
- **Shared symbols that must NOT be removed with the Shiori cluster.**
  `displayTitleWithSoftWrapOpportunities` is shared (the live `CardGroupHeader`
  and the dead `ShioriGroupHeader` both call it); `SearchTypography` is used
  throughout the live Library / Search code. Both are kept.
- **Finding F for Shiori is not dead-code removal.** The live `ShioriCard`
  still fills the selected card with `Color.accentColor` and `selectedShiori`
  is still plumbed into the live `ShioriCardGroupView` (P5.0 audit finding F,
  doc 11 §7). Excising this is a behavior/visual change inside the P5.4 visual
  rebuild (mirrors P5.2-2), not the pre-delete cleanup.

Deletion timing (decision):

- **P5.3 (Library):** no pre-deletion; the current live implementation is
  replaced in place within the visual rebuild commit(s).
- **P5.4 (Shiori):** delete the dead cluster + orphaned `SearchLayout` as
  dedicated cleanup commits BEFORE the visual rebuild, mirroring P5.2-3 /
  P5.2-4 and satisfying git workflow §3. Sub-commit shape per surface, reusing
  the owner-accepted P5.2 sequence:
  - P5.4-1 — swap `ShioriCard` surface to the shared
    `LiquidGlassSelectableCard`
  - P5.4-2 — excise the retained accent selected visual and `selectedShiori`
    plumbing on the live Shiori card / shared `CardGroupHeader` (finding F)
  - P5.4-3 — retire the dead Shiori legacy cluster (`shioriList`,
    `ShioriGroupView` / `ShioriGroupHeader` / `ShioriRowView`,
    `SearchResultGroupRail`)
  - P5.4-4 — remove the orphaned `SearchLayout` enum
  - P5.4-B — precise visual alignment to the v6 Shiori card / group spec
  P5.3 reuses the same shape minus the dead-path / orphan steps (no P5.3-3 /
  P5.3-4).
- The concrete P5.3 / P5.4-B pixel values are not invented here. Like P5.2-B
  they require a v6-prototype-derived, owner-confirmed "Confirmed Pixel Spec"
  sub-section added before the P5.3-B / P5.4-B App code (Step Document Rule),
  with the doc 11 / doc 12 mapping updates done first per git workflow §10.

## P5.3 / P5.4 Confirmed Pixel Spec (2026-05-20)

Owner-reviewed and confirmed. Values are from the v6 prototype CSS (extracted,
then the prototype was updated to match the three owner decisions below). Same
native-difference boundary as P5.2-B: light / dark both explicit, scheme-
driven, no hardcoded light values; CSS `backdrop-filter` realized with native
scheme-adaptive color/shadow (NOT a frosted `Material`); NSWindow traffic
lights and window shell stay native. Empty / loading / failed / no-videos /
no-shiori **state views are out of this spec** — deferred to a later visual
pass per doc 12 §6.1/§7.1/§8 and "P5.0 C2"; this spec covers cards / groups /
grid only, exactly the P5.2-B scope.

Shared, unchanged from P5.2-B (Library and Shiori inherit, no new values):

- Page background light `#f4f4f6` / dark `#1f2027`.
- Authoritative card token skin: fill light white @0.62 / dark white @0.10;
  hover light white @0.82 / dark white @0.15; selected-fill light white @0.92
  / dark white @0.18. Rest shadow light `inset 0 .5px 0 rgba(255,255,255,.92)`
  + `inset 0 -.5px 0 rgba(255,255,255,.22)` + ring `rgba(0,0,0,.08)` + `0 1px
  2px rgba(15,18,30,.06)`; dark `inset 0 .5px 0 rgba(255,255,255,.18)` + `inset
  0 -.5px 0 rgba(255,255,255,.05)` + ring `rgba(255,255,255,.10)` + `0 1px 2px
  rgba(0,0,0,.22)`. Hover shadow light `…ring rgba(0,0,0,.08), 0 4px 12px -4px
  rgba(15,18,30,.14)`; dark `…ring rgba(255,255,255,.14), 0 5px 14px -5px
  rgba(0,0,0,.44)`.

P5.4-B — Shiori (no new pixel values):

- The v6 markup `result-card shiori-card ui-selectable-card` has **no
  `.shiori-card` rule**: the Shiori card is the P5.2-B "Search result card"
  spec verbatim (radius 10; padding 13h / 11v; gap 6; `.meta` 11px monospaced
  tabular text-3 letter-spacing −0.01em; `.line` 13.5px weight 600 opacity
  0.88 App-authoritative; `<mark>` highlight per P5.2-B).
- Group header / group / results-header / Collapse All: the P5.2-B "Group
  header / group / results-header" spec verbatim (shared `.group` /
  `.group-header` / `.group-title` / `.group-count` / `.results-header` /
  `.small-button`); content horizontal padding 24.
- The only Shiori delta vs Search: **no retained selected visual** — the
  `.result-card.selected` accent-ring is not applied (finding F; excised in
  P5.4-2). Hover + pressed (scale 0.995) only.

P5.3-B — Library (distinct values):

- Scroll padding 4 top / 24 horizontal / 120 bottom — unified with the Search
  content padding (owner decision 1; v6 prototype updated, commit `71b13f2`).
- `.library-group`: padding 12 top / 10 bottom; **no bottom hairline** (unlike
  Search `.group`); margin-bottom 6.
- `.library-group-header` (extends shared `.group-header`): align-items
  flex-start; gap 10; padding 8 8 8 4; max width `min(100%, 720px)`; radius 7;
  transparent, subtle hover bg, transition 100ms. Chevron shared 16pt text-3,
  0° collapsed / 90° expanded over 160ms; header chevron margin-top 2.
- Folder two-line block `.library-heading`: column, gap 2, min-width 0.
  `.library-title` text color, 13.5px, **weight 700**, line-height 1.2.
  `.library-count` text-3, 12px, line-height 1.2 (the doc 12 §7.1 `Playing M`
  suffix lives on this count line).
- `.library-episode-grid`: flex-wrap, gap 10, margin 8 top / 0 right / 12
  bottom / **30 left** (the 30px left indent expresses folder→episode
  hierarchy).
- `.library-episode-card` (`ui-selectable-card`): height 42, **min-width 66
  with 0 / 14 horizontal padding** so short ranks (`EP01`) stay compact while
  long ranks (`EP120`) widen instead of truncating (owner decision 2; v6
  prototype updated, commit `71b13f2`); radius 8; fill / hover / shadows = the
  shared card token skin above; label color text, 12.5px **weight 700**,
  tabular, centered. Active: scale 0.96.
- `.library-episode-card.selected` is the **Library-launched "Playing"
  indicator**, not finding F: selected-fill + `outline 2px solid` accent
  (light `#0a84ff` / dark `#6ea6ff`), `outline-offset -2px`, `box-shadow:
  none`, label color `text-on-selected-card` (light `#0a1426` / dark
  `#f8f6fb`). This retained visual is mandated by doc 12 §7.2 (playing state,
  Library-launched playback only) and must NOT be excised — finding F forbids
  retained *selection* visuals on Search/Shiori cards, a different concept.

Owner decisions (2026-05-20):

1. Library scroll/content padding **unified with Search** (4 top / 24
   horizontal / 120 bottom); the v6 prototype was updated to match.
2. Library episode card width is **content-driven** — fixed height 42, min-
   width 66, 14px horizontal padding so long ranks (`EP120`) widen rather than
   truncate; the v6 prototype was updated to match and doc 12 §7.2 records the
   UX rule.
3. `.library-group` keeping **no bottom hairline** while Search groups have one
   is **accepted** as an intentional surface difference; no prototype change.

These resolve all P5.3 / P5.4 pixel open points. With the v6 prototype and the
doc 11 / doc 12 mapping updated, this is the confirmed single source for the
P5.3-B / P5.4-B visuals; App implementation remains gated on explicit owner
approval (Step Document Rule).

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

Closeout (2026-05-20): all acceptance criteria met. P5.0–P5.5 complete;
`swift test` 94/94 and `swift build` green at every step; the project-owner
real-machine end-to-end regression and the P5.3 / P5.4 prototype visual
acceptance passed. Phase 5 is accepted and closed (recorded in
`docs/changelog.md`).

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
