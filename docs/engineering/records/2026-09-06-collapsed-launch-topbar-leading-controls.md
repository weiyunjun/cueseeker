# The collapsed top bar reads the window controls' width before it lays out

Human-owned documents:

- `docs/human/requirements/20260906-UI-Collapsed Launch Topbar Leading Controls Position.md`

## Why

Starting the App with the sidebar collapsed put the Sidebar Toggle and the Back
Action about 54pt too far left, the toggle sitting on top of the yellow and
green window buttons. Toggling the sidebar once put everything right, and it
stayed right for the rest of the session.

The collapsed toggle's origin is not a constant. It is the window controls'
inset plus the width the three buttons actually occupy plus the gap token, so
that the toggle lands after the buttons whatever the system gives them. That
width is measured from the live window once, when the window controls are
adopted — and that adoption was the last statement of the window's construction,
after the content view had already been hosted and the window shown. The top bar
had therefore already laid out against a width of zero, which is the value the
measurement starts from.

Nothing corrected it afterwards, because the measured width is a plain stored
value rather than observed state: no layout depends on it changing, so no layout
re-runs when it does. The next re-run came from something else entirely — the
sidebar being toggled — and that re-read the width and placed the toggle
correctly, which is why the fault looked like it healed itself.

The expanded sidebar hid all of this. With the sidebar open the toggle sits at
the sidebar's trailing edge, a position derived from the sidebar width alone,
and the measured width does not enter the result. Only a collapsed launch could
show the zero.

## What changed

**The window controls are adopted before the content view is hosted.** One
statement moved earlier in the window's construction, so the width is measured
while nothing has laid out yet and the top bar's first layout is also its
correct one. The buttons' frames are already valid at that point: the window is
created titled, and the capture below shows the three buttons at the inset the
placement asks for.

No new state, no observation, no second measurement. The value was always read
once and never invalidated; the fix is to read it before the only reader runs.

Files:

- `apps/macos-native/Sources/CueSeekerApp/App/AppDelegate.swift`

## Verification

`swift build` clean. `swift test --filter "WorkbenchLayoutStateTests"`: 12 tests,
all passing.

Debug E2E controller, `swift run CueSeeker --cueseeker-debug-e2e`, with the
persisted sidebar state collapsed — the state that reproduced the fault:

1. Collapsed launch. The capture shows the three window buttons at the inset,
   then a gap, then the Sidebar Toggle centred near 114pt and the Back Action
   near 158pt: the positions the layout asks for, on the first frame.
2. Toggle open, toggle closed, capture again. The top-left 280 x 55pt region is
   byte-identical to the launch capture, which is the requirement's first and
   third acceptance points together — the first frame is what a re-layout would
   have produced.
3. Expanded launch, after quitting and relaunching with the sidebar open. The
   toggle sits at the sidebar's trailing edge as before, unchanged.
4. Into playback and back. The playback Return Action sits after the window
   buttons at its own gap, and the Workbench top bar returns to the same place.

The persisted sidebar state was left as it was found.

The controller's `inspect` reports window bounds, not control frames, so the
acceptance was read from `capture` images instead. No end-to-end capability was
added for this change.
