# One owner for the pointer shape, stated on movement and on resets

Human-owned documents:

- `docs/human/requirements/20260902-UI-Pointer Shape Follows Pointer Movement.md`

## Why

Three earlier rounds of pointer work each closed one leak and left the next one open. The cause was not any one leak. The accepted 2026-08-26 approach handed the shape to the framework that draws each surface — SwiftUI pointer styles for cards, AppKit cursor rects for the table and the reel — and a framework decides the cursor from what is under the pointer *now*. The requirement asks for the opposite: the shape may change only when the pointer really moves, or on three named resets, and a scroll, a key or a layout change under a still pointer must leave it alone.

That is a semantic mismatch, not a bug, and it was measured before anything was changed (§5 step 1 of the requirement). A temporary swizzle logged every cursor set with the event being dispatched and the caller, while the owner drove the three scenarios with the real pointer:

- Every shape SwiftUI stated came from the display cycle, not from a mouse event: `_NSTrackingAreaAKManager displayCycleUpdateStructuralRegions` re-evaluates the cursor for the pointer's current location at every CATransaction commit and dispatches a cursor update to the hosting view, which set the hand or the arrow from there. This runs in a run loop observer, outside event dispatch, so nothing done "after the event" could have been the last word.
- A wheel notch over the table re-registered all of the table's cursor rects and the same display-cycle pass then set whatever rect was now under the still pointer. A wheel notch over a card grid made SwiftUI restate the hand for whichever card had slid under the pointer.
- Each arrow key in the reel re-registered its I-beam rects; each arrow key in the video playlist made SwiftUI restate the hand five or six times, so the hand survived a highlight that had moved away — the exact opposite of rule 5.

Two further AppKit paths set the arrow on their own: `_clearOverrideCursorAndSetArrow` when the pointer leaves a tracking area, and `setCursorForMouseLocation:` when the window becomes key. The 2026-08-30 defect — the hand outliving the table — was one symptom of the same design.

## What changed

The shape has one owner, `AppPointerShape`, and no surface declares a shape any more.

- The decision is a value type, `PointerShapeModel`, with three inputs: a real movement, which asks what is under the pointer; a reset, which puts the arrow back until the next movement; and the hand's target losing its highlight to something other than the pointer, which drops the hand and nothing else. A card's hover is bookkeeping until a movement, or a hover the pointer itself caused, asks for a decision.
- The main window states the shape after it has dispatched a `mouseMoved` or drag, so every surface has answered the movement first. What is under the pointer is asked of the AppKit view hit at that point: the table and the reel answer `PointerShapeProviding` from the geometry they already had (the cue-text hover rects and the selectable-text rects, now laid out for the one row under the pointer instead of the visible range), an editable or selectable text control answers the I-beam, everything else the arrow. A card under the pointer wins over that, and cards are known through `CardHighlightModel`, which already receives every card hover and already knows whether the pointer caused it.
- Rule 3 is wired where the interfaces switch: the workbench route (sidebar page, Library and Shiori levels, Recent sections), the Library Video/File segment, the overlay module and collage editing, the Command Panel page, and every layer opening or closing in `InterfaceLayerRegistry` (playback page, overlay, Command Panel, dialog). Rule 4 for menus is the menu gate's barrier. Rule 5 is `CardHighlightModel.setCurrent` — the same branch that already knew a target the pointer is not on came from the keyboard.
- The frameworks are kept from restating their own shape, and made to restate the App's. Every surface that can be under the pointer — the hosting views (`CueSeekerHostingView`, which `MenuHostingView` and the table's header hosts now use), the table's document view and the reel's — registers one cursor rect over its whole visible area whose cursor is the shape already decided, and the owner rebuilds the window's rects when the decision changes. AppKit applies a cursor rect synchronously in the display-cycle pass that would otherwise fall back to the arrow, so a scroll or a layout change under a still pointer now restates the decision instead of erasing it. The hosting views answer the cursor update AppKit sends for that rect with the same shape, so SwiftUI's geometry-based answer never runs. What AppKit still states on its own — the arrow on leaving a tracking area or when the window becomes key, the I-beam from a text view's own tracking — is put back at the end of the run loop pass by an observer. It corrects only the App's three shapes, only while the App is active and the pointer is inside the window, so a cursor AppKit chose for its own reason is left alone.
- Two ways of stopping the display-cycle arrow were measured and rejected before the cursor rect. Disabling the window's cursor rects and ignoring cursor updates left the fallback in place: with nothing to apply, the pass set the arrow and the run-loop observer put the hand back 5 to 18 ms later, which the owner saw as a flicker on every wheel notch. A `.cursorUpdate` tracking area was never consulted by that pass, on the root hosting view or on the table's own view, even when the hit view owned it. A cursor rect on the root hosting view was consulted for a pointer over plain SwiftUI content, so the rect is the delivery the pass honours.
- The table's hover no longer follows a scroll. AppKit synthesizes an exit and an entry for the table's tracking area whenever the table scrolls or reflows under a still pointer, and the table used to place its hover again from the entry — so a wheel notch moved the highlight to whatever row had arrived under the pointer, unlike a card grid. Now an entry places nothing (a real entry is followed by a real move, which does), and an exit clears the hover only when the pointer is really outside the table body. The hover stays on its row and scrolls with it, which is what scenario 1 describes.
- Removed: the SwiftUI pointer style on the three cards and the `isFrozen` parameter that existed only for it; the table's cursor rects, its per-move rect invalidation and the arrow it handed back when covered; the reel's cursor rects and their invalidation; the scrollbar overlay's arrow rects; the menu gate's disable/enable of cursor rects and its direct arrow set. `HandPointer.swift` has no users left and is deleted by the owner.
- macOS 15 is no longer a boundary for the card hand: the owner sets an `NSCursor`, which every supported version has.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/AppPointerShape.swift` — new: `PointerShape`, `PointerShapeProviding`, `PointerShapeModel`, `AppPointerShape`, `CueSeekerHostingView`.
- `apps/macos-native/Sources/CueSeekerApp/Shared/CueSeekerMainWindow.swift` — states the shape after dispatching a movement.
- `apps/macos-native/Sources/CueSeekerApp/App/AppDelegate.swift` — the content view is a `CueSeekerHostingView`; the owner is attached to the window.
- `apps/macos-native/Sources/CueSeekerApp/Shared/CardHighlightModel.swift` — reports card hover to the owner and rule 5 from `setCurrent`; `noteHover` takes whether the card shows the hand.
- `apps/macos-native/Sources/CueSeekerApp/Shared/InterfaceLayerRegistry.swift`, `.../App/WorkbenchLayoutState.swift`, `.../Playback/PlaybackStore.swift`, `.../Playback/SubtitleFocus/PlaybackSubtitleFocusSessionStore.swift`, `.../TableSandbox/WorkbenchTestLibraryView.swift` — the rule 3 resets.
- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuGate.swift` — rule 4; cursor rect handling removed.
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`, `.../Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift` — answer `PointerShapeProviding`; cursor rects removed.
- `apps/macos-native/Sources/CueSeekerApp/Shared/TableScrollbarPrimitive.swift`, `.../Shared/MenuHostingView.swift`, `.../Shared/LibraryOverviewComponents.swift`, `.../Shiori/ShioriListCardGrid.swift` — cursor code removed.
- `apps/macos-native/Tests/CueSeekerAppTests/PointerShapeModelTests.swift` — new; `SubtitleTableVirtualRowTests.swift`, `TableScrollbarPrimitiveTests.swift` — the cursor rect assertions ask the shape for a point instead.
- `docs/engineering/04_architecture_rules.md` — the pointer rule now names the owner instead of the hosting framework.

No token, colour, size, layout, hover, menu or keyboard behaviour changed.

## Verification

Measured, with the same swizzle, on the changed App and the owner's real pointer:

- Wheel notches with the pointer parked on cue text (hand) and on a video card (hand): with the cursor rect in place, the only set during a notch is AppKit's display-cycle pass applying the rect's cursor, which is the hand. Measured with the real pointer resting over plain content and the decision driven to the hand through the Debug E2E controller's synthetic move, then synthetic wheel notches: the pass set the hand, never the arrow. Scenario 1.
- Up and down arrows with the pointer parked on reel text (I-beam): no cursor set. Tab to the Playlist: one arrow from the owner's reset. Scenarios 3 and 6.
- Arrow key with the pointer parked on a Playlist card (hand): one arrow from the owner's rule 5; further keys set nothing; the next movement over the same card set the hand again. Scenario 7.
- Over the search field: the I-beam, from the owner and, redundantly, from the text view's own tracking.
- What AppKit still sets on its own is the arrow on leaving a tracking area during movement; every instance was followed within a few milliseconds by the owner's own decision on the next movement. The run loop observer was confirmed to run after the display cycle in the same pass; it is the guard for a pointer that stops in the same instant.
- The swizzle was removed before this commit.

`swift test --filter "PointerShapeModel|SubtitleTableVirtualRow|TableScrollbarPrimitive|InterfaceLayerFreeze|CardHighlight|MenuInputBarrier|PointerHoverGate|MenuHighlightModel|DebugE2EController"`: 167 tests pass, including the seven scenarios of 规则解释 4 in `PointerShapeModelTests`. After the table hover and flicker follow-up, the pointer, table, card and layer suites: 122 tests pass, including `subtitleTableViewKeepsHoverWhenAppKitReportsAnExitUnderAStillPointer`.

The wheel-notch flicker and the table hover were reported by the owner from the plain Debug build after the measured session; both fixes were verified by the owner the same way, not by the swizzle.

Full `swift test`: 1131 tests, 25 issues, all in the suites the earlier pointer records list as failing on the baseline tree — native playback timeline, library folder removal, refresh scope, and the Debug E2E window-geometry cases, which pass in the filtered run above.

Pointer shapes are not readable from the Debug E2E controller, so scenarios 2, 4 and 5 and every visible acceptance point remain the owner's, as the requirement says.

## Known limits

- A text view sets its own I-beam from its tracking and its own cursor rect; where it disagrees with the decision — a field that appeared under a still pointer — the observer corrects it at the end of the run loop pass, and a single frame may show the I-beam first.
- The card's hover is reported by SwiftUI, which may report it one synthetic event after the movement that caused it; the owner decides again on that report, so a pointer that stops on a card's edge is still given the hand.
