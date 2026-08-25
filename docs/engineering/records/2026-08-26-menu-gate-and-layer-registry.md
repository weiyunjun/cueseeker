# Menu Gate And Layer Registry

Requirement: `docs/human/requirements/20260825-UI-Menu Gate And Layer Registry.md`
Design authority: `docs/human/design/UI Application Rules.md`,
`docs/human/design/UI Design System.md` §2.4 Menus.

The requirement is an implementation convergence with no user-visible change:
one registry answers every "is this layer covered / frozen" question (§2), and
one gate implements menu event handling for all five menus (§3).

## Step A — the layer registry

### What existed

"Is something above me open" had five unrelated answers: the workbench
popup-layer environment flag (dialog sheets composed at the window root, the
playback route composed again inside the workbench), the card-menu-open
environment flag, the table coordinator's copy of the popup flag, the playback
session store's covered-by-higher-overlay flag (synchronized by hand from the
Command Panel's presentation), and raw "is the Command Panel presentation nil"
checks in the speed menu's monitor, its menu item interaction, and the playback
keyboard router. A sixth, the table's outside-click-dismiss suspension, was
dead: nothing ever set it.

### What the step did

`Shared/InterfaceLayerRegistry.swift` records the open layers of the design's
layer list (playback page, Playback Overlay, Command Panel, dialog; the
workbench page is the base and always open) and the open menus by owning
layer. It answers `isCovered` (a higher layer is open), `isFrozen` (covered, or
a menu is open at or above the layer), and `isMenuCovered` (whatever covers a
menu's owner covers the menu).

Layer state stays with its owners, per the requirement:

- The playback route registers where it is routed over the workbench
  (`SearchView`).
- `PlaybackStore` reports overlay and panel transitions from the two
  presentation properties themselves, so every mutation path registers.
- The dialog layer follows the two editor sessions by observation
  (`AppCoordinator`), because the sheet bindings write nil directly on an
  interactive dismissal.
- Menus hold an `OpenMenuToken` while open; releasing the token — dismissal or
  the owner being torn down with its menu open — unregisters the menu, so no
  teardown path can leave the registry believing a menu is open.

Readers converged:

- Workbench surfaces (cards, table, tags, shell, Shiori overview) read two
  environment values — covered and frozen — published once by a bridge at the
  window root that observes the registry, so consumers re-render only when an
  answer changes.
- The playback session store's wheel and scrollbar gates ask the registry;
  the covered flag, its setter, and the by-hand synchronization are gone.
- The overlay views pass the registry's answer down the existing
  representable plumb to the AppKit reels.
- The speed menu's three checks and the playback keyboard router ask the
  registry (`isOpen(.commandPanel)`, preserving today's exact behavior — see
  the deviations below).
- The dead outside-click-dismiss suspension flag was removed, along with the
  card-menu-open environment key (the menu owner's identity already carries
  it) and the table coordinator's popup-flag copy (renamed to the plumbed
  `isCoveredByHigherLayer` the reels already use).

### Deviations found and preserved (reported, not fixed)

Per requirement §4.1 these keep today's behavior; aligning them to the design
needs an owner decision:

1. The speed menu asks only "is the Command Panel open", not "is anything
   above the playback page open". If the Playback Overlay is opened while the
   speed menu is open, the menu still treats itself as topmost.
2. The playback overlay's covered answer historically tracked only the
   Command Panel. Dialogs are registered globally now, but the sheets are
   window-modal, so no reachable difference was observed.
3. The in-page Confirmation dialog (Shiori deletion) is not registered as the
   dialog layer; it blocks input with its own scrim, and a right-click that
   bypasses the scrim through the card monitors can still open a card menu
   under it — unchanged from before this step.
4. The workbench Selection Action Overlay is not registered: no coverage
   question is asked about it today, and registering it would freeze the
   table beneath, which selection mode relies on.

### Verification

- `swift build` clean.
- `swift test` compared against a same-day baseline run on the untouched
  tree: both runs share the same deterministic failures (two
  `CueGroupRefreshScopeIntegrationTests` cases, pre-existing) plus a shifting
  set of load-sensitive media/window cases; every case that failed only on
  the modified tree passes in isolation on it. `SubtitleTableVirtualRowTests`
  (the renamed coordinator surface): 93/93 pass.
- In-app E2E: see Step B verification; the acceptance pass covers both steps.

## Step B — the menu gate

(Recorded with the Step B commit.)
