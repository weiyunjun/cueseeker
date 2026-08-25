# One card highlight per interface

Human-owned documents:

- `docs/human/requirements/20260826-UI-Card Highlight Single Authority And Menu Input Rules.md`

## Why

Every card kept half of its own truth. The view held a private hover flag and was
handed a separate selection flag from outside, and it painted the union of the
two. Nothing in that arrangement can promise that one card is lit: the two
sources never see each other, so a card lit by a stationary pointer and a card
lit by the keyboard were both lit, and neither knew about the other.

Around that grew four different owners for the same idea — a store for the
Playback Overlay, an ordinal for the Command Panel, nothing at all for the
Workbench cards, and a fourth copy for the Shiori list — and three unrelated
gates deciding whether hover was allowed to count: whether the pointer was
visible, whether the layer was frozen, and whether the grid was in "playback
mode". Behaviour was the sum of all seven, which is why it could not be reasoned
about.

There was also a mechanical fault underneath. SwiftUI reports hover when a card
is scrolled, reflowed or revealed under a pointer that never moved. The menus had
already solved this — `MenuHighlightModel` adopts hover only after a real pointer
movement — but the cards had no such gate, so a wheel could hand the highlight to
whatever slid under the cursor.

## What changed

Hover and selection are one state for a card, and the card no longer holds any of
it. `CardHighlightModel` owns the current card of one interface; the card paints
what it is told and reports the pointer back. That is the whole fix — one card can
be lit because there is one place that can light one.

The model reuses the menus' proven shape: a gate opened by real pointer movement
and closed by a wheel, by a freeze, and by a selection landing somewhere the
pointer is not. The card under the pointer is remembered while the gate is shut,
so the next real movement applies it without the pointer having to leave the card
and come back.

The Workbench and Playback difference is one flag rather than a mode enum
threaded through the grids: a Workbench interface lets the pointer leave and
lights nothing, a Playback interface keeps one lit at all times. Interfaces that
already navigate with a selection of their own — the Playback Overlay's grid, the
Command Panel's two card pages — point the model's `adopt` at that selection and
report the result back, so those pages still have exactly one place the answer
lives.

Three gates are gone. Pointer visibility no longer decides whether a card may
follow the pointer; the keyboard no longer hides the pointer at all, in the menus
or on the playback page, so the idle player is the only thing left that hides it
and the cursor authority no longer needs to count owners. The per-card
"is my menu the open one" special case is gone too: a right-click now moves the
highlight like any other press, and the freeze holds it there.

On the menu side, every arrow and Enter now belongs to an open menu whether or
not the menu has anywhere to move — previously a key the menu declined leaked to
the grid or the page underneath. The playback speed menu is the single exception
and still lets left and right through to seeking. Three menu behaviours were
missing outright and were added: the speed menu closes when a result is switched,
when the Command Panel opens and when the Playback Overlay opens, decided by
those three events rather than by the key or controller button that caused them;
closing a selected-text menu takes the selection with it; and a card menu closes
when the interface under it changes, which the Recent page needed because it
hosts one menu for its overview and both of its sections.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/CardHighlightModel.swift`
  - New. The current card of one interface, its pointer gate, and the freeze
    modifier that keeps it in step with the layer.
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`
  - The video card, the folder card and the Shiori resume row lost their hover
    state, their `allowsHover` gate and their menu-owner special case; the grids
    take the model; Recent and Library own one model each and reset it when the
    interface changes; the card menu takes the horizontal arrows and closes on an
    interface change.
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriListOverviewView.swift`
  - The Shiori list card the same way.
- `apps/macos-native/Sources/CueSeekerApp/Shared/LibraryOverviewComponents.swift`
  - The card button style paints one state instead of hover-or-selected.
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackMediaSelectionStore.swift`
  - Keeps the grid geometry and scrolling; the selection itself is now the
    model's, and `selectFromPointer` is replaced by the model's adoption.
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackLibraryOverlay.swift`,
  `.../PlaybackCommandPanel.swift`
  - Pass the model instead of a selected id, a hover callback and a pointer-
    visibility flag. The Command Panel root list is not a card surface and is
    unchanged.
- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuHighlightModel.swift`,
  `.../Shared/AppCursorVisibility.swift`,
  `.../Playback/PlaybackChromeVisibilityModel.swift`,
  `.../Playback/PlaybackVideoStage.swift`,
  `.../App/AppCoordinator+Playback.swift`
  - The keyboard no longer hides the cursor. The counted-owner cursor authority
    collapses to one flag; the player's idle hide and the controller's hide are
    unchanged.
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`,
  `.../Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift`
  - The row menu and the selected-text menu consume every arrow and Enter; the
    selected-text menu clears the selection when it closes.
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`,
  `.../App/AppCoordinator+PlaybackCommandPanel.swift`,
  `.../App/AppCoordinator+PlaybackSubtitleFocus.swift`
  - The three events that close the speed menu.

No colour, size, radius or spacing token was added, changed or replaced, and no
interface gained a private implementation of the rule.

## Verification

`swift build`: clean.

`swift test`: 1076 tests. Ten new tests in `CardHighlightModelTests.swift` pin the
rule itself — nothing lit on entry, hover ignored until a real movement, a wheel
refused, one card at a time, the Workbench and Playback difference, a press
landing without movement and while frozen, a frozen interface keeping its picture
and not replaying what the pointer did meanwhile, a selection moved away from the
pointer not being pulled back, an interface with its own selection receiving the
adopted card, and an interface switch starting over.

Four existing tests changed because the rules changed, not because they broke:
two playback shortcut tests now expect the keyboard to leave the pointer alone,
the Command Panel freeze test now expects the speed menu to close, and the menu
highlight tests no longer expect a hidden cursor.

Against a baseline run of the same suite with this change stashed, no new failure
survives. The suite has a set of failures that shift between runs on both trees —
native playback timeline, window geometry, refresh-scope, library folder removal,
persistence migration, the submenu timing test — and each of the names that
appeared in one run passes when run on its own.

Driven through the Debug in-app E2E controller, with captures at each step:

- Shiori list page, pointer moved onto a card: that card is lit and no other.
- Pointer moved off the cards: nothing is lit.
- Right-click a second card: the highlight moves to it, the first goes out, the
  menu opens on it.
- Left-click outside the menu: the menu closes and the highlight stays put.
- Library folder list, pointer on a folder card: lit. Click it: the episode grid
  opens with nothing lit, although the pointer is over a card.
- A key press leaves `pointerVisible` true.

What the controller cannot check is which card is lit, because `inspect` does not
report it; the checks above read it from the captures. The Playback Overlay and
Command Panel card surfaces need a video playing across scripted steps, which the
controller has not managed on this tree, so acceptance items 1, 3 and the
playback halves of 5 and 6, together with items 8 to 10, are the owner's manual
check. The owner accepted item 1 as manual when the requirement was agreed.

## Design documents

Sections 3 to 9 of the requirement go into `docs/human/design/UI Design System.md`
and `docs/human/design/UI Application Rules.md` after visual acceptance. Two
existing lines will need rewording rather than adding: Media Card's states say the
selection follows a pointer that *rests* on a card and that one grid holds one,
where the rule is now a *real movement* and one *interface*.

## Follow-up: three defects found in acceptance

**The Scrollbar still answered the pointer while a menu was open.** The menu gate
withholds presses and the wheel from everything outside the menu, and it never
had to withhold hover, because until now hover reached SwiftUI views that asked
the layer registry themselves. The Scrollbar is an AppKit view taking
`mouseMoved` from its own tracking area, and nothing had ever told it about
layers. It now carries the same freeze answer as the cards beside it — while
frozen the thumb keeps the picture it had, rather than lighting under the
pointer or going out when the pointer leaves. Presses and the wheel were already
withheld by the gate, so only hover changed.

**A highlight could not be handed to the card the pointer had walked to while a
menu was open.** Right-click card A, walk to card B with the menu up, close the
menu with a click, move: on the Workbench the highlight went out and in Playback
it stayed on A. The cause was in this change's own model: freezing dropped hover
reports outright, so it forgot the pointer had reached B, and SwiftUI does not
report hover again for a card the pointer never left. Freezing now stops the
*picture* changing and keeps tracking where the pointer is, so the first real
movement after the menu closes hands the highlight to the card the pointer is
actually on. Nothing is replayed at the moment the freeze lifts; a real movement
is still required.

**Opening a selected-text menu cleared the selection it belonged to.** Making
menu dismissal take the selection with it (§9.3) was wired into the one function
that also runs at the start of the open path, where it tears down any previous
menu. So the menu came up on a selection that had just been erased. Teardown and
dismissal are now separate: the open path only tears down, and dismissal clears.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/TableScrollbarPrimitive.swift`
  - `isInteractionFrozen` suppresses the hover updates.
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchScrollView.swift`,
  `.../Shared/WorkbenchPageScrollbar.swift`
  - Both Scrollbar hosts read the layer context and pass it down.
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift`
  - The reel's Scrollbar freezes with its own menu; teardown split from
    dismissal.
- `apps/macos-native/Sources/CueSeekerApp/Shared/CardHighlightModel.swift`
  - Freezing keeps the pointer bookkeeping.

### Verification

`swift test`: 1078 tests, no new failure against the baseline. Two more tests in
`CardHighlightModelTests.swift` pin the second defect from both ends — the
pointer that travelled to another card while frozen, and the pointer that left
the cards entirely — and the frozen-picture test was corrected, because it had
asserted the defect.

Driven through the Debug in-app E2E controller, with captures:

- Library page, pointer on the Scrollbar: the thumb is the interactive colour.
  With a card menu open and the pointer on the same spot: the default colour.
- Shiori page: right-click card 1, move to card 2, click to close the menu, move
  once. Card 2 is lit and card 1 is out.

The Command Panel's selected-text menu needs a video playing across scripted
steps, which the controller has not managed on this tree, so that one is the
owner's check.

## Follow-up: the same defect was on every button, not just the Scrollbar

Fixing the Scrollbar by hand answered the report and nothing else. The App had
48 places reacting to hover and **one** of them asked whether its layer still
owned input. Every Workbench button, every player-chrome control, the Command
Panel's root rows and the Data page's rows went on lighting under the pointer
while a card menu was open, exactly as the Scrollbar did. The owner asked
whether the Scrollbar fix would hold for controls added later; it would not,
because the rule lived in the caller and a new caller starts out not knowing it.

The rule now lives in one place. `onPointerHover` reports hover only while the
surface's layer owns input, and holds the report otherwise; the held value is
delivered when the freeze lifts, so a pointer that walked away during a menu
does not leave a control lit behind it. A bare `onHover` survives in exactly
three kinds of place, and a grep is the enforcement: menu content, which belongs
to the layer it froze and reports to `MenuHighlightModel`; cards, which report to
`CardHighlightModel`; and Toast, which the design excludes from the layer list
altogether.

Two layers had never claimed themselves, and the conversion would have frozen
them against the page they were covering: the playback chrome and the two
dialog sheets read the workbench page's answer, which is frozen precisely while
they are open. Both now claim their own layer. This is the same defect class as
the Command Panel and Playback Overlay grids in the pointer-shape work above —
a subtree that does not claim a layer answers for the workbench page.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/PointerHover.swift`
  - New. `onPointerHover` and `PointerHoverGate`, the delivery rule kept out of
    the view so it can be pinned by tests.
- Sixteen files converted, one line each: `WorkbenchControls` (six controls),
  `WorkbenchIconButton`, `LibraryOverviewComponents`, `HoverEffectModifier`,
  `CoverSummaryCard`, `LibraryFolderHeader`, `LibraryEpisodeButton`,
  `LiquidGlassSelectableCard`, `PlaybackChromeIconButton`,
  `PlaybackProgressScrubber`, `PlaybackChromeView`, `LiquidGlassVideoTopBar`,
  `PlaybackVolumeControl`, `ContentView`, `PlaybackCommandPanel`, `DataView`,
  `SubtitleTableView`'s toolbar.
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackPage.swift`,
  `.../Workbench/ContentView.swift`
  - The playback chrome claims `.playbackPage`; both dialog sheets claim
    `.dialog`.
- `docs/engineering/04_architecture_rules.md`
  - Three rules: hover goes through `onPointerHover`, an AppKit surface with its
    own tracking area carries the freeze itself, and a layer with interactive
    content must claim itself.

`HoverBackgroundModifier` was converted with the rest and is unused by anything
in the App — pre-existing dead code, left in place rather than removed.

### Verification

`swift test`: 1083 tests, no new failure against the baseline. Five tests in
`PointerHoverGateTests.swift` pin the rule: an active surface is told what the
pointer did, nothing is said twice, a frozen surface is told nothing, where the
pointer ended up is delivered when the freeze lifts, and a pointer that came back
to where it started changes nothing.

The Scrollbar is the one converted surface the Debug in-app E2E controller can
drive to a visible answer, and it still gives it: interactive thumb colour with
no menu, default colour with a card menu open and the pointer on the same spot.

Per-button confirmation is the owner's. The controller's synthetic `mouseMove`
does not reliably reach SwiftUI's `onHover` — the same limit recorded in the
pointer-shape work above — so a capture cannot prove a SwiftUI button's hover
either way. What is machine-checked is the rule itself and the AppKit path;
what is left to the eye is that each converted control still lights normally
with no menu open, and stops while one is.
