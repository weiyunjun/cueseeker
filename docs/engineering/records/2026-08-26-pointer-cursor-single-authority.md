# Pointer cursor by hosting framework

Human-owned documents:

- `docs/human/requirements/20260826-UI-Pointer Cursor Single Authority.md`

## Why

The hand pointer was written in nine places and appeared in one: the subtitle
table. Cards, buttons, menu rows and the playback chrome all claimed it and none
of them showed it. The one place it did appear was where it should not — hovering
a video card while another card's menu was open.

All of it has one cause. SwiftUI decides the pointer for everything it draws: its
hosting view keeps a cursor-update tracking area and states the shape again on
every mouse move. Eight of the nine places pushed a shape from a hover handler,
which is not part of that decision, so the next move overwrote it — at most a
frame of hand. The subtitle table was the exception because it is AppKit: its own
document view takes hits and registers cursor rects, so the decision resolves to
the hand there and nothing overwrites it. And while a menu is open the window
stops receiving moves, so the decision that erases a pushed shape stops running
and the hand survives; the menu did not add the hand, it removed what was taking
it away.

Two attempts before this one failed, and both failures were informative enough to
record:

- A cursor rect on an `NSView` of our own did nothing. SwiftUI keeps a
  representable's view out of hit testing — probed directly, hit-testing a card's
  centre returns SwiftUI's own document view — and AppKit collects cursor rects
  and cursor updates from the view it hit-tests. The rects were registered and
  never consulted.
- Re-stating the shape on every move from `onContinuousHover` produced a visible
  flicker: our set landed before SwiftUI's own cursor update in the same event,
  and SwiftUI then set the arrow back.

## What changed

The shape is now asked of the framework that draws the surface. SwiftUI surfaces
declare it through SwiftUI's own pointer style; the subtitle table keeps its
AppKit cursor rects. Nothing sets the pointer from outside its hosting framework
any more, so there is nothing left to be overwritten.

SwiftUI gained that ability in macOS 15, so below it a card keeps the plain
arrow. That is the accepted trade in the requirement: there is no way to hold a
hand there that does not flicker, and a flicker is worse than the arrow. The
table is unaffected by the version either way.

A `Button` decides the pointer for its own area, so on the two cards that are
buttons the hand goes on the label inside the button rather than around it.
Measured, not assumed: around the button the pointer stayed the arrow.

Three surfaces ask for the hand — the video card, the library folder card and the
Shiori list card — each only while the card is available and its layer is not
frozen, asked of the existing layer registry rather than a new flag. The table
gained the same frozen rule, so its own open row menu now leaves the arrow in
place. Every other pointer shape is gone, and with it the `not-allowed` pointer
on disabled cards and buttons, which macOS does not use.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/HandPointer.swift`
  - Replaced wholesale: was `PointerOnHoverModifier.swift` holding
    `pointerOnHover`, now holds `handPointer`. Renamed after acceptance.
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`
  - The video card and the folder card ask for the hand; the retired
    `LibraryCardCursorModifier` and the Recent Shiori row's pointer are gone.
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriListOverviewView.swift`
  - The Shiori list card asks for the hand on its button label.
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
  - One `isPointerFrozen` answer feeds both the cursor rects and the per-move
    refresh; opening and closing the row menu asks for a fresh decision.
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`,
  `.../Shared/LibraryOverviewComponents.swift`,
  `.../Playback/SubtitleFocus/PlaybackCommandPanel.swift`,
  `.../Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift`
  - Pointer code removed; hover state and every other behaviour unchanged.
- `docs/engineering/04_architecture_rules.md`
  - Records where a pointer shape may come from, next to the existing rule that
    warned the pushed-cursor approach is unreliable.

No token, colour, size, layout, menu content or keyboard behaviour changed.

## Verification

`swift build`: clean. `swift test`: 1061 tests, the same failures as the baseline
tree with this change stashed — native playback timeline, library folder removal,
refresh-scope, window geometry, and the submenu timing test that fails on the
baseline too and passes in isolation on both trees.

The pointer shape was measured, not eyeballed. A temporary swizzle on the cursor
setter logged every shape the App set, driven through the Debug in-app E2E
controller; it was removed before this commit. In each case the log ends on the
expected shape with nothing setting it back:

- Video card, library folder card, Shiori list card: the hand.
- Subtitle cue text: the hand.
- The New List button: the arrow.
- A card's context menu open, pointer moved to another card: the arrow.
- The table's row menu open, pointer moved to another cue: the arrow.

That instrumentation is what the E2E controller cannot do on its own: `mouseMove`
does not reach `.onHover`, and captures never contain the cursor. Exposing the
current shape through `inspect` would make these five checks repeatable; the
owner declined that for this requirement, so acceptance items 1 to 6 remain the
owner's manual check, including the macOS 15 boundary, which cannot be exercised
on this machine.

## Follow-up: the freeze answer belongs to the layer, not the page

The hand did not appear on cards in the Command Panel or the Playback Overlay,
and their hover highlight did not appear either. Both surfaces reuse the card
grids written for the workbench page, and those cards asked whether the
*workbench page* was frozen. The workbench page is frozen exactly because the
Command Panel or the playback page is open above it, so a panel declared its own
cards frozen the moment it opened.

The hand there was this change's own gap: the frozen rule was wired to the only
answer available. The missing hover was older — the same flag already guarded the
hover handler before this work started, so those cards never followed the pointer
inside the panel.

The registry now answers for every layer at once, and a subtree says which layer
it is on: the Command Panel claims its own layer, the Playback Library Overlay
claims the overlay. A card asks the layer it is actually on. The registry is
still the only place the question is answered, and no new state was added.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/InterfaceLayerRegistry.swift`
  - `frozenLayers` answers for all layers; `InterfaceLayerContext` carries the
    subtree's layer with it, and `interfaceLayer(_:)` claims one. The
    workbench-page freeze environment value it replaces is gone.
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCommandPanel.swift`,
  `.../PlaybackLibraryOverlay.swift`
  - Each claims its layer for the grids it hosts.
- The three cards read the context instead of the page's answer.

Covered by `## 4. 覆盖与冻结` item 3 of the requirement.

### Verification

Four tests in `InterfaceLayerFreezeTests.swift` pin the defect: an open layer
freezes the page below it and not itself, a surface answers for the layer it is
on, a menu still freezes the layer that owns it, and nothing is frozen with only
the workbench page open. `swift test`: 1065 tests, no new failures against the
baseline.

With the cursor instrumentation still installed, the workbench page was
re-checked and is unchanged: the video card shows the hand, and a card whose
neighbour has an open menu shows the arrow. The Command Panel and Playback
Overlay could not be driven reliably through the E2E controller — playback did
not stay open across the scripted steps — so the on-screen confirmation there is
the owner's, and the automated guard is the unit tests above.

## Follow-up: the card menu came back the same way

Cards in the Command Panel and the Playback Overlay had no right-click menu
either. This one was not a gap in this work — it is a regression from
`e65c97f6`, the commit that moved coverage into the registry.

Before it, the card's right-click monitor was gated on a flag that the workbench
subtree set on itself and the playback subtree never inherited, so a card inside
the Command Panel read "not covered" and kept its menu. That commit replaced the
flag with the registry's "is the workbench page covered", which is true wherever
you read it once a higher layer is open — including inside the panel that made it
true. The menu stopped opening there and the loss went unnoticed.

Coverage now answers per layer the same way freezing does: the registry reports
every covered layer, and the card's right-click gate asks about the layer the
card is on. Cards in the Command Panel and the Playback Overlay behave like
workbench cards again.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/InterfaceLayerRegistry.swift`
  - `coveredLayers`, and `InterfaceLayerContext.isCovered` beside `isFrozen`.
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`
  - The card menu trigger asks the context instead of the page's answer.

### Verification

Three more tests in `InterfaceLayerFreezeTests.swift`: an open layer covers the
page below it and not itself, a surface answers coverage for its own layer, and a
dialog still covers the layer it opens over. `swift test`: 1068 tests, no new
failures against the baseline.

Driven through the Debug in-app E2E controller: play an episode, open the Command
Panel, open its Recent Videos page, right-click a card. The capture shows the
card menu open over the panel with the right-clicked card highlighted. The
Playback Overlay's episode grid takes the same path and claims its own layer, but
its module could not be opened from the scripted steps, so that surface is the
owner's check.

The menu inventory in `docs/human/design/UI Application Rules.md` lists the card
menu as a Workbench menu. After acceptance it should record that the same menu
belongs to the Command Panel and the Playback Overlay as well; that is the
owner's edit.

## Follow-up: the menu had to belong to the layer too

Restoring the menu was not enough — it opened, and then behaved like a menu
nobody owned. Two more places named the workbench page where they should have
named the layer the cards are on.

The menu host registered its gate client as owned by the workbench page. The gate
takes no input for a menu whose owning layer is covered, and the workbench page is
covered while the Command Panel is open, so the panel's card menu got no keys, no
outside press and no scroll ban — and, registered against the wrong layer, it
froze the hidden page instead of the panel, leaving the panel's own cards
following the pointer underneath an open menu.

The card menu also never took keys from the playback key router. On the workbench
page nothing competes for the arrows, but on a playback layer the key owner
offers keys to the gate before the Command Panel navigates its grid. Opted out,
the menu watched the panel move its selection while its own highlight sat still.

Both now follow the layer: the client is registered against the layer the cards
are on, and it accepts router keys the way the playback speed menu already does.

Files:

- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`
  - `LibraryCardContextMenuHost` registers with `layerContext.layer` and sets
    `receivesKeysFromRouter`.

### Verification

Driven through the Debug in-app E2E controller, in the Command Panel's Recent
Videos page, with captures at each step:

- Right-click a card: the menu opens, the card keeps its highlight.
- Down arrow: the menu highlight moves to the next item and the panel's own
  selection stays where it was.
- Wheel over the grid: the grid does not scroll.
- Right-click a second card: the menu and the highlight move to it, and the menu
  highlight restarts at the first item.
- Click outside: the menu closes, the panel stays open, the card keeps its
  selection.

`swift test`: 1068 tests, no new failures against the baseline. The Playback
Overlay's episode grid takes the same path but its module could not be opened
from the scripted steps, so that surface is the owner's check.

## Follow-up: nothing states a shape while a menu is open

The owner requires that no pointer shape be stated explicitly while a right-click
menu is open, because an upcoming requirement tests that. Two things violated it.

This work had added `NSCursor.arrow.set()` when the table's row menu opens, and a
cursor refresh when it closes. Both are gone: opening and closing only ask AppKit
to decide again, and the frozen guard on the cursor rects is what leaves the
arrow. The table's exit reset is now silent while frozen for the same reason.

A second pushed pointer survived the earlier sweep: the table row's hover action
bar still pushed the hand, and the not-allowed shape when disabled. It is
removed, so no SwiftUI surface in the App pushes a cursor any more.

The freeze answer the table uses is now its own `isMenuOpen` flag. The gate
session it used before is not opened on the path that shows the row menu, so the
guard never fired.

Cards state nothing either: while frozen they withdraw their pointer style rather
than naming a shape, so the surrounding decision stands.

Files:

- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`

### Verification

With the cursor setter instrumented and the row menu open, no cursor set
originates in the App: every set logged while the menu is up comes from AppKit's
own cursor-update pass. A grep over the sources confirms the only remaining
cursor code is the table's own guarded per-move decision, the scrollbar's arrow
rect, the reel's rects and the cursor-visibility counter.

`swift test`: 1068 tests, no new failures against the baseline.
