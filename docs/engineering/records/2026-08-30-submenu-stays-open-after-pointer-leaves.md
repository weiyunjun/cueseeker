# Measuring why the submenu does not hear the pointer leave

Human-owned documents:

- `docs/human/requirements/20260830-Bug-Submenu Stays Open After Pointer Leaves.md`

Status: instrumentation only. The cause is not established yet, and no fix is
in this record.

## Why measure first

The submenu closes when both its own hover flag and the parent menu's go false:
a short grace period runs, and if neither comes back the submenu goes away. That
much is already proven by `subtitleTableShioriSubmenuStaysOpenAcrossDirectPointerTransfer`,
which exercises exactly that sequence and passes. So the defect is not in the
decision — it is that the news of the pointer leaving never arrives, or arrives
and is undone.

Guessing here has a cost this area has already paid. On 2026-08-27 the same
family of defect took two reasoned attempts, both wrong and both rejected, before
a measured third. The barrier around an open menu spends pointer events on
purpose, which is what keeps the interface underneath still, and whether the
event carrying "the pointer left" survives that is a question about delivery, not
about intent.

## What the probes ask

Two points, one line per event, both `#if DEBUG` and both temporary:

- The gate's verdict on every pointer event while a menu is open: which event,
  whether the pointer was judged to be on the menu, and whether it passed.
- What the submenu state hears and does: each hover report it receives, whether
  the grace period was started, skipped, cancelled or fired, and every change of
  which trigger is open.

Together they separate four outcomes: the event never reached the App; the
barrier spent it; it passed but SwiftUI never turned it into a hover report; or
the report arrived and something took the closing back.

Nothing is throttled. The previous record names throttling as what made its log
misread — independently throttled probes drift and land next to each other by
coincidence. The gate's monitor only exists while a menu is open, which bounds
the volume on its own.

## Verification

`swift build`: clean.

The reproduction needs a real pointer over a real menu: synthetic mouse events do
not produce the tracking-area crossings SwiftUI hover is built on, so the Debug
E2E controller cannot drive it. The owner runs it by hand once, in three
variants — out from the submenu, out from the trigger without entering the
submenu, and back onto an ordinary item of the parent menu.

## Removal

The probe lines are marked in place and come out with the fix. They are the only
change in the commit that added them.
