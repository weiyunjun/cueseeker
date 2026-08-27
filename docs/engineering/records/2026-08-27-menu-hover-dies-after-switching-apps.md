# The barrier spent AppKit's record of where the pointer was

Human-owned documents:

- `docs/human/requirements/20260827-Bug-Menu Hover Dies After Switching Apps.md`

## Why

Right-clicking the table, leaving the App with the pointer on the menu, moving it away while outside, and coming back left nothing in the interface answering the pointer — and closing the menu did not bring it back. Nor did opening a new menu, nor resizing the window. Only relaunching did.

While a menu is open the barrier spends every pointer event that did not land on the menu, which is what keeps the interface underneath from lighting up. Two of the event types it was spending are not input at all. A crossing into or out of a tracking area is how AppKit records which areas the pointer is inside, and that record is written when the crossing is delivered. A local monitor that returns nil stops the delivery, so the record is never written: the window goes on believing the pointer is outside an area it is actually inside, stops sending that area any motion, and never corrects itself, because the correction it is waiting for is the very crossing it never saw.

Leaving the App with the pointer on the menu and coming back with it elsewhere produces exactly one such crossing, at reactivation, landing outside the menu. That one event was the whole defect. Staying still produced no crossing, and never being on the menu produced none either, which is why those two cases survived.

The damage outliving the menu follows from the same thing: the record is wrong inside AppKit, so taking the barrier away afterwards changes nothing.

## Measured, not reasoned

Two earlier attempts were wrong and were rejected: closing every menu when the App deactivates, which is a behaviour change the owner never asked for, and letting departures through, which addressed the wrong half of the crossing. Both were guesses. The third was measured.

Temporary instrumentation was added at three points — an App-wide monitor installed at launch, the gate's own decision, and what the table actually received — and the owner ran the reproduction once. The log says it plainly:

```
 9.55  table.received moved frozen=false
 9.67  gate.open clients=1
14.56  table.received moved frozen=true
18.75  app.…DidResignActive
24.50  app.…DidBecomeActive
24.53  gate.route entered passed=false clients=1 onMenu=[false]
42.62  gate.close clients=0 monitor=false
43.08…50.09  app.received moved  (continuously, and no table.received ever again)
```

The barrier was torn down cleanly, motion kept arriving at the App, nothing was spending it any more, and the table still never heard another one.

One reading of the same log was wrong and is worth naming, because the log invites it. Two adjacent lines appeared to show the gate's monitor running ahead of one installed at launch, which would have made `MenuGate.Kind.receivesKeysFromMonitor` wrong and the speed menu's key routing with it. They were not the same event: each probe throttles itself independently, so their lines drift apart and land next to each other by coincidence. Every pair the log produced for one event puts the monitor installed at launch first. Local monitors do run in install order, and that comment is right.

## What changed

A crossing into or out of a tracking area always travels on. Motion, drags and cursor updates are spent exactly as before, so the modality the design describes is unchanged.

Nothing underneath lights up from a crossing. The freeze is what holds those surfaces still, and each of them already asks it before acting: the table's hover entry point and its cursor reset return early while frozen, the header's hover state returns early, the Scrollbar's crossings return early, the card highlight records without applying, and the layer hover gate holds the report and delivers it when the freeze lifts.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuInputBarrier.swift` — the rule, and why a crossing is not input.
- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuGate.swift` — the one call site says whether the event is a crossing.
- `apps/macos-native/Tests/CueSeekerAppTests/MenuInputBarrierTests.swift` — the new rule, and the existing cases restated as motion.

The instrumentation is not part of this change. Its three call sites were reverted; the file it lived in, `apps/macos-native/Sources/CueSeekerApp/Diagnostics/MenuHoverDiagnostics.swift`, is untracked, is reachable from nothing, and is for the owner to remove.

## Verification

`swift build`: clean.

`swift test`: the menu-facing suites pass in full — `MenuInputBarrierTests`, `MenuGateKindTests`, `MenuHighlightModelTests`, `SubtitleTableRowActionMenuTests`, `InterfaceLayerFreezeTests` and `PointerHoverGateTests`, 48 tests, including `subtitleTableShioriSubmenuStaysOpenAcrossDirectPointerTransfer`, which is what the barrier's pointer routing would break first.

The whole suite is noisy enough that its count has to be reported rather than read as a result. Runs during this session produced 17, 19, 17 and 22 distinct failures on trees that differed only in this area, and every entry that appeared in one run and not another passes on its own. The stable remainder is the known native playback timeline, presentation transition, window geometry and localization set. Nothing menu-related fails.

The acceptance points need the App to actually lose and regain activation with the pointer in a particular place, which the Debug E2E controller cannot do: it drives the key window's own pointer and keyboard and has no activate or deactivate command. This was reported before implementation started and no test capability was added for it. Acceptance is the owner's manual check.
