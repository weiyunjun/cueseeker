# Debug E2E mouse pointer and button interaction

Human-owned documents:

- `docs/human/requirements/20260824-Engineering-Debug End-to-End In-App Mouse Pointer And Button Interaction.md`

## Why

The Debug E2E controller could only send an atomic left click, a vertical wheel
event and a key press. Three interactions had no automated path at all: the
Workbench row context menu and the Library cover context menu open on right
click, and the Playback Overlay selected-text menu only appears after a real
press-drag-release over subtitle text. Pointer visibility had no observable
evidence either, because captures never contain the cursor.

## What changed

Five commands were added: `mouseMove`, `rightClick`, and the separable
`mouseDown` / `mouseDrag` / `mouseUp`. They reuse the existing complete-scene
coordinates and frontmost-window routing. `rightClick` and `mouseDown` perform
the same activation as `click`; `mouseMove`, `mouseDrag` and `mouseUp` do not,
so a drag never reorders windows midway through its own sequence.

Drag order is enforced by a small value type rather than by ad-hoc flags:
dragging or releasing without an open press, and a second press before a
release, fail with `invalidDragSequence` and post no event.

Every scene response now carries `pointerVisible`. Its single source is the one
place in the App that hides the system cursor, so the reported value cannot
drift from the real cursor state.

The six existing commands are untouched.

Files: `DebugE2EController.swift`, `PlaybackChromeVisibilityModel.swift`,
`DebugE2EControllerTests.swift`, `docs/engineering/08_end_to_end_testing.md`.

## Verification

Before writing any of this, four AppKit probes were run against a real
application event loop with the physical cursor parked outside both probe
windows, testing both the direct `sendEvent` and the queued `postEvent` paths:

- A synthesized `mouseMoved` reaches an AppKit first responder with the correct
  converted location.
- A synthesized `rightMouseDown` reaches the view under the point.
- `NSTrackingArea` enter/exit callbacks never fire from synthesized events.
- SwiftUI `.onHover` never fires from synthesized events.
- `CGWarpMouseCursorPosition` did not move the cursor in an unbundled process,
  and moving the real pointer is forbidden by the requirement anyway.

Automated: `swift build` clean. `swift test --filter DebugE2EControllerTests`,
12 tests green, covering parsing and argument rejection for all five new
actions, the posted event types, frontmost-window targeting and converted
location for each action, invalid and non-finite coordinates, real delivery of
`mouseMove` to a first responder and of `rightClick` to a view, and the full
drag-order rule. The six pre-existing controller tests still pass.

Full `swift test`: the failures are media-decode, playback-timeline and
CueGroup refresh-timing cases. The two consistently failing CueGroup tests were
re-run against the same tree with the three modified files restored from Git;
they fail identically without this change, so they are pre-existing. The
media-decode failures did not reproduce under a filtered run and are
load-dependent.

## Outcome

The requirement is met for `rightClick`, the drag primitives, `pointerVisible`,
and `mouseMove` on surfaces that derive hover from the event location.

It is **not** met for hover on SwiftUI surfaces, which the platform makes
impossible without moving the real pointer. Acceptance criteria 1 and 2 are
therefore only partly reachable: the Workbench table row hover and its right
click work, while the Library cover hover effect and the cover context menu do
not, because that menu installs its right-click monitor only while the card
reports SwiftUI hover. Both remain manual acceptance steps. The limit and its
cause are documented in `docs/engineering/08_end_to_end_testing.md` so a later
procedure does not read an absent hover effect as a product defect.

In-app confirmation of acceptance criteria 1 through 4 in a running Debug E2E
session has not been done yet.
