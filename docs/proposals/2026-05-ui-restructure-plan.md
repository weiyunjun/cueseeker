# UI Restructure Plan

Status: Accepted; Phases 0, 3, 1, 2 all implemented. `ui/restructure` branch
not merged to main — UI detail alignment continues on the same branch.

## Background

The `apps/macos-native/Sources/CueSeekerApp/` SwiftUI layer grew to a point
where ordinary UI work was being slowed down by three coupled problems:

- `AppState.swift` was ~3700 lines and held ~40 `@Published` properties
  spanning seven different product domains. Any mutation in one domain forced
  SwiftUI to re-evaluate views in unrelated domains, and every code change had
  to be reasoned about against the same flat namespace.
- Several view files had grown past 1000 lines (`PlaybackPageView.swift` 1687,
  `SearchView.swift` 1209, `SettingsView.swift` 846), making it hard to find
  or change a single visual element without scrolling through unrelated code.
- All view files were flat under `Sources/CueSeekerApp/`. Feature ownership
  was implicit; searching was the only way to locate code for a given panel.

`docs/engineering/04_architecture_rules.md` §7 already anticipated this
direction ("A single broad observable object may coordinate workflows, but
large SwiftUI views must not subscribe to unrelated high-frequency or
high-cardinality state when a smaller store, value model, or binding can
express the same UI responsibility."). This proposal records the concrete
plan that operationalized that rule on the `ui/restructure` branch.

## Goals

- Reduce SwiftUI invalidation fan-out so per-domain mutation invalidates only
  per-domain subscribers.
- Make every UI file's domain ownership explicit through folder structure.
- Cap view files at a size where a reader can grasp them in one screen.
- Preserve all behavior; the restructure must be a structural refactor with
  no functional change at each step.

## Non-goals

- Do not move product semantics into a different module. CueSeekerCore
  remains the home of database/index/parser/search behavior; the per-domain
  stores added by this plan are presentation-layer organization only.
- Do not introduce Rust shared-core scaffolding (per
  `04_architecture_rules.md` §2.2; shared-core work is paused).
- Do not redesign UX, polish visual style, or change keyboard shortcuts.
  Liquid Glass mapping and behavioral docs (11, 12) remain authoritative.
- Do not change the dependency graph between CueSeekerApp,
  CueSeekerPlayback, CASSRendering, and CueSeekerCore.

## Sequence

Implemented in the order **Phase 0 → Phase 3 → Phase 1 → Phase 2**: make
space (folder structure) before moving anything; extract state into stores
once each feature has a home; split large view files last so the splits land
in the right folders against the right stores. Each step is a small atomic
commit with `swift build` and `swift test` green at every commit.

### Phase 0 — Baseline (Implemented)

Anchor commit `f379ff6 Refactor: baseline before UI restructure`. Verifies
build clean, 95/95 tests pass, and Package.swift CueSeekerApp target uses
default source discovery so subdirectory moves do not require manifest edits.

### Phase 3 — File reorganization (Implemented)

Eight `git mv` commits (`3.1` through `3.8`, `2c6beed` → `80b2a22`) move the
26 flat files under `Sources/CueSeekerApp/` into nine feature subdirectories:

```text
Sources/CueSeekerApp/
  App/         AppDelegate, main, AppCoordinator (still named AppState here),
               AppLogDirectory
  Workbench/   ContentView, TitlebarBackgroundView, InfoPageStateView
  Search/      SearchView, SearchTextView, TopbarSearchInputState,
               SearchPerformanceLogger
  Playback/    PlaybackPageView, PlaybackView, PlaybackViewModel,
               PlaybackFullscreenManager, PlaybackChromeVisibilityModel,
               PlaybackFeedbackOverlay
  Settings/    SettingsView
  Media/       ThumbnailCache, ThumbnailGenerator
  Shared/      HoverEffectModifier, EmptyStateView, LiquidGlassSelectableCard
  Diagnostics/ AppPerformanceProbe, LayoutPerformanceProbeView,
               UIInvalidationProbe
  Library/     (empty placeholder; Library views still live inside SearchView
               at this stage)
  Shiori/      (empty placeholder; same reason)
```

Every commit is a pure `git mv`, no content edits, build green.

### Phase 1 — Store extraction (Implemented)

Nine commits (`1.1` through `1.9`, `428b275` → `b19405e`) split the 40+
`@Published` properties on `AppState` into seven per-domain stores. The
god object becomes a thin coordinator.

- **1.1 SettingsStore** — `appAppearanceMode`, `playbackDecodeMode`,
  `searchE2ELoggingEnabled`, `searchFTSVocabularyDiagnosticsEnabled`. Cross-
  domain side effects (decode mode → player, FTS toggle off → cancel
  diagnostics task) move from didSet to Combine subscriptions in AppState.
- **1.2 IndexingStore** — `selectedFolders`, `indexingStatus`,
  `databaseStorageStats`, `databaseMaintenanceStatus`,
  `searchFTSVocabularyDiagnostics*`. Folder add/remove + UserDefaults
  persistence encapsulated; FTS diagnostics task moves into IndexingStore
  and the settings-toggle subscription moves with it.
- **1.3 WorkbenchLayoutState** — `panelMode`, `isVideoSizeTransitionInProgress`,
  `isAppFullscreen`, `isSearchFocused`, `clearSearchFocus()`. The class
  already existed for panel mode; this step folds in search focus.
- **1.4 ShioriStore** — `shioris`, `shioriFileGroups`, `selectedShiori`,
  `collapsedShioriGroupPaths` plus three derived counts. Static helpers
  (`makeShioriFileGroups`, `shioriSort`) stay on AppCoordinator because
  `shioriSort` calls a private static on AppCoordinator.
- **1.5 LibraryStore** — `libraryStatus`, `libraryVideos`,
  `libraryFolderGroups`, `libraryPresentationRevision`,
  `selectedLibraryVideo`. Pure state container.
- **1.6 SearchStore** — 17 `@Published` properties plus five derived computed
  properties (`isSearching`, `hasSearchResultGroups`, `searchResultFileCount`,
  `canCollapseAllSearchResultGroups`, `shouldShowSearchGlobalLoadMoreTrigger`).
  Search orchestration (start, paginate, group rebuild) stays in
  AppCoordinator along with the internal pagination cursors
  (`nextGlobalSearchCursor`, `loadedGlobalSearchResultCount`) and
  `searchGlobalLoadMoreTriggerID` which reads them.
- **1.7 PlaybackStore** — `currentSubtitleEntries`,
  `currentSubtitleEntryLookup`, `playbackStatus`, `isPlaybackSurfaceExpanded`,
  `isPlaybackSidePanelVisible`, `playbackViewModel`. All playback
  orchestration (`ensurePlayerInitialized`, `seekCurrentPlayback`,
  fullscreen coordination, Shiori toggle, subtitle copy, library playback
  history) stays in AppCoordinator and writes through `playback.X`.
- **1.8 AppCoordinator rename + env audit** — `AppState` → `AppCoordinator`
  with a temporary `typealias AppState = AppCoordinator` for the rename
  commit. Crucially, every SwiftUI view that reads a cross-store AppCoordinator
  computed property is audited and given `@EnvironmentObject` for the
  underlying stores. The audit was triggered by the `ContentRootView`
  top-bar regression (`39e059b`), which surfaced the general rule that
  AppCoordinator does not republish child store changes (it holds them as
  `let`), so any view reading e.g. `coordinator.isPlaybackPageVisible` must
  also observe `PlaybackStore`.
- **1.9 Finalize** — Drop the typealias, rename all 16 `AppState`
  type references to `AppCoordinator`, update
  `docs/engineering/04_architecture_rules.md` §7 and `docs/changelog.md`
  Unreleased entry. Active product mapping docs (08, 11, 12) had their
  remaining `AppState.X` references replaced with the correct
  `AppCoordinator` / `<Store>.X` names in a follow-up commit.

Per-commit verification at Phase 1: `swift build` green, `swift test` 95/95,
plus a manual end-to-end pass by the project owner with Codex code review
on each commit.

### Phase 2 — View file split (Implemented)

The three remaining large view files are split into one focused file per
SwiftUI struct. 2.a and 2.b are pure file-level moves with `private`
visibility widened to `internal` where a moved type now lives in a different
file from its callers. 2.c required actual restructuring (inline computed
properties became separate `Category` structs that own their own `@State` /
`@EnvironmentObject` / `.alert`), because the categories were not standalone
structs in the original `SettingsView.swift`.

Per-commit verification at Phase 2: `swift build` green, `swift test` 95/95,
`git diff --check` clean, plus the project owner's end-to-end real-machine
regression after every sub-step (2.a, 2.b, 2.c) with Codex code review on
each block. Actual commit count: 29 (vs. estimated 15) — 2.a went more
granular than planned to keep each commit auditable.

#### 2.a `Playback/PlaybackPageView.swift` (~1687 lines → 113-line shell + 13 files; commits `8a6764e` → `24433b2`)

Split layout:

```text
Playback/
  PlaybackPage.swift              top-level PlaybackPageView container
  PlaybackVideoStage.swift        video stage + chrome tracking
  Chrome/
    PlaybackChromeTrackingView.swift
    PlaybackChromeView.swift      bottom-bar shell
    PlaybackProgressScrubber.swift
    PlaybackVolumeControl.swift   PlaybackVolumeControl + PlaybackVolumeSlider
    PlaybackChromeSpeedMenu.swift
    PlaybackChromeIconButton.swift  PlaybackChromeIconButton + IconView
  TopBar/
    LiquidGlassVideoTopBar.swift
    LiquidGlassWindowControlButton.swift
  Sidebar/
    PlaybackSidebarShell.swift
    PlaybackSidebarResultRow.swift
    PlaybackSubtitlesList.swift   PlaybackSubtitlesList + SidebarSubtitleRow
  Feedback/
    PlaybackFeedbackLayer.swift
```

Each move is its own commit. The supporting types `PlaybackChromeControls`
(struct + factory extension) and `PlaybackChromeMetrics` (layout
constants) stay in `PlaybackChromeView.swift` so the chrome region is
self-contained. Eight types not named in the original plan were co-located
with their primary caller: `PlaybackSpeedButtonAnchorKey` and
`PlaybackChromeCapsuleButtonStyle` joined `PlaybackChromeView.swift`;
`PlaybackChromeMenuButtonStyle` joined `PlaybackChromeSpeedMenu.swift`;
`PlaybackChromeButtonKind`, `PlaybackChromeIcon`, `PlaybackChromeIconButtonStyle`,
and `PlaybackCopyGlyph` (already cross-file `internal`, used by
`PlaybackFeedbackOverlay`) joined `PlaybackChromeIconButton.swift`;
`PlaybackOverlayPanelMetrics` joined `PlaybackSidebarShell.swift`. A final
small commit (`24433b2`) stripped trailing blank lines at the EOF of the
renamed `PlaybackPage.swift`.

#### 2.b `Search/SearchView.swift` (~1209 lines → 662-line shell + 7 files; commits `a7af162` → `7c2c5e4`)

Subviews to peel out, exact list confirmed by re-grepping at Phase 2 start:

```text
Search/
  SearchView.swift                top-level mode dispatch
  Library/                        Library mode subviews (currently inside SearchView)
    LibraryFolderGroupView.swift
    LibraryFolderHeader.swift
    LibraryEpisodeGrid.swift
    LibraryEpisodeButton.swift
  Results/
    SearchResultCardGroupView.swift
    CardGroupHeader.swift
  Shiori/
    ShioriCardGroupView.swift
```

The Library/ subfolder under Search/ is intentional during Phase 2: Library
views currently are tightly coupled to Search's panel mode dispatch. A
later step can promote them to a sibling `Library/` feature folder once the
dispatch responsibility is split out. As-implemented also co-located several
helpers with their primary caller: `WrapFlowLayout` + `LibraryLayout` joined
`LibraryEpisodeGrid.swift`; `LibraryEpisodeButtonStyle` joined
`LibraryEpisodeButton.swift`; `SearchResultCard` joined
`SearchResultCardGroupView.swift`; `ShioriCard` joined `ShioriCardGroupView.swift`.
The shared types `SearchCardLayout`, `EqualHeightCardGridLayout`,
`SearchHighlightState`/`Tokens`/`Typography`, and helper
`displayTitleWithSoftWrapOpportunities` stayed in `SearchView.swift` and were
widened from `private` to `internal` because at least one extracted file
references them.

#### 2.c `Settings/SettingsView.swift` (~846 lines → 126-line shell + 6 category files; commits `f6e1090` → `023070b`)

```text
Settings/
  SettingsView.swift                 shell + category switcher
  SettingsLibraryCategory.swift
  SettingsDecodeCategory.swift
  SettingsAppearanceCategory.swift
  SettingsMaintenanceCategory.swift
  SettingsDeveloperCategory.swift
  SettingsExperimentalCategory.swift
```

The `AppearanceModeSegmentedControl` and `DecodeModeSegmentedControl`
helpers stayed `private` inside their corresponding category file (no
`Settings/Controls/` subfolder needed). Unlike 2.a / 2.b, 2.c required
actual restructuring: each category was originally a `private var
xxxSettingsContent: some View` computed property on `SettingsView`, not a
standalone struct. The refactor moved each into its own `SettingsXxxCategory`
struct that declares its own `@EnvironmentObject`s (SwiftUI's environment
propagates down the view tree), owns its own `@State` (`folderPendingRemoval`
+ `isChoosingFolder` → Library, `isShowingCompactConfirmation` → Maintenance),
and hosts its own `.alert` (the Remove Folder alert moved to Library, the
Compact Database alert moved to Maintenance). Private helpers (`folderList`,
`statusView`, `chooseFolder`, `indexingSummary`, `maintenanceStatusView`,
`storageRow`/`metricRow`/`formattedBytes`, `ftsVocabulary*`,
`currentQueryTermsTitle`, `formattedCount`) were relocated whole onto the
relevant category struct. A final cleanup commit (`023070b`) dropped now-unused
imports (`AppKit`, `CueSeekerCore`, `CueSeekerPlayback`) and env objects
(`appState`, `indexing`, `search`, `library`) from the shell, plus trailing
EOF blank lines.

#### Phase 2 verification

`swift build` + `swift test` 95/95 + `git diff --check` clean at every
commit. End-to-end smoke was the project owner's responsibility (there is
no automated UI test coverage on `CueSeekerApp`), and the owner ran an E2E
real-machine regression after every sub-step (2.a, 2.b, 2.c) with Codex
code review on each block.

## Risks and mitigations

- **Cross-store computed property staleness.** Demonstrated by the
  `ContentRootView` top-bar regression in Phase 1.7. Mitigation: every view
  reading a cross-store AppCoordinator computed property must observe the
  underlying stores. Encoded as a rule in `04_architecture_rules.md` §7 at
  Phase 1.9. Phase 2 splits inherit the same audit when subviews acquire
  their own `@EnvironmentObject` declarations.
- **Parameter shadowing during bulk rewrites.** Methods that take a
  parameter named identically to a moved store (`openShiori(_ shiori:)`)
  produced silent semantic breakage during Phase 1.4 perl rewrites.
  Mitigation: post-perl `swift build` immediately surfaces the type error;
  Phase 2 has no equivalent risk because moves are file-level, not
  identifier-level.
- **`if let` / `guard let` shorthand bindings.** Swift's shorthand requires
  a simple identifier; `if let store.property` is invalid syntax.
  Encountered 11 times across Phase 1.4–1.7 perl passes. Mitigation: each
  shorthand site got a manual rewrite using an explicit local name. Phase 2
  has no perl rewrites so this does not recur.
- **Search lazy loading / first-screen latency regression.** Flagged by the
  project owner before Phase 1 started. Phase 1.6 SearchStore extraction
  preserved every field involved (pagination, expand/collapse,
  presentation state) within a single store, and the cursor state stayed
  on AppCoordinator unchanged. Verified by end-to-end pass after Phase 1.6
  with no regression observed.

## Acceptance and rollback

Each phase is its own group of small commits. Rollback unit is one commit.
The branch `ui/restructure` is the working branch. The original plan called
for merging back to `main` after Phase 2 + owner acceptance, but the
project owner has decided to keep the branch open for subsequent UI detail
alignment work (handed off to other AIs) instead of merging immediately.
Merge timing is owner-controlled.

## Decision

All four phases (0, 3, 1, 2) are implemented and owner-accepted via
per-sub-step E2E regression. `ui/restructure` stays open as the active
branch for follow-up UI alignment work. Subsequent structural work (e.g.
splitting `AppCoordinator.swift` further) is out of this proposal's scope
and, if pursued, will land as its own proposal.
