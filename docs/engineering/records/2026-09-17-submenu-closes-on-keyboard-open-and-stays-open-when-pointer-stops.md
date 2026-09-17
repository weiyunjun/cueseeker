# A submenu closed under a still pointer and stayed open under a stopped one

Human-owned documents:

- `docs/human/requirements/20260917-Bug-Submenu Closes On Keyboard Open And Stays Open When Pointer Stops.md`
- `docs/human/design/UI Design System.md` (Submenu), which the requirement
  updates after acceptance

Both defects came from
`docs/human/requirements/20260830-Bug-Submenu Stays Open After Pointer Leaves.md`
(`225de8db`), and reached the Player More Menu when `44b55360` moved the
submenu rules into shared code.

## What the measurement said

Temporary probes logged every pointer event the menu gate handed to the
submenu, and every change of the open submenu. The Debug E2E controller then
searched `the` on the Search page, right-clicked the third row, and pressed
Down, Down and Right, with the real pointer resting over the window outside the
menu.

The submenu opened, and in the same millisecond the gate handed over a
tracking-area exit whose location was the one the pointer had rested on all
along, with no movement at all. The submenu's pointer rule saw a pointer outside
both menus and closed it. No item reported hover in that run. So a keyboard
open was undone by AppKit re-deciding tracking areas for the view that had just
appeared, not by anything the pointer did. Hovering to open never showed it
because the pointer then sits on the trigger, where the same rule keeps the
submenu open.

The second defect needed no probe. The 2026-08-30 rule was purely a place: the
pointer inside the triangle kept the submenu open for as long as it stayed
there, and the items it passed over had their hover reports thrown away. A
pointer that stopped inside the triangle over another item therefore held the
submenu open indefinitely, and nothing remained to give that item the highlight
when the pointer stood still.

The probes were removed before the fix.

## What changed

- The gate hands a menu only real moves. Tracking-area crossings and cursor
  updates still reach AppKit exactly as before, but they no longer count as the
  pointer going anywhere.
- Every item of a menu with submenus reports its hover to the submenu state
  through one entry. The state remembers which item the pointer is on and holds
  back the effect while the pointer is crossing to the submenu, or has not
  moved since a click or a key opened the submenu. When that ends, the
  remembered item takes effect as if the pointer had just reached it.
- The safe area now also requires the pointer to be moving sideways toward the
  submenu; a step straight up or down keeps the previous direction. It ends
  300 ms after the pointer stops, and once it ends it stays over until the
  pointer comes back to the trigger. Ending over the parent menu gives the item
  under the pointer its effect, or closes the submenu when there is no item
  there; ending outside both menus closes the submenu.
- The table row menu's rows and dividers and the Player More Menu's triggers
  report through the new entry. The two public hover methods they used before
  are gone.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuGate.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuSubmenu.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeMoreMenu.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/SubtitleTableRowActionMenuTests.swift`
  — the existing hover and crossing cases now report through the new entry
  with the same assertions; new cases cover a keyboard-opened submenu under a
  still pointer, turning away inside the triangle, moving straight down, and
  the pointer stopping inside the safe area.

## Verification

`swift build`: clean.

`swift test --filter "SubtitleTableRowActionMenu|subtitleTable|PlaybackMoreMenu|moreMenu|MenuHighlightModel|audioTrack|MenuInputBarrier|MenuGate|MenuOutsidePress|PointerHoverGate"`:
200 tests pass.

Full `swift test`: 1248 tests, with 15 to 17 failing per run in the native
playback timeline, Debug E2E controller, refresh-scope integration, Library
folder removal and shared persistence migration suites. The unmodified baseline
(`git stash`) fails in the same suites over two runs of 1245 tests. The tests
that failed only in runs with the fix belong to those same suites and fail the
same way under load: a 3 s wait for the removal executor, and a body refresh
count. All of them pass when run alone. The new stopped-pointer test first
failed under full-suite load on its highlight check, because the highlight
model watches App-wide wheel events that other tests post. The highlight check
moved to the synchronous turn-away test, and the timed test now waits up to
20 s for the main actor.

Debug E2E controller, same steps as the measurement: Right now leaves
`Save to Excerpt List`'s submenu open with its recent list highlighted; Left
closes it; Enter opens it again and it stays open. Esc closed the menu, and
nothing was saved.

Not automated: the pointer's paths, the stopped-pointer timing in the App, and
the Player More Menu. The controller cannot move the real pointer or drive
SwiftUI hover, so these stay with the owner's manual acceptance.

Outcome: the keyboard defect is fixed as observed in the App; the safe area
behaviour matches the unit cases and awaits the owner's acceptance.
