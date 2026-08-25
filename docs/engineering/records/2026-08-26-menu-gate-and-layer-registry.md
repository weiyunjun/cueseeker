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

### What existed

Each of the five menus installed and removed its own `NSEvent` monitors and
implemented the modality rules for itself: the table's dismiss monitor plus a
menu block inside its keyboard monitor, the card host's keyboard and pointer
monitor views, the speed menu's dismiss monitor in the chrome plus key blocks
in the playback key router, and the reel's monitor serving both selected-text
menus, with a hand-registered key handler relayed from the overlay's reel
through six plumbing layers to the router.

### What the step did

`Shared/MenuGate.swift` is now the one implementation of menu event handling.
An open menu registers as a client describing itself — owning layer, window,
pointer hit tests, the design's scroll answer, its keys, how it dismisses —
and the gate owns everything the requirement lists: one monitor installed
while any menu is open and removed with the last one; arrows, Enter, Esc and
the submenu's left/right routed to the open menu; the outside press through
the already-unified `MenuOutsidePress` decision; the wheel through the
design's per-menu scroll table (two client facts: whether the window is
banned, and whether the menu surface takes its own wheel); and the freeze,
which the registry from Step A already answers. A covered menu is skipped
wholesale — it stays on screen and takes no input, as the modality design
specifies. Clients are processed in the order their menus opened, each seeing
an event only if the ones before passed it on — the same contract the
separate monitors had.

Sessions close themselves on any teardown path, replacing Step A's separate
menu tokens. SwiftUI-hosted menus (cards, speed) mount a `MenuGateClientView`
exactly while the menu is open; AppKit owners (table coordinator, reels) open
the session directly.

The playback key owner still sees keys first — monitors run in install order
and the app-wide playback monitor is installed at launch — so it offers every
plain key to the gate (`routeKey`) before seeking, volume and cue navigation.
This one call replaced the router's separate speed-menu and selected-text
blocks, the store's hand-registered key handler, and the whole
`onSelectedTextMenuKeyHandlerChanged` plumbing chain. The speed menu's key
logic moved next to its state (`PlaybackStore.handleSpeedMenuKey`) so the
chrome client and the unit tests exercise the same implementation.

`MenuHighlightModel`, `MenuPlacement`, `MenuOutsidePress` and the popover
panels stay what they were: single shared implementations the menus already
present themselves with. The text-selection drag engine is untouched, per the
requirement.

### Deviations resolved and left

- Step A's deviation 1 is resolved: the speed menu's coverage now comes from
  the registry like every other menu's, so a menu below the Playback Overlay
  or the Command Panel is uniformly frozen — the behavior the committed
  modality and outside-press requirements already specify.
- Found and preserved, reported for an owner decision: the Command Panel's
  selected-text menu never actually receives keys — the playback key router
  consumes arrows and Enter for panel navigation before the menu's (now the
  gate's) monitor can see them, unchanged from before this work. Routing the
  panel's menu through `routeKey` would fix it in one line once approved.

### Verification

- `swift build` clean; `swift test` full run matches the same-day baseline
  (the two pre-existing `CueGroupRefreshScopeIntegrationTests` failures plus
  the shifting load-sensitive media/window set; every case failing only on
  the modified tree passes in isolation). `PlaybackNormalShortcutTests` menu
  cases now drive the real router→gate→store path;
  `LibraryCardMenuPlacementTests` reads the menu frame from the gate client
  view; `SubtitleTableVirtualRowTests` 93/93.
- Debug E2E against the running App (scene-checked captures, compared byte
  for byte outside the traffic-light corner):
  - **Card menu**: right-click opens it anchored to the card, the anchor card
    alone stays lit; Down moves the highlight and hides the cursor; a wheel
    step outside changes not one pixel, and scrolls again after close; a
    right-click on another card closes and reopens in the same press with the
    highlight moving cards; a left press outside closes the menu, is spent,
    and hover returns only after real pointer movement; Esc closes.
  - **Table row menu**: the same set, plus six Downs and Right opening the
    destination submenu with its first item highlighted, and Left closing it.
  - The speed menu and the two selected-text menus are not reachable from the
    controller (the chrome needs real cursor movement; text selection needs a
    drag the procedure has no recipe for), the same limit every earlier menu
    record hit. Their key ownership and freeze are covered by
    `PlaybackNormalShortcutTests`; the pointer-side behavior needs the same
    manual pass the earlier requirements assigned them.

## Outcome

The five menus answer coverage from one registry and handle events through
one gate; a new modality rule now has exactly two possible homes. Behavior
matches the acceptance list everywhere the controller can reach; the playback
menus' pointer behavior awaits the owner's manual pass.
