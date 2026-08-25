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

- `apps/macos-native/Sources/CueSeekerApp/Shared/PointerOnHoverModifier.swift`
  - Replaced wholesale: was `pointerOnHover`, now holds `handPointer`. The file
    name still says `PointerOnHoverModifier`; it should be renamed to
    `HandPointer.swift`, which is left to the owner.
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
